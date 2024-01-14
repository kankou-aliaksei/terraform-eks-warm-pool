locals {
  cluster_name               = var.cluster_name
  region                     = var.region
  cluster_version            = data.aws_eks_cluster.cluster.version
  cluster_endpoint           = data.aws_eks_cluster.cluster.endpoint
  certificate_authority_data = data.aws_eks_cluster.cluster.certificate_authority[0].data
  subnet_ids                 = data.aws_eks_cluster.cluster.vpc_config[0].subnet_ids
  security_group_ids = concat(
    [data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id],
    tolist(data.aws_eks_cluster.cluster.vpc_config[0].security_group_ids)
  )
  token         = data.aws_eks_cluster_auth.cluster.token
  oidc_provider = replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
}

data "aws_eks_cluster" "cluster" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = local.cluster_name
}

module "warm_node_group" {
  source = "../../modules/warm_node_group"

  region                     = local.region
  cluster_name               = local.cluster_name
  cluster_version            = local.cluster_version
  instance_type              = "t3a.large"
  subnet_ids                 = local.subnet_ids
  vpc_security_group_ids     = local.security_group_ids
  token                      = local.token
  cluster_endpoint           = local.cluster_endpoint
  certificate_authority_data = local.certificate_authority_data
  tags                       = var.tags
}

module "autoscaler" {
  source = "../../modules/autoscaler"
  count  = var.enable_autoscaler ? 1 : 0

  cluster_name  = local.cluster_name
  region        = local.region
  oidc_provider = local.oidc_provider
}
