# Bootstrap intentionally does NOT include the root config.
# It creates the S3 state bucket, so it can't use the S3 backend yet —
# it runs on local state. This file exists only so Terragrunt treats
# bootstrap as a unit, which lets other units read its outputs via `dependency`.
