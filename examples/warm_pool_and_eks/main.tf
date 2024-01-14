module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnets
  tags            = var.tags

  cluster_addons = merge({
    coredns    = { addon_version = "v1.10.1-eksbuild.2" }
    kube-proxy = { addon_version = "v1.28.1-eksbuild.1" }
    vpc-cni    = { addon_version = "v1.14.1-eksbuild.1" }
    },
    var.pod_identity_type == "EKS_POD_IDENTITY" ? {
      eks-pod-identity-agent = { addon_version = "v1.0.0-eksbuild.1" }
    } : {}
  )

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  enable_irsa                     = var.pod_identity_type == "IRSA"
}

resource "aws_eks_pod_identity_association" "autoscaler" {
  count = var.pod_identity_type == "EKS_POD_IDENTITY" ? 1 : 0

  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = module.autoscaler.autoscaler_role_arn
}

module "warm_node_pool" {
  source = "../../modules/warm_node_group"

  region                     = var.region
  cluster_name               = module.eks.cluster_name
  cluster_version            = module.eks.cluster_version
  instance_type              = "t3a.large"
  subnet_ids                 = module.vpc.public_subnets
  vpc_security_group_ids     = [module.eks.cluster_primary_security_group_id, module.eks.cluster_security_group_id]
  token                      = data.aws_eks_cluster_auth.cluster.token
  cluster_endpoint           = module.eks.cluster_endpoint
  certificate_authority_data = module.eks.cluster_certificate_authority_data
  tags                       = var.tags
}

module "autoscaler" {
  source = "../../modules/autoscaler"

  cluster_name      = module.eks.cluster_name
  region            = var.region
  oidc_provider     = module.eks.oidc_provider
  pod_identity_type = var.pod_identity_type
}

module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "19.21.0"

  name                              = "addons"
  cluster_name                      = var.cluster_name
  cluster_version                   = var.cluster_version
  subnet_ids                        = module.vpc.public_subnets
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.cluster_security_group_id]
  instance_types                    = ["t3a.medium"]
  min_size                          = 1
  max_size                          = 1
  desired_size                      = 1
  tags                              = merge(var.tags, { Info = "eks-managed-node-group" })
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.4.0"

  name                    = "${var.cluster_name}-eks-vpc"
  cidr                    = "10.0.0.0/16"
  azs                     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  public_subnets          = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  map_public_ip_on_launch = true
  tags                    = var.tags
}

data "aws_eks_cluster_auth" "cluster" {
  name       = var.cluster_name
  depends_on = [module.eks]
}
