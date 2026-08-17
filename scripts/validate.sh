#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AWS_REGION="ap-south-2"
DOMAIN_NAME="dev.muralidharops.com"
ROOT_DOMAIN="muralidharops.com"
STATE_BUCKET="aws-production-platform-terraform-state"

DEV_DIR="${PROJECT_ROOT}/environments/dev"
ROUTE53_DIR="${PROJECT_ROOT}/global/route53"
ACM_DIR="${PROJECT_ROOT}/global/acm"

echo "=============================================="
echo " AWS Production Platform - VALIDATION"
echo "=============================================="
echo
echo "Project root : ${PROJECT_ROOT}"
echo "AWS region   : ${AWS_REGION}"
echo "Domain       : ${DOMAIN_NAME}"
echo

fail() {
  echo
  echo "ERROR: $1"
  echo
  exit 1
}

echo "===== 1. AWS IDENTITY ====="

aws sts get-caller-identity \
  || fail "Unable to determine AWS identity."

echo
echo "===== 2. TERRAFORM DIRECTORIES ====="

for dir in "${DEV_DIR}" "${ROUTE53_DIR}" "${ACM_DIR}"; do
  [[ -d "${dir}" ]] \
    || fail "Terraform directory not found: ${dir}"

  echo "OK: ${dir}"
done

echo
echo "===== 3. TERRAFORM FORMAT CHECK ====="

terraform fmt -check -recursive "${PROJECT_ROOT}/environments/dev" \
  || fail "Terraform formatting check failed for DEV."

terraform fmt -check -recursive "${PROJECT_ROOT}/global/route53" \
  || fail "Terraform formatting check failed for Route 53."

terraform fmt -check -recursive "${PROJECT_ROOT}/global/acm" \
  || fail "Terraform formatting check failed for ACM."

echo "Terraform formatting: OK"

echo
echo "===== 4. DEV TERRAFORM VALIDATION ====="

cd "${DEV_DIR}"

terraform init -input=false >/dev/null
terraform validate

echo
echo "===== 5. DEV PLAN ====="

terraform plan -input=false

echo
echo "DEV Terraform: OK"

echo
echo "===== 6. PROTECTED DEV STATE CHECK ====="

DEV_STATE_LIST="$(terraform state list)"

if grep -Eq \
  'aws_route53_zone|aws_acm_certificate|aws_acm_certificate_validation' \
  <<< "${DEV_STATE_LIST}"; then

  echo
  echo "Protected resources found in DEV state:"
  grep -E \
    'aws_route53_zone|aws_acm_certificate|aws_acm_certificate_validation' \
    <<< "${DEV_STATE_LIST}"

  fail "Protected global resources must not exist in DEV state."
fi

echo "SAFE: DEV state contains no protected global resources."

echo
echo "===== 7. ROUTE 53 VALIDATION ====="

cd "${ROUTE53_DIR}"

terraform init -input=false >/dev/null
terraform validate

echo
echo "Checking Route 53 state..."

ROUTE53_STATE_LIST="$(terraform state list)"

grep -q '^aws_route53_zone\.this$' \
  <<< "${ROUTE53_STATE_LIST}" \
  || fail "Route 53 hosted zone is missing from global state."

grep -q '^aws_route53_record\.dev\[0\]$' \
  <<< "${ROUTE53_STATE_LIST}" \
  || fail "DEV DNS record is missing from global Route 53 state."

echo "Route 53 state: OK"

echo
echo "===== 8. ROUTE 53 AWS RECORD ====="

ZONE_ID="$(
  terraform output -raw zone_id 2>/dev/null
)"

[[ -n "${ZONE_ID}" ]] \
  || fail "Unable to determine Route 53 hosted zone ID."

DNS_RECORD="$(
  aws route53 list-resource-record-sets \
    --hosted-zone-id "${ZONE_ID}" \
    --query \
      "ResourceRecordSets[?Name==\`${DOMAIN_NAME}.\` && Type==\`A\`].AliasTarget.DNSName | [0]" \
    --output text
)"

[[ -n "${DNS_RECORD}" && "${DNS_RECORD}" != "None" ]] \
  || fail "DEV Route 53 A alias record was not found."

echo "DNS record:"
echo "${DOMAIN_NAME} -> ${DNS_RECORD}"

echo
echo "===== 9. ACM VALIDATION ====="

cd "${ACM_DIR}"

terraform init -input=false >/dev/null
terraform validate

ACM_STATUS="$(
  terraform output -raw certificate_status 2>/dev/null
)"

ACM_DOMAIN="$(
  terraform output -raw certificate_domain 2>/dev/null
)"

ACM_ARN="$(
  terraform output -raw certificate_arn 2>/dev/null
)"

[[ "${ACM_DOMAIN}" == "${DOMAIN_NAME}" ]] \
  || fail "ACM certificate domain is ${ACM_DOMAIN}, expected ${DOMAIN_NAME}."

[[ "${ACM_STATUS}" == "ISSUED" ]] \
  || fail "ACM certificate status is ${ACM_STATUS}, expected ISSUED."

[[ -n "${ACM_ARN}" ]] \
  || fail "ACM certificate ARN is empty."

echo "ACM domain : ${ACM_DOMAIN}"
echo "ACM status : ${ACM_STATUS}"
echo "ACM ARN    : ${ACM_ARN}"

echo
echo "===== 10. DEV ALB ====="

cd "${DEV_DIR}"

ALB_DNS="$(
  terraform output -raw alb_dns_name
)"

ALB_ZONE_ID="$(
  terraform output -raw alb_zone_id
)"

TARGET_GROUP_ARN="$(
  terraform output -raw target_group_arn
)"

[[ -n "${ALB_DNS}" ]] \
  || fail "DEV ALB DNS output is empty."

[[ -n "${ALB_ZONE_ID}" ]] \
  || fail "DEV ALB zone ID output is empty."

[[ -n "${TARGET_GROUP_ARN}" ]] \
  || fail "Target group ARN output is empty."

echo "ALB DNS     : ${ALB_DNS}"
echo "ALB Zone ID : ${ALB_ZONE_ID}"

echo
echo "===== 11. TARGET HEALTH ====="

aws elbv2 describe-target-health \
  --region "${AWS_REGION}" \
  --target-group-arn "${TARGET_GROUP_ARN}" \
  --query \
    'TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State}' \
  --output table

UNHEALTHY_TARGETS="$(
  aws elbv2 describe-target-health \
    --region "${AWS_REGION}" \
    --target-group-arn "${TARGET_GROUP_ARN}" \
    --query \
      'TargetHealthDescriptions[?TargetHealth.State!=`healthy`].Target.Id' \
    --output text
)"

if [[ -n "${UNHEALTHY_TARGETS}" ]]; then
  fail "One or more DEV targets are unhealthy: ${UNHEALTHY_TARGETS}"
fi

echo "All DEV targets are healthy."

echo
echo "===== 12. DNS RESOLUTION ====="

RESOLVED_IPS="$(getent hosts "${DOMAIN_NAME}" | awk '{print $1}' | sort -u)"

if [[ -z "${RESOLVED_IPS}" ]]; then
  fail "DNS resolution failed for ${DOMAIN_NAME}."
fi

echo "Resolved addresses:"
echo "${RESOLVED_IPS}"

echo
echo "===== 13. HTTPS HEALTH CHECK ====="

HTTP_STATUS="$(
  curl \
    --silent \
    --show-error \
    --output /tmp/dev-health-response.json \
    --write-out '%{http_code}' \
    --max-time 20 \
    "https://${DOMAIN_NAME}/health"
)"

if [[ "${HTTP_STATUS}" != "200" ]]; then
  echo "Response:"
  cat /tmp/dev-health-response.json || true
  fail "HTTPS health check returned HTTP ${HTTP_STATUS}."
fi

echo "HTTPS status: ${HTTP_STATUS}"

echo "Application response:"
cat /tmp/dev-health-response.json

echo
echo "=============================================="
echo " VALIDATION SUCCESSFUL"
echo "=============================================="
echo
echo "DEV infrastructure : HEALTHY"
echo "Route 53            : HEALTHY"
echo "ACM                 : ISSUED"
echo "ALB targets         : HEALTHY"
echo "HTTPS /health       : 200"
echo
