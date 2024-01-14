variable "cluster_name" {}

variable "cluster_version" {}

variable "tags" {
  type = map(string)
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "subnet_ids" {
  type = list(string)
}

variable "instance_type" {}

variable "region" {}

variable "token" {}

variable "cluster_endpoint" {}

variable "certificate_authority_data" {}
