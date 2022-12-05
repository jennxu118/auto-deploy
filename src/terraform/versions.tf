terraform {
  required_version = ">= 1.0.0"

  backend "remote" {
    organization = "rocket-homes"

    workspaces {
      name = "sandbox-us-east-1-dip-image-trimmer-iac"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.16.0"
    }
  }
}
