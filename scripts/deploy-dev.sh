#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_DIR="${PROJECT_ROOT}/environments/dev"

AWS_REGION="ap-south-2"
DOMAIN_NAME="dev.muralidharops.com"
STATE_BUCKET="aws-production-platform-terraform-state"

echo "=============================================="
echo " AWS Production Platform - DEV DEPLOY"
echo "=============================================="
echo
echo "Project root : ${PROJECT_ROOT}"
echo "Dev directory: ${DEV_DIR}"
echo "AWS region   : ${AWS_REGION}"
echo "Domain       : ${DOMAIN_NAME}"
echo

if [[ ! -d "${DEV_DIR}" ]]; then
  echo "ERROR: Dev environment directory not found."
  exit 1
fi

echo "Checking AWS identity..."
aws sts get-caller-identity

echo
echo "Checking global Route 53 state..."

if ! aws s3api head-object \
  --bucket "${STATE_BUCKET}" \
  --key "global/route53/terraform.tfstate" \
  --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "ERROR: Global Route 53 Terraform state was not found."
  echo "Refusing to deploy."
  exit 1
fi

echo "Global Route 53 state exists."

echo
echo "Checking global ACM state..."

if ! aws s3api head-object \
  --bucket "${STATE_BUCKET}" \
  --key "global/acm/terraform.tfstate" \
  --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "ERROR: Global ACM Terraform state was not found."
  echo "Refusing to deploy."
  exit 1
fi

echo "Global ACM state exists."

echo
echo "Checking ACM certificate..."

CERT_ARN="$(
  aws acm list-certificates \
    --region "${AWS_REGION}" \
    --query "CertificateSummaryList[?DomainName==\`${DOMAIN_NAME}\`].CertificateArn | [0]" \
    --output text
)"

if [[ -z "${CERT_ARN}" || "${CERT_ARN}" == "None" ]]; then
  echo "ERROR: ACM certificate for ${DOMAIN_NAME} was not found."
  echo "Refusing to deploy."
  exit 1
fi

CERT_STATUS="$(
  aws acm describe-certificate \
    --region "${AWS_REGION}" \
    --certificate-arn "${CERT_ARN}" \
    --query 'Certificate.Status' \
    --output text
)"

echo "Certificate ARN    : ${CERT_ARN}"
echo "Certificate status : ${CERT_STATUS}"

if [[ "${CERT_STATUS}" != "ISSUED" ]]; then
  echo "ERROR: ACM certificate is not ISSUED."
  echo "Current status: ${CERT_STATUS}"
  echo "Refusing to deploy."
  exit 1
fi

echo
echo "ACM certificate is ISSUED."

cd "${DEV_DIR}"

echo
echo "Initializing Terraform..."
terraform init

echo
echo "Validating Terraform..."
terraform validate

echo
echo "Checking DEV state for protected global resources..."

terraform state list > /tmp/dev-state-list.txt

if grep -Eq \
  'aws_route53_zone|aws_acm_certificate|aws_acm_certificate_validation' \
  /tmp/dev-state-list.txt; then

  echo
  echo "ERROR: Protected global resources were found in DEV state."
  echo
  grep -E \
    'aws_route53_zone|aws_acm_certificate|aws_acm_certificate_validation' \
    /tmp/dev-state-list.txt

  echo
  echo "Refusing to deploy."
  exit 1
fi

echo "DEV state contains no protected global resources."

echo
echo "Creating Terraform deployment plan..."

set +e
terraform plan -out=dev-deploy.tfplan
PLAN_EXIT_CODE=$?
set -e

if [[ ${PLAN_EXIT_CODE} -ne 0 ]]; then
  echo
  echo "ERROR: Terraform plan failed."
  rm -f dev-deploy.tfplan
  exit "${PLAN_EXIT_CODE}"
fi

if terraform show -no-color dev-deploy.tfplan | grep -q "No changes. Your infrastructure matches the configuration."; then
  echo
  echo "=============================================="
  echo " DEV ENVIRONMENT ALREADY UP TO DATE"
  echo "=============================================="
  echo
  echo "Terraform reports no changes."
  echo "Nothing to deploy."
  echo
  rm -f dev-deploy.tfplan
  exit 0
fi

echo
echo "=============================================="
echo " DEPLOYMENT PLAN CREATED"
echo "=============================================="
echo
echo "Review the plan carefully."
echo
read -r -p "Type DEPLOY-DEV to continue: " CONFIRM

if [[ "${CONFIRM}" != "DEPLOY-DEV" ]]; then
  echo
  echo "Deployment cancelled."
  rm -f dev-deploy.tfplan
  exit 0
fi

echo
echo "Applying deployment plan..."

terraform apply dev-deploy.tfplan

rm -f dev-deploy.tfplan

echo
echo "=============================================="
echo " DEV DEPLOYMENT COMPLETE"
echo "=============================================="

echo
echo "Terraform outputs:"
terraform output

echo
echo "Checking ALB..."

ALB_DNS="$(
  terraform output -raw alb_dns_name 2>/dev/null || true
)"

if [[ -n "${ALB_DNS}" ]]; then
  echo "ALB DNS: ${ALB_DNS}"
fi

echo
echo "Checking target health..."

TARGET_GROUP_ARN="$(
  terraform output -raw target_group_arn 2>/dev/null || true
)"

if [[ -n "${TARGET_GROUP_ARN}" ]]; then
  aws elbv2 describe-target-health \
    --region "${AWS_REGION}" \
    --target-group-arn "${TARGET_GROUP_ARN}"
fi

echo
echo "Checking DNS..."

dig @8.8.8.8 "${DOMAIN_NAME}" +short || true

echo
echo "Checking HTTPS endpoint..."

curl -I --max-time 15 "https://${DOMAIN_NAME}" || true

echo
echo "=============================================="
echo " DEV DEPLOYMENT VERIFICATION FINISHED"
echo "=============================================="
