terraform {
  required_version = ">=1.1.4"
  required_providers {
    aws = {
      version               = ">=4.0.0"
      source                = "hashicorp/aws"
      configuration_aliases = [aws.region]
    }
  }
}
