data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_ecr_authorization_token" "token" {}

data "terraform_remote_state" "common" {
  backend = "s3"

  config = {
    bucket = "inv-prd-s3-tfstate"
    key    = "common.tfstate"
    region = "ap-northeast-1"
  }
}