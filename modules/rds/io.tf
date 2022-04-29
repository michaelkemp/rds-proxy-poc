variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "name" {
  type = string
}

variable "ssm_pwd" {
  type = string
}

variable "ec2_security_group_id" {
  type = string
}
