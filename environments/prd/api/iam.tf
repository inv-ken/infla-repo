resource "aws_iam_role" "apigateway_putlog" {
  name = "${var.pjname}-${var.envname}-role-AmazonAPIGatewayPushToCloudWatchLogs"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "apigateway_putlog" {
  role       = aws_iam_role.apigateway_putlog.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "my_api" {
  cloudwatch_role_arn = aws_iam_role.apigateway_putlog.arn
}