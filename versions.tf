terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "tf-state-20251003143634666300000001"
    encrypt      = true
    key          = "infra-website/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }

  required_version = "~> 1.11"
}
