terraform {
  required_version = ">=1.1.4"
  required_providers {
    aws = {
      version = ">=4.0.0"
      source  = "hashicorp/aws"
    }
  }
  backend "s3" {
    bucket         = "terraform-state-storage-847068433460"
    key            = "kempy-infrastructure.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-847068433460"
    profile        = "sandbox"
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
  profile             = var.account_profile
}

provider "aws" {
  alias               = "us-west-2"
  region              = "us-west-2"
  allowed_account_ids = [var.account_id]
  profile             = var.account_profile
}

provider "aws" {
  alias               = "us-east-1"
  region              = "us-east-1"
  allowed_account_ids = [var.account_id]
  profile             = var.account_profile
}
