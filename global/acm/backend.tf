terraform {
  backend "s3" {
    bucket       = "aws-production-platform-terraform-state"
    key          = "global/acm/terraform.tfstate"
    region       = "ap-south-2"
    encrypt      = true
    use_lockfile = true
  }
}
