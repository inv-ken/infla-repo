# /corp
resource "aws_api_gateway_resource" "register" {
  rest_api_id = aws_api_gateway_rest_api.internal-info-api.id
  parent_id   = aws_api_gateway_rest_api.internal-info-api.root_resource_id
  path_part   = "register"
}

