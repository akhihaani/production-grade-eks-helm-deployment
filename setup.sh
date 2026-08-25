#!/usr/bin/env bash
set -euo pipefail

# --- 1. The author's CURRENT values ---
TFVARS=Terraform/bootstrap/terraform.tfvars
OLD_ACCOUNT=$(grep -E '^account_id[[:space:]]*='  "$TFVARS" | cut -d'"' -f2)
OLD_REGION=$(grep -E  '^region[[:space:]]*='      "$TFVARS" | cut -d'"' -f2)
OLD_DOMAIN=$(grep -E  '^domain[[:space:]]*='      "$TFVARS" | cut -d'"' -f2)
OLD_REPO=$(grep -E    '^github_repo[[:space:]]*=' "$TFVARS" | cut -d'"' -f2)

# --- 2. Ask the porter for their 4 values ---
read -rp "AWS account ID [$OLD_ACCOUNT]: " ACCOUNT_ID
ACCOUNT_ID="${ACCOUNT_ID:-$OLD_ACCOUNT}"

read -rp "AWS region [$OLD_REGION]: " REGION
REGION="${REGION:-$OLD_REGION}"

read -rp "Domain [$OLD_DOMAIN]: " DOMAIN
DOMAIN="${DOMAIN:-$OLD_DOMAIN}"

read -rp "GitHub repo (owner/repo) [$OLD_REPO]: " REPO
REPO="${REPO:-$OLD_REPO}"

# --- 3. Files that contain those literals ---
# Curated on purpose: only files vetted to hold these values are touched, so a
# short substring like the region can never be swapped somewhere unintended
# (e.g. inside the app/memos submodule or an unrelated ARN).
FILES=(
  Terraform/bootstrap/terraform.tfvars
  Terraform/bootstrap/backend.tf.disabled          # forked repo ships this; renamed to backend.tf after first apply
  Terraform/bootstrap/backend.tf
  Terraform/root.hcl
  Terraform/infra/live/eks-addons/terragrunt.hcl
  Terraform/infra/modules/eks-addons/eks-addons.tf
  Terraform/infra/modules/eks-addons/helm-values/cert-manager.yaml
  Terraform/infra/modules/eks-addons/helm-values/external-dns.yaml
  helm/memos-chart/templates/ingress.yaml
  helm/memos-chart/values.yaml
  manifests/application.yaml
  manifests/clusterIssuer-prod.yaml
  manifests/clusterIssuer-staging.yaml
  Dockerfile
)

# --- 4. Swap old -> new in each file ---
for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "skip (not present): $f"
    continue
  fi
  sed -i.bak \
    -e "s|${OLD_ACCOUNT}|${ACCOUNT_ID}|g" \
    -e "s|${OLD_REGION}|${REGION}|g" \
    -e "s|${OLD_DOMAIN}|${DOMAIN}|g" \
    -e "s|${OLD_REPO}|${REPO}|g" \
    "$f"
  rm "${f}.bak"
done

# --- 5. Set the GitHub Actions variables (derived from the same inputs) ---
# Requires an authenticated gh CLI with access to $REPO.
if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh is not authenticated. Run 'gh auth login' and re-run this script." >&2
  exit 1
fi

# --- 5b. Immutable-OIDC numeric IDs: derive from the porter's repo, write into tfvars ---
# GitHub's immutable subject claim (July 2026+) encodes the owner + repo numeric IDs,
# which differ for every fork, so they are fetched rather than string-swapped.
OWNER="${REPO%%/*}"
OWNER_ID=$(gh api "users/${OWNER}" --jq '.id' 2>/dev/null || true)
REPO_ID=$(gh api "repos/${REPO}" --jq '.id' 2>/dev/null || true)
if [[ -n "$OWNER_ID" && -n "$REPO_ID" ]]; then
  sed -i.bak -E "s|^(github_owner_id[[:space:]]*=).*|\\1 \"${OWNER_ID}\"|" "$TFVARS"
  sed -i.bak -E "s|^(github_repo_id[[:space:]]*=).*|\\1 \"${REPO_ID}\"|" "$TFVARS"
  rm -f "${TFVARS}.bak"
  echo "Set immutable-OIDC IDs in tfvars: owner=${OWNER_ID} repo=${REPO_ID}"
else
  echo "Warning: could not fetch GitHub numeric IDs for ${REPO}." >&2
  echo "Set github_owner_id and github_repo_id in ${TFVARS} manually." >&2
fi

ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/memos"
gh variable set AWS_ACCOUNT_ID --body "$ACCOUNT_ID" --repo "$REPO"
gh variable set AWS_REGION     --body "$REGION"     --repo "$REPO"
gh variable set ECR_REPO       --body "$ECR_REPO"   --repo "$REPO"
gh variable set APP_DOMAIN     --body "$DOMAIN"     --repo "$REPO"

echo "Done. Review the changed files, then run terraform init/apply."
echo "Reminder: delegate DNS at your registrar to the new Route 53 hosted zone's"
echo "nameservers (bootstrap output) before the cluster pipeline runs."