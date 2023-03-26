module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${var.pjname}-${var.envname}-s3-portal"
  acl    = "private"

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    enabled = true
  }

  logging = {
    target_bucket = data.terraform_remote_state.common.outputs.access-log-bucket.s3_bucket_id
    target_prefix = "portal-s3/"
  }

}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    connection_attempts = 3
    connection_timeout  = 10
    domain_name         = module.s3_bucket.s3_bucket_bucket_regional_domain_name
    origin_id           = module.s3_bucket.s3_bucket_bucket_regional_domain_name

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/${aws_cloudfront_origin_access_identity.origin_access_identity.id}"
    }
  }
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = data.terraform_remote_state.common.outputs.access-log-bucket.s3_bucket_bucket_domain_name
    prefix          = "portal"
  }

  enabled         = true
  is_ipv6_enabled = true
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
    # acm_certificate_arn            = "arn:aws:acm:us-east-1:${data.aws_caller_identity.current.account_id}:certificate/${var.portal_certificate_id}"
    # minimum_protocol_version       = "TLSv1.2_2021"
    # ssl_support_method             = "sni-only"
  }

  default_cache_behavior {

    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = module.s3_bucket.s3_bucket_bucket_regional_domain_name

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }
  # aliases = [
  #   ".jp",
  # ]
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "access-identity-${var.pjname}-${var.envname}-s3-portal.s3.ap-northeast-1.amazonaws.com"
}

resource "aws_s3_bucket_policy" "bucket-policy" {
  bucket = module.s3_bucket.s3_bucket_id

  policy = <<POLICY
    {
    "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "1",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"
            },
            "Action": "s3:GetObject",
            "Resource": "${module.s3_bucket.s3_bucket_arn}/*"
        }
    ]
}
    POLICY

}