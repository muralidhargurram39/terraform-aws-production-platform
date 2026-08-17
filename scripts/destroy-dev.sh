#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_DIR="${PROJECT_ROOT}/environments/dev"

echo "=============================================="
echo " AWS Production Platform - DEV DESTROY"
echo "=============================================="
echo
echo "Project root : ${PROJECT_ROOT}"
echo "Dev directory: ${DEV_DIR}"
echo

if [[ ! -d "${DEV_DIR}" ]]; then
  echo "ERROR: Dev environment directory not found."
  exit 1
fi

cd "${DEV_DIR}"

echo "Checking Terraform configuration..."
terraform validate

echo
echo "Checking Terraform state..."
terraform state list > /tmp/dev-state-list.txt

if grep -Eq 'aws_route53_zone|aws_acm_certificate|aws_acm_certificate_validation' /tmp/dev-state-list.txt; then
  echo
  echo "ERROR: Protected global resources were found in DEV state."
  echo
  grep -E 'aws_route53_zone|aws_acm_certificate|aws_acm_certificate_validation' /tmp/dev-state-list.txt
  echo
  echo "Refusing to destroy."
  exit 1
fi

echo "Protected global resources are NOT present in DEV state."
echo

echo "Creating destroy plan..."
terraform plan -destroy -out=dev-destroy.tfplan

echo
echo "=============================================="
echo " DESTROY PLAN CREATED"
echo "=============================================="
echo
echo "Review the plan above carefully."
echo
read -r -p "Type DESTROY-DEV to continue: " CONFIRM

if [[ "${CONFIRM}" != "DESTROY-DEV" ]]; then
  echo
  echo "Destroy cancelled."
  exit 0
fi

echo
echo "Applying destroy plan..."
terraform apply dev-destroy.tfplan

echo
echo "=============================================="
echo " DEV ENVIRONMENT DESTROYED"
echo "=============================================="
echo

echo "Verifying protected Route 53 state..."
cd "${PROJECT_ROOT}/global/route53"

terraform state list

echo
echo "Verifying protected ACM state..."
cd "${PROJECT_ROOT}/global/acm"

terraform state list

echo
echo "Done."
