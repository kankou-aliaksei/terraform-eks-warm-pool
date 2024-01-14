locals {
  policy_context = {
    Partition    = data.aws_partition.current.partition
    DnsSuffix    = data.aws_partition.current.dns_suffix
    Region       = var.region
    AccountId    = data.aws_caller_identity.current.account_id
    ClusterName  = var.cluster_name
    OidcProvider = var.oidc_provider
  }
  trust_policy_path = var.pod_identity_type == "IRSA" ? "${path.module}/policies/IrsaTrust.json" : "${path.module}/policies/EksPodIdentitiesTrust.json"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "aws_iam_role" "autoscaler" {
  name               = "${var.cluster_name}_AutoscalerRole"
  assume_role_policy = templatefile(local.trust_policy_path, local.policy_context)
}

resource "aws_iam_policy" "autoscaler" {
  name   = "${var.cluster_name}_AutoscalerPolicy"
  policy = templatefile("${path.module}/policies/Autoscaler.json", local.policy_context)
}

resource "aws_iam_role_policy_attachment" "autoscaler_attachment" {
  role       = aws_iam_role.autoscaler.name
  policy_arn = aws_iam_policy.autoscaler.arn
}

output "autoscaler_role_arn" {
  value = aws_iam_role.autoscaler.arn
}
