variable "region" {}

variable "cluster_name" {}

variable "tags" {
  type = map(string)
}

variable "enable_autoscaler" {
  type = bool
}