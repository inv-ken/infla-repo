terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.9.0"
    }
  }
  backend "s3" {
    bucket         = "inv-prd-s3-tfstate"
    key            = "portal.tfstate"
    region         = "ap-northeast-1"
    # dynamodb_table = "mc-prd-dynamodb-tfstate-lock"
  }
}

# Configure the AWS Provider
#変数持ってこないので直接設定する,ここがリソースを作成するリージョン指定
provider "aws" {
  region = "ap-northeast-1"
}