## STAGE 1: BUILD

FROM golang@sha256:47ce5636e9936b2c5cbf708925578ef386b4f8872aec74a67bd13a627d242b19 AS builder
# Base image is Go because that is the language
# Sha hash for 1.26-bookworm
# 1.26 since that is the Go version specified in 'go.mod'
# '-bookworm' is a go image tag for a specific Debian release (the OS Go is built on), it's the most stable current release
# 'AS builder' means we named this stage 'builder'

WORKDIR /app/memos
# This is the directory where we will run everything in

RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g pnpm
# apt-get update: refreshes the package list
# apt-get install -y curl means we install curl
# Using curl in the next line we add the NodeSource repo for Node 22 to apt
# apt-get install -y nodejs npm: installs Node and npm
# npm install -g pnpm: uses npm to install pnpm globally

COPY web/package.json ./web/
COPY web/pnpm-lock.yaml ./web/
# Copied pnpm dependency files to container filesystem
# These are instruction for pnpm on what to install and which version

RUN --mount=type=cache,target=/root/.pnpm-store \
    cd web && pnpm install
# Install dependencies
# The mount is a buildKit feature, we are keeping this cache the same between builds
# so every subsequent time we build the image this cache stays

COPY go.mod go.sum ./
# go.mod and go.sum are the dependency files for Go, like requirements.txt for pip
RUN --mount=type=cache,target=/root/.cache/go/pkg/mod \
    go mod download
# Download Go dependencies using the dependency files we just copied
# Buildkit mount for caching between builds

COPY . .
# Copy rest of memos repo (needed for binary compilation)

RUN cd web && pnpm release
# Turn dependencies into static files, rest of 'web' folder was needed for this
# so this command was ran after copying that
# Also this way, if web folder changes we don't need to reinstall dependencies

RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o build/memos ./cmd/memos
# create binary file using input from './cmd/memos' and output 'build/memos'
# '-ldflags="-s -w" ' means we are removing debug metadata. This is not needed in prod and helps trim binary size.
# CGO_ENABLED=0 turns off dynamic linking, meaning the binary is fully self-contained and does not depend on any shared libraries

RUN chmod 550 build/memos
# change modification permissions for /memos file
# 5 = read + execute (no write), 0 = no permissions
# first number is permissions for the owner (user), second number for the group, third is for everyone else

## STAGE 2: RUNTIME
FROM alpine@sha256:fd791d74b68913cbb027c6546007b3f0d3bc45125f797758156952bc2d6daf40
# small and fast base image, that is the SHA256 hash for alpine:3.23.5

LABEL org.opencontainers.image.title="memos" \
      org.opencontainers.image.description="A self hosted Markdown note taking app" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.source="https://github.com/akhihaani/production-grade-eks-helm-deployment"
# Metadata which gives extra information for those looking at the container
# Standard is to place label after FROM but there is no technical benefit to that

RUN addgroup -S memos && adduser -S memos -G memos
# Add system group 'memos' and system user 'memos' who is attached to group 'memos'

COPY --from=builder --chown=memos:memos /app/memos/build/memos /memos
# copy from stage named builder
# take file inside '/memos/build/memos' (inside of that stage's repo) and place inside '/memos' (of this new stages repo)
# Change ownership of /memos to user 'memos' and group 'memos'

RUN mkdir -p /var/opt/memos && \
    chown memos:memos /var/opt/memos
# creeated the directory for the volume mount and gave the group and user the permissions to edit it

USER memos
# non-root user, changes into user

EXPOSE 8081
# Documentation purposes

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
   CMD wget -q -O - http://localhost:8081/healthz || exit 1
# HEALTHCHECK is a command to check if the container is healthy
# wget is alpine's version of curl, -q means quiet, -O- means to output to stdout (Standard output) instead of file, this means to print in terminal rather than a log in the container
# || exit 1 means if wget fails then exit with code 1 which is what tells docker the container is unhealthy.
# CMD here is part of HEALTHCHECK and separate from the other CMD

CMD ["/memos"]
# Command to execute binary file since that's where the binary file was moved to
