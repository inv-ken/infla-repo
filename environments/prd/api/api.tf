resource "aws_api_gateway_rest_api" "internal-info-api" {
  name = "${var.pjname}-${var.envname}-api-internal-info-operation"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  policy = data.aws_iam_policy_document.internal-info-api.json
}

data "aws_iam_policy_document" "internal-info-api" {
  statement {
    effect = "Allow"
    principals {
      type = "*"
      identifiers = [
        "*",
      ]
    }
    actions = [
      "execute-api:Invoke",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_api_gateway_deployment" "internal-info-api" {
  rest_api_id = aws_api_gateway_rest_api.internal-info-api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.internal-info-api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_api_gateway_integration.internal-info-operation-integration
  ]
}

resource "aws_api_gateway_stage" "internal-info-api" {
  deployment_id        = aws_api_gateway_deployment.internal-info-api.id
  rest_api_id          = aws_api_gateway_rest_api.internal-info-api.id
  stage_name           = var.envname
  xray_tracing_enabled = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigateway_accesslog.arn
    format          = replace(file("${path.module}/logformat.json"), "\n", "")
  }
}

resource "aws_api_gateway_method_settings" "internal-info-api" {
  rest_api_id = aws_api_gateway_rest_api.internal-info-api.id
  stage_name  = aws_api_gateway_stage.internal-info-api.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "ERROR"
    data_trace_enabled = true
  }
}

resource "aws_cloudwatch_log_group" "apigateway_executionlog" {
  name = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.internal-info-api.id}/${var.envname}"
  # kms_key_id        = data.terraform_remote_state.common.outputs.log_kms_arn
  retention_in_days = 1827
}


resource "aws_cloudwatch_log_group" "apigateway_accesslog" {
  name = "API-Gateway-Access-Logs_${aws_api_gateway_rest_api.internal-info-api.id}/${var.envname}"
  # kms_key_id        = data.terraform_remote_state.common.outputs.log_kms_arn
  retention_in_days = 1827
}


locals {
  apis = {
    "register" = [
      aws_api_gateway_resource.register.id,
      "POST",
      module.lambda_function["register"]
    ],
  }
}

resource "aws_api_gateway_method" "internal-info-operation-method" {
  for_each = local.apis

  rest_api_id   = aws_api_gateway_rest_api.internal-info-api.id
  resource_id   = each.value[0]
  http_method   = each.value[1]
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "internal-info-operation-integration" {
  for_each = local.apis

  rest_api_id             = aws_api_gateway_rest_api.internal-info-api.id
  resource_id             = each.value[0]
  http_method             = aws_api_gateway_method.internal-info-operation-method[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value[2].lambda_function_invoke_arn
}

# # Lambda
resource "aws_lambda_permission" "internal-info-operation-apigw_lambda" {
  for_each = local.apis

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = each.value[2].lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.internal-info-api.id}/*/*"
}

module "cors" {
  source = "../../../modules/api/cors"

  for_each = local.apis

  api      = aws_api_gateway_rest_api.internal-info-api.id
  resource = each.value[0]

  methods = [each.value[1]]
}