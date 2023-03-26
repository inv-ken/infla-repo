locals {
  lambdas = {
    ## [ name, vpc_subnet_ids, vpc_security_group_ids, environment_variables ]
    # 3 事業者検索
    "register" = [
      "register",
      # data.terraform_remote_state.common.outputs.private_api_subnets,
      # [data.terraform_remote_state.common.outputs.vpc_lambda_sg_id],
      # { "secret_name" = data.terraform_remote_state.db.outputs.rds-proxy-secret-arn },
    ],
  }
}

module "this" {
  source = "../../../modules/api/lambda"

  for_each = local.lambdas

  pjname  = var.pjname
  envname = var.envname
  #   変更する
  name = each.value[0]
  # kms_key  = data.terraform_remote_state.common.outputs.kms_arn
  token    = data.aws_ecr_authorization_token.token.password
  endpoint = data.aws_ecr_authorization_token.token.proxy_endpoint
}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  for_each = local.lambdas

  function_name  = "${var.pjname}-${var.envname}-lambda-${each.value[0]}"
  description    = "${var.pjname}-${var.envname}-lambda-${each.value[0]}"
  create_role    = false
  lambda_role    = module.this[each.key].iam_role_arn
  create_package = false
  image_uri      = "${module.this[each.key].repository_url}:latest"
  package_type   = "Image"
  timeout        = 60

  # cloudwatch_logs_kms_key_id        = data.terraform_remote_state.common.outputs.log_kms_arn
  # cloudwatch_logs_retention_in_days = 1827

  # vpc_subnet_ids         = each.value[1]
  # vpc_security_group_ids = each.value[2]

  # environment_variables = each.value[3]

  tracing_mode = "Active"

  tags = merge(
    { "Name" = "${var.pjname}-${var.envname}-lambda-${each.value[0]}" },
    { "Environment" = var.envname,
    "Region" = "apne1" }
  )
}