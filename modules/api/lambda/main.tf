resource "aws_ecr_repository" "this" {
  
  name = "${var.pjname}-${var.envname}-ecr-${var.name}"
  tags = merge(
    { "Name" = "${var.pjname}-${var.envname}-ecr-${var.name}" },
    { "Environment" = var.envname,
    "Region" = "apne1" }
  )

  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key
  }
}


resource "aws_ecr_lifecycle_policy" "foopolicy" {
  repository = aws_ecr_repository.this.name

  policy = <<EOF
    {
        "rules": [
            {
                "rulePriority": 1,
                "description": "Expire images older than 14 days",
                "selection": {
                    "tagStatus": "untagged",
                    "countType": "sinceImagePushed",
                    "countUnit": "days",
                    "countNumber": 14
                },
                "action": {
                    "type": "expire"
                }
            }
        ]
    }
    EOF
}

resource "null_resource" "this" {
  provisioner "local-exec" {
    command = <<-EOF
      docker build . -t ${aws_ecr_repository.this.repository_url}:latest; \
      docker login -u AWS -p ${var.token} ${var.endpoint}; \
      docker push ${aws_ecr_repository.this.repository_url}:latest;
    EOF
  }
}


# Lambda Role
resource "aws_iam_role" "this" {
  name = "${var.pjname}-${var.envname}-role-${var.name}"

  tags = merge(
    { "Name" = "${var.pjname}-${var.envname}-role-${var.name}" },
    { "Environment" = var.envname,
    "Region" = "apne1" }
  )

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
POLICY
}

data "aws_iam_policy_document" "this" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "secretsmanager:Describe*",
      "secretsmanager:Get*",
      "secretsmanager:List*",
      "kms:Decrypt",
      "s3:*",
      "s3-object-lambda:*"
    ]

    effect    = "Allow"
    resources = ["*"]
  }
}

# Lambda Attach Role to Policy
resource "aws_iam_role_policy" "this" {
  role   = aws_iam_role.this.id
  name   = "${var.pjname}-${var.envname}-policy-${var.name}"
  policy = data.aws_iam_policy_document.this.json

}