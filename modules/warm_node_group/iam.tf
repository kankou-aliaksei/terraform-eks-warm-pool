data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  partition    = data.aws_partition.current.partition
  region       = var.region
  cluster_name = var.cluster_name

  policy_vars = {
    Region      = local.region
    AccountId   = local.account_id
    Partition   = local.partition
    ClusterName = local.cluster_name
    LambdaName  = local.function_name
  }
}

resource "aws_iam_policy" "warm_pool" {
  name        = "${local.cluster_name}WarmPool"
  description = "Additional policy to enable warm pools"
  policy      = templatefile("${path.module}/policies/WarmPool.json", local.policy_vars)
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "${local.cluster_name}_config_map_update"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "lambda.amazonaws.com" },
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "${local.cluster_name}_config_map_update"
  role   = aws_iam_role.lambda_execution_role.id
  policy = templatefile("${path.module}/policies/AwsAuthLambda.json", local.policy_vars)
}
