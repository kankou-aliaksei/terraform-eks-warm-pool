module "self_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/self-managed-node-group"
  version = "19.21.0"

  name                = "${var.cluster_name}-ng"
  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  cluster_endpoint    = var.cluster_endpoint
  cluster_auth_base64 = var.certificate_authority_data

  subnet_ids = var.subnet_ids

  vpc_security_group_ids = var.vpc_security_group_ids

  min_size     = 0
  max_size     = 1
  desired_size = 0

  warm_pool = {
    pool_state                  = "Stopped"
    min_size                    = 1
    max_group_prepared_capacity = -1
  }

  instance_type = var.instance_type

  iam_role_additional_policies = {
    "ssm"       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    "warm-pool" = aws_iam_policy.warm_pool.arn
  }

  autoscaling_group_tags = {
    "k8s.io/cluster-autoscaler/enabled": true,
    "k8s.io/cluster-autoscaler/${var.cluster_name}": "owned"
  }

  initial_lifecycle_hooks = [
    {
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      name                 = "finish_user_data"
    }
  ]

  pre_bootstrap_user_data  = file("${path.module}/user_data/pre_bootstrap_user_data.sh")
  post_bootstrap_user_data = file("${path.module}/user_data/post_bootstrap_user_data.sh")

  block_device_mappings = {
    xvda = {
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = 50
        volume_type           = "gp2"
        delete_on_termination = true
        encrypted             = false // For hibernation, the root device volume must be encrypted.
      }
    }
  }
}
