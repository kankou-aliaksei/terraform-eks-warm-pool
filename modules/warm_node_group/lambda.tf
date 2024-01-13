locals {
  function_name = "${var.cluster_name}-eks-auth"
}

data "archive_file" "aws_auth_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/eks_config_map_updater/src/lambda.py"
  output_path = "${path.module}/dist/lambda.zip"
}

resource "aws_lambda_function" "config_map_updater" {
  function_name    = local.function_name
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "lambda.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.aws_auth_lambda_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.aws_auth_lambda_zip.output_path)

  environment {
    variables = {
      KUBE_API_ENDPOINT = var.cluster_endpoint
    }
  }
}

resource "aws_lambda_invocation" "config_map_updater_invocation" {
  function_name = aws_lambda_function.config_map_updater.function_name
  input = jsonencode({
    token    = var.token
    role_arn = module.self_managed_node_group.iam_role_arn
  })
  depends_on = [module.self_managed_node_group]
}
