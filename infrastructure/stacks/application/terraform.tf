terraform {
  backend "s3" {
    encrypt = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.19.0"
    }
  }
}
