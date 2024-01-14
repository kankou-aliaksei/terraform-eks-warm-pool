variable "region" {}

variable "cluster_name" {}

variable "cluster_version" {}

variable "tags" {
  type = map(string)
}

variable "pod_identity_type" {
  validation {
    condition     = var.pod_identity_type == "IRSA" || var.pod_identity_type == "EKS_POD_IDENTITY"
    error_message = "The pod_identity_type must be either 'IRSA' or 'EKS_POD_IDENTITY'."
  }
}