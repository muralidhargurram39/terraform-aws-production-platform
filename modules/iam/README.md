# IAM Module

Reusable IAM foundation for the AWS production platform.

## Components

- EC2 instance role
- EC2 instance profile
- EC2 permission boundary
- EC2 runtime policy
- CI/CD role
- Auditor role
- IAM Access Analyzer

## Principles

- No long-lived AWS credentials on EC2
- EC2 uses IAM instance profiles
- Permission boundaries limit maximum permissions
- CI/CD permissions are added only when required
- Auditor access is read-only
- IAM Access Analyzer provides continuous analysis

## Future Extensions

- OIDC federation for GitHub Actions
- Service-specific deployment policies
- Organization-level permission boundaries
- Automated IAM policy validation
