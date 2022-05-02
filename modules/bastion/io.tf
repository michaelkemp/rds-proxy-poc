variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "ec2_name" {
  type = string
}

variable "testdb_pwd" {
  type = string
}
