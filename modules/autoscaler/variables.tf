variable "region" {}

variable "cluster_name" {}

variable "oidc_provider" {}

variable "pod_identity_type" {
  default = "IRSA"

  validation {
    condition     = var.pod_identity_type == "IRSA" || var.pod_identity_type == "EKS_POD_IDENTITY"
    error_message = "The pod_identity_type must be either 'IRSA' or 'EKS_POD_IDENTITY'."
  }
}

variable "cluster_autoscaler_image_tag" {
  default = "v1.29.0"
}
