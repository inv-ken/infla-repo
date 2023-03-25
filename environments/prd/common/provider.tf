terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    bucket         = "inv-prd-s3-tfstate"
    key            = "common.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "inv-prd-dynamodb-tfstate-lock"
  }
}

# Configure the AWS Provider
#変数持ってこないので直接設定する,ここがリソースを作成するリージョン指定
provider "aws" {
  region = "ap-northeast-1"
}

provider "aws" {
  alias  = "east1"
  region = "us-east-1"
}