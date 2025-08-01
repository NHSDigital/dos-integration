terraform {
  backend "s3" {
    encrypt = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.7.0"
    }
    template = {
      source  = "hashicorp/random"
      version = "~> 3.3.0"
    }
  }
}
