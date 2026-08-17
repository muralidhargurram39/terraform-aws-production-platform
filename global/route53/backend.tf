terraform {
  backend "s3" {
    bucket       = "aws-production-platform-terraform-state"
    key          = "global/route53/terraform.tfstate"
    region       = "ap-south-2"
    encrypt      = true
    use_lockfile = true
  }
}
