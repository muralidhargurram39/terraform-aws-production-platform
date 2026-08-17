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
echo " DEV INFRASTRUCTURE DEPLOYED"
echo "=============================================="

echo
echo "Terraform outputs:"
terraform output

echo
echo "Reading new ALB details..."

ALB_DNS="$(
  terraform output -raw alb_dns_name 2>/dev/null || true
)"

ALB_ZONE_ID="$(
  terraform output -raw alb_zone_id 2>/dev/null || true
)"

if [[ -z "${ALB_DNS}" || "${ALB_DNS}" == "null" ]]; then
  echo "ERROR: Unable to determine DEV ALB DNS name."
  rm -f dev-deploy.tfplan
  exit 1
fi

if [[ -z "${ALB_ZONE_ID}" || "${ALB_ZONE_ID}" == "null" ]]; then
  echo "ERROR: Unable to determine DEV ALB hosted zone ID."
  rm -f dev-deploy.tfplan
  exit 1
fi

echo "ALB DNS     : ${ALB_DNS}"
echo "ALB Zone ID : ${ALB_ZONE_ID}"

echo
echo "=============================================="
echo " UPDATING PERSISTENT ROUTE 53"
echo "=============================================="

ROUTE53_DIR="${PROJECT_ROOT}/global/route53"

if [[ ! -d "${ROUTE53_DIR}" ]]; then
  echo "ERROR: Global Route 53 directory not found:"
  echo "${ROUTE53_DIR}"
  exit 1
fi

cd "${ROUTE53_DIR}"

echo
echo "Initializing global Route 53 Terraform..."
terraform init

echo
echo "Validating global Route 53 Terraform..."
terraform validate

echo
echo "Checking global Route 53 state..."

GLOBAL_STATE_LIST="$(
  terraform state list
)"

if ! grep -q '^aws_route53_zone\.this$' <<< "${GLOBAL_STATE_LIST}"; then
  echo "ERROR: Persistent Route 53 hosted zone is not present in global Terraform state."
  echo "Refusing to modify DNS."
  exit 1
fi

if ! grep -q '^aws_route53_record\.dev\[0\]$' <<< "${GLOBAL_STATE_LIST}"; then
  echo "ERROR: Persistent DEV Route 53 record is not present in global Terraform state."
  echo "Refusing to modify DNS."
  exit 1
fi

echo "Global Route 53 state verified."

echo
echo "Creating Route 53 update plan..."

ROUTE53_PLAN="route53-dev-dns.tfplan"

set +e
terraform plan \
  -out="${ROUTE53_PLAN}" \
  -var="domain_name=muralidharops.com" \
  -var="dev_alb_dns_name=${ALB_DNS}" \
  -var="dev_alb_zone_id=${ALB_ZONE_ID}"
ROUTE53_PLAN_EXIT_CODE=$?
set -e

if [[ ${ROUTE53_PLAN_EXIT_CODE} -ne 0 ]]; then
  echo
  echo "ERROR: Route 53 Terraform plan failed."
  rm -f "${ROUTE53_PLAN}"
  exit "${ROUTE53_PLAN_EXIT_CODE}"
fi

echo
echo "Inspecting Route 53 plan..."

ROUTE53_PLAN_TEXT="$(
  terraform show -no-color "${ROUTE53_PLAN}"
)"

if grep -Eq \
  'aws_route53_zone\.this.*(destroy|replace)|aws_route53_zone\.this.*must be replaced' \
  <<< "${ROUTE53_PLAN_TEXT}"; then

  echo
  echo "ERROR: Route 53 plan attempts to modify or replace"
  echo "the persistent hosted zone."
  echo "Refusing to apply."
  rm -f "${ROUTE53_PLAN}"
  exit 1
fi

if grep -Eq \
  'aws_acm_certificate|aws_acm_certificate_validation' \
  <<< "${ROUTE53_PLAN_TEXT}"; then

  echo
  echo "ERROR: Route 53 plan unexpectedly contains ACM resources."
  echo "Refusing to apply."
  rm -f "${ROUTE53_PLAN}"
  exit 1
fi

if grep -q \
  "No changes. Your infrastructure matches the configuration." \
  <<< "${ROUTE53_PLAN_TEXT}"; then

  echo
  echo "=============================================="
  echo " ROUTE 53 ALREADY UP TO DATE"
  echo "=============================================="
  echo
  echo "dev.muralidharops.com already points to:"
  echo "${ALB_DNS}"
  echo

  rm -f "${ROUTE53_PLAN}"
else

  echo
  echo "Route 53 requires an update."
  echo
  echo "dev.muralidharops.com"
  echo "        ->"
  echo "${ALB_DNS}"
  echo

  echo "Applying Route 53 DNS update..."

  terraform apply "${ROUTE53_PLAN}"

  rm -f "${ROUTE53_PLAN}"

  echo
  echo "Persistent DNS updated:"
  echo "dev.muralidharops.com -> ${ALB_DNS}"
fi

cd "${DEV_DIR}"

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
