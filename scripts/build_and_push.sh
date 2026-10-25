#!/usr/bin/env bash
# Build services/<name> and push it to ECR as :latest.
# Usage: build_and_push.sh <service> <ecr_repository_url> <aws_region>
set -euo pipefail

SERVICE="${1:?service name (customer|employee)}"
REPO_URL="${2:?ECR repository URL}"
REGION="${3:-us-east-1}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/services/${SERVICE}"

[ -f "${SRC}/Dockerfile" ] || { echo "ERROR: ${SRC}/Dockerfile not found. Add the service code first." >&2; exit 1; }

REGISTRY="${REPO_URL%%/*}"

aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"

# Fargate tasks run linux/amd64 by default; force it so builds on Apple Silicon work.
docker build --platform linux/amd64 -t "${REPO_URL}:latest" "${SRC}"
docker push "${REPO_URL}:latest"
