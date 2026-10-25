#!/usr/bin/env bash
# Push ONLY the four generated files to branch "dev" of the CodeCommit
# "deployment" repo (the pipeline artifact must stay small).
# Usage: push_deployment_files.sh [aws_region]
set -euo pipefail

REGION="${1:-${AWS_REGION:-us-east-1}}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILES=(taskdef-customer.json taskdef-employee.json appspec-customer.yaml appspec-employee.yaml)

for f in "${FILES[@]}"; do
  [ -f "${ROOT}/deployment/${f}" ] || { echo "ERROR: deployment/${f} missing. Run 'terraform apply' first." >&2; exit 1; }
done

URL="https://git-codecommit.${REGION}.amazonaws.com/v1/repos/deployment"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cd "${WORK}"
git init -q
git config credential.helper '!aws codecommit credential-helper $@'
git config credential.UseHttpPath true
git config user.name  "${GIT_AUTHOR_NAME:-$(git -C "${ROOT}" config user.name || echo deploy)}"
git config user.email "${GIT_AUTHOR_EMAIL:-$(git -C "${ROOT}" config user.email || echo deploy@example.com)}"
git remote add origin "${URL}"

# Continue from existing dev if present, otherwise start a new dev branch.
if git fetch -q origin dev 2>/dev/null; then
  git checkout -q -b dev FETCH_HEAD
else
  git checkout -q -b dev
fi

for f in "${FILES[@]}"; do cp "${ROOT}/deployment/${f}" .; done
git add "${FILES[@]}"

if git diff --cached --quiet; then
  echo "No changes to push."
else
  git commit -q -m "Update task definitions and AppSpec files"
  git push -q origin dev
  echo "Pushed to ${URL} (branch dev)."
fi
