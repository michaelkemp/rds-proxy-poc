variable "account_id" {
  type = string
}

variable "region" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "cidr_blocks" {
  type = list(string)
}

variable "repo" {
  type = string
}

variable "container_secrets" {
  type    = map(string)
  default = {}
}

variable "ulimits" {
  type    = list(map(string))
  default = []
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "rds_security_group" {
  type = string
}