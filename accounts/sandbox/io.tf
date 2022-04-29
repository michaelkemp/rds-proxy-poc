## =============== Variables ===============
variable "account_id" {
  type        = string
  description = "AWS account ID"
  default     = "847068433460"
}

variable "account_profile" {
  type        = string
  description = "Account Profile [SSO]"
  default     = "sandbox"
}

variable "region" {
  type        = string
  description = "The default AWS region."
  default     = "us-west-2"
}

## =============== SANDBOX VALUES ===============
data "aws_caller_identity" "current" {}

variable "vpc_name_oregon" {
  type    = string
  default = "local-oregon"
}

data "aws_vpc" "vpc_oregon" {
  provider = aws.us-west-2
  default  = false
  filter {
    name   = "tag:Name"
    values = [var.vpc_name_oregon]
  }
}

data "aws_subnets" "private_oregon" {
  provider = aws.us-west-2
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_oregon.id]
  }
  filter {
    name = "tag:Name"
    values = [
      "*-private-*",
    ]
  }
}

data "aws_subnets" "public_oregon" {
  provider = aws.us-west-2
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_oregon.id]
  }
  filter {
    name = "tag:Name"
    values = [
      "*-public-*",
    ]
  }
}

variable "vpc_name_virginia" {
  type    = string
  default = "local-virginia"
}

data "aws_vpc" "vpc_virginia" {
  provider = aws.us-east-1
  default  = false
  filter {
    name   = "tag:Name"
    values = [var.vpc_name_virginia]
  }
}

data "aws_subnets" "private_virginia" {
  provider = aws.us-east-1
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_virginia.id]
  }
  filter {
    name = "tag:Name"
    values = [
      "*-private-*",
    ]
  }
}

data "aws_subnets" "public_virginia" {
  provider = aws.us-east-1
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_virginia.id]
  }
  filter {
    name = "tag:Name"
    values = [
      "*-public-*",
    ]
  }
}
