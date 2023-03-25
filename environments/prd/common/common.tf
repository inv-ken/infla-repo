# ログ保管用のS3
module "log-storage-bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${var.pjname}-${var.envname}-s3-log-storage"
  acl    = "private"

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.kms-key-log.arn
        sse_algorithm     = "aws:kms"
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
  tags = {
    "Name"        = "${var.pjname}-${var.envname}-s3-log-storage"
    "Environment" = var.envname,
    "Region"      = "apne1"
  }

  lifecycle_rule = [
    {
      abort_incomplete_multipart_upload_days = 0
      enabled                                = true
      id                                     = "${var.pjname}-${var.envname}-s3-log-storage-lifecycle"
      tags = {
        "Name"        = "${var.pjname}-${var.envname}-s3-log-storage-lifecycle"
        "Environment" = var.envname,
        "Region"      = "apne1"
      }
      transition = [
        {
          days          = 30
          storage_class = "GLACIER"
        }
      ]
      expiration = {
        days                         = 366
        expired_object_delete_marker = false
      }
    }
  ]
}

resource "aws_s3_bucket_policy" "log-storage-bucket-policy" {
  bucket = module.log-storage-bucket.s3_bucket_id
  policy = <<POLICY
    {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "AWSCloudTrailAclCheck20150319",
              "Effect": "Allow",
              "Principal": {
                 "Service": "cloudtrail.amazonaws.com"
              },
              "Action": "s3:GetBucketAcl",
              "Resource": "arn:aws:s3:::${var.pjname}-${var.envname}-s3-log-storage"
          },
          {
              "Sid": "AWSCloudTrailWrite20150319",
              "Effect": "Allow",
              "Principal": {
                "Service": "cloudtrail.amazonaws.com"
              },
              "Action": "s3:PutObject",
              "Resource": "arn:aws:s3:::${var.pjname}-${var.envname}-s3-log-storage/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
              "Condition": {
                  "StringEquals": {
                      "s3:x-amz-acl": "bucket-owner-full-control",
                      "AWS:SourceArn": [ "arn:aws:cloudtrail:ap-northeast-1:${data.aws_caller_identity.current.account_id}:trail/${var.pjname}-${var.envname}-cloud-trail",
                                         "arn:aws:cloudtrail:us-east-1:${data.aws_caller_identity.current.account_id}:trail/${var.pjname}-${var.envname}-cloud-trail"]
                  }
              }
          },
          {
        			"Sid": "AllowGuardDutygetBucketLocation",
        			"Effect": "Allow",
        			"Principal": {
        				"Service": [
        				  "guardduty.ap-northeast-1.amazonaws.com",
        				  "guardduty.us-east-1.amazonaws.com"
        				]
        			},
        			"Action": "s3:GetBucketLocation",
        			"Resource": "arn:aws:s3:::mc-prd-s3-log-storage",
        			"Condition": {
        				"StringEquals": {
        					"aws:SourceAccount": "${data.aws_caller_identity.current.account_id}",
        					"aws:SourceArn": [ 
        					  "arn:aws:guardduty:ap-northeast-1:${data.aws_caller_identity.current.account_id}:detector/${aws_guardduty_detector.tokyo-detector.id}",
        					  "arn:aws:guardduty:us-east-1:${data.aws_caller_identity.current.account_id}:detector/${aws_guardduty_detector.virginia-detector.id}"
        					]
        				}
        			}
        		},
        		{
        			"Sid": "AllowGuardDutyPutObject",
        			"Effect": "Allow",
        			"Principal": {
        				"Service": [
        				  "guardduty.ap-northeast-1.amazonaws.com",
        				  "guardduty.us-east-1.amazonaws.com"
        				]
        			},
        			"Action": "s3:PutObject",
        			"Resource": "arn:aws:s3:::mc-prd-s3-log-storage/*",
        			"Condition": {
        				"StringEquals": {
        					"aws:SourceAccount": "${data.aws_caller_identity.current.account_id}",
        					"aws:SourceArn": [ 
        					  "arn:aws:guardduty:ap-northeast-1:${data.aws_caller_identity.current.account_id}:detector/${aws_guardduty_detector.tokyo-detector.id}",
        					  "arn:aws:guardduty:us-east-1:${data.aws_caller_identity.current.account_id}:detector/${aws_guardduty_detector.virginia-detector.id}"
        					]
        				}
        			}
        		},
        		{
        			"Sid": "AWSConfigBucketPermissionsCheck",
        			"Effect": "Allow",
        			"Principal": {
        				"Service": "config.amazonaws.com"
        			},
        			"Action": "s3:GetBucketAcl",
        			"Resource": "arn:aws:s3:::${var.pjname}-${var.envname}-s3-log-storage"
        		},
        		{
        			"Sid": "AWSConfigBucketExistenceCheck",
        			"Effect": "Allow",
        			"Principal": {
        				"Service": "config.amazonaws.com"
        			},
        			"Action": "s3:ListBucket",
        			"Resource": "arn:aws:s3:::${var.pjname}-${var.envname}-s3-log-storage"
        		},
        		{
        			"Sid": "AWSConfigBucketDelivery",
        			"Effect": "Allow",
        			"Principal": {
        				"Service": "config.amazonaws.com"
        			},
        			"Action": "s3:PutObject",
        			"Resource": "arn:aws:s3:::${var.pjname}-${var.envname}-s3-log-storage/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*",
        			"Condition": {
        				"StringEquals": {
        					"s3:x-amz-acl": "bucket-owner-full-control"
        				}
        			}
        		}
      ]
    }
    POLICY
}

# ap-northeas-1のCloudtrailの設定
resource "aws_cloudtrail" "cloudtrail" {
  name                          = "${var.pjname}-${var.envname}-cloud-trail"
  s3_bucket_name                = module.log-storage-bucket.s3_bucket_id
  include_global_service_events = false
  enable_log_file_validation    = true

  advanced_event_selector {
    field_selector {
      equals = ["AWS::S3::Object"]
      field  = "resources.type"
    }
    field_selector {
      equals = ["Data"]
      field  = "eventCategory"
    }
  }

  advanced_event_selector {
    field_selector {
      equals = ["Management"]
      field  = "eventCategory"
    }
  }
}

# # us-east-1のCloudtrailの設定
# resource "aws_cloudtrail" "cloudtrail-virginia" {
#   provider                      = aws.east1
#   name                          = "${var.pjname}-${var.envname}-cloud-trail"
#   s3_bucket_name                = module.log-storage-bucket.s3_bucket_id
#   include_global_service_events = false
#   enable_log_file_validation    = true

#   advanced_event_selector {
#     field_selector {
#       equals = ["AWS::S3::Object"]
#       field  = "resources.type"
#     }
#     field_selector {
#       equals = ["Data"]
#       field  = "eventCategory"
#     }
#   }

#   advanced_event_selector {
#     field_selector {
#       equals = ["Management"]
#       field  = "eventCategory"
#     }
#   }
# }

# アクセスログ用のS3
# module "accesslog-bucket" {
#   source = "terraform-aws-modules/s3-bucket/aws"

#   bucket = "${var.pjname}-${var.envname}-s3-access-log"
#   acl    = "private"

#   server_side_encryption_configuration = {
#     rule = {
#       apply_server_side_encryption_by_default = {
#         sse_algorithm = "AES256"
#       }
#     }
#   }

#   # S3 bucket-level Public Access Block configuration
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true



#   versioning = {
#     enabled = true
#   }
#   tags = {
#     "Name"        = "${var.pjname}-${var.envname}-s3-access-log"
#     "Environment" = var.envname,
#     "Region"      = "apne1"
#   }
#   lifecycle_rule = [
#     {
#       abort_incomplete_multipart_upload_days = 0
#       enabled                                = true
#       id                                     = "${var.pjname}-${var.envname}-s3-access-log-lifecycle"
#       tags = {
#         "Name"        = "${var.pjname}-${var.envname}-s3-access-log-lifecycle"
#         "Environment" = var.envname,
#         "Region"      = "apne1"
#       }
#       transition = [
#         {
#           days          = 30
#           storage_class = "GLACIER"
#         }
#       ]
#       expiration = {
#         days                         = 366
#         expired_object_delete_marker = false
#       }
#     }
#   ]
# }

# resource "aws_s3_bucket_policy" "accesslog-bucket-policy" {
#   bucket = module.accesslog-bucket.s3_bucket_id
#   policy = <<POLICY
#     {
#       "Version": "2012-10-17",
#       "Id": "S3-Console-Auto-Gen-Policy-1645753762707",
#       "Statement": [
#         {
#           "Sid": "S3PolicyStmt-DO-NOT-MODIFY-1645753762508",
#           "Effect": "Allow",
#           "Principal": {
#             "Service": "logging.s3.amazonaws.com"
#           },
#           "Action": "s3:PutObject",
#           "Resource": "${module.accesslog-bucket.s3_bucket_arn}/*"
#         }
#       ]
#     }
#     POLICY
# }

# //KMS設定
# resource "aws_kms_key" "kms-key" {
#   description             = "Custumer Master Key"
#   enable_key_rotation     = true
#   is_enabled              = true
#   deletion_window_in_days = 30
#   # policy内の「"arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/mc-XXX-administrators-role"」は「アカウント種別」を示している点に注意すること
#   # CI環境の場合devとなる点に注意
#   policy                  = <<POLICY
#   {
#     "Id": "key-consolepolicy-3",
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Sid": "Enable IAM User Permissions",
#             "Effect": "Allow",
#             "Principal": {
#                 "AWS": [ "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root", 
#                          ]
#             },
#             "Action": "kms:*",
#             "Resource": "*"
#         },
#         {
#             "Sid": "Allow access for Key Administrators",
#             "Effect": "Allow",
#             "Principal": {
#                 "AWS": [
#                     "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/mc-prd-administrators-role",
#                     "arn:aws:iam::${data.aws_caller_identity.current.accou11nt_id}:user/administrator"
#                 ]
#             },
#             "Action": [
#                 "kms:Create*",
#                 "kms:Describe*",
#                 "kms:Enable*",
#                 "kms:List*",
#                 "kms:Put*",
#                 "kms:Update*",
#                 "kms:Revoke*",
#                 "kms:Disable*",
#                 "kms:Get*",
#                 "kms:Delete*",
#                 "kms:TagResource",
#                 "kms:UntagResource",
#                 "kms:ScheduleKeyDeletion",
#                 "kms:CancelKeyDeletion"
#             ],
#             "Resource": "*"
#         }
#     ]
# }
# POLICY

#   tags = {
#     "Name"        = "${var.pjname}-${var.envname}-kms"
#     "Environment" = var.envname,
#     "Region"      = "apne1"
#   }
# }

# resource "aws_kms_alias" "sample" {
#   name          = "alias/${var.pjname}-${var.envname}-kms"
#   target_key_id = aws_kms_key.kms-key.key_id
# }

# resource "aws_kms_key" "kms-key-log" {
#   description             = "Custumer Master Key"
#   enable_key_rotation     = true
#   is_enabled              = true
#   deletion_window_in_days = 30
#   # policy内の「"arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/mc-XXX-administrators-role"」は「アカウント種別」を示している点に注意すること
#   # CI環境の場合devとなる点に注意
#   policy                  = <<POLICY
#   {
#     "Id": "key-consolepolicy-3",
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Sid": "Enable IAM User Permissions",
#             "Effect": "Allow",
#             "Principal": {
#                 "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
#                 "Service": [ 
#                   "cloudtrail.amazonaws.com",
#                   "events.amazonaws.com",
#                   "guardduty.ap-northeast-1.amazonaws.com",
#                   "config.amazonaws.com"
#                 ]
#             },
#             "Action": "kms:*",
#             "Resource": "*"
#         },
#         {
#             "Sid": "Allow access for Key Administrators",
#             "Effect": "Allow",
#             "Principal": {
#                 "AWS": [
#                     "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/administrator",
#                     "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/mc-prd-administrators-role",
#                     "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/codeguru-reviewer.amazonaws.com/AWSServiceRoleForAmazonCodeGuruReviewer"
#                 ]
#             },
#             "Action": [
#                 "kms:Create*",
#                 "kms:Describe*",
#                 "kms:Enable*",
#                 "kms:List*",
#                 "kms:Put*",
#                 "kms:Update*",
#                 "kms:Revoke*",
#                 "kms:Disable*",
#                 "kms:Get*",
#                 "kms:Delete*",
#                 "kms:TagResource",
#                 "kms:UntagResource",
#                 "kms:ScheduleKeyDeletion",
#                 "kms:CancelKeyDeletion"
#             ],
#             "Resource": "*"
#         },
#         {
#             "Sid": "Allow VPC Flow Logs to use the key",
#             "Effect": "Allow",
#             "Principal": {
#                 "Service": [
#                     "logs.ap-northeast-1.amazonaws.com",
#                     "delivery.logs.amazonaws.com"
#                 ]
#             },
#            "Action": [
#                "kms:Encrypt",
#                "kms:Decrypt",
#                "kms:ReEncrypt*",
#                "kms:GenerateDataKey*",
#                "kms:DescribeKey"
#             ],
#             "Resource": "*"
#         },
#         {    
#             "Sid": "AllowGuardDutyKey",
#             "Effect": "Allow",
#             "Principal": {
#                 "Service": [
#                     "guardduty.us-east-1.amazonaws.com",
#                     "guardduty.ap-northeast-1.amazonaws.com"
#                 ]
#             },
#             "Action": "kms:GenerateDataKey",
#             "Resource": "*",
#             "Condition": {
#                 "StringEquals": {
#                     "aws:SourceAccount": "${data.aws_caller_identity.current.account_id}",
#                     "aws:SourceArn": [ 
#                       "arn:aws:guardduty:ap-northeast-1:${data.aws_caller_identity.current.account_id}:detector/${aws_guardduty_detector.tokyo-detector.id}",
#                       "arn:aws:guardduty:us-east-1:${data.aws_caller_identity.current.account_id}:detector/${aws_guardduty_detector.virginia-detector.id}"
#                     ]
#                 }
#             }
#         }
        
#     ]
# }
# POLICY

#   tags = {
#     "Name"        = "${var.pjname}-${var.envname}-log-kms"
#     "Environment" = var.envname,
#     "Region"      = "apne1"
#   }
# }

# resource "aws_kms_alias" "log" {
#   name          = "alias/${var.pjname}-${var.envname}-log-kms"
#   target_key_id = aws_kms_key.kms-key-log.key_id
# }


# # Lambda Attach Role to Policy
# resource "aws_iam_role_policy" "cognito" {
#   role   = aws_iam_role.cognito.id
#   name   = "${var.pjname}-${var.envname}-cognito"
#   policy = data.aws_iam_policy_document.cognito.json
# }

# // ACLの作成

# resource "aws_wafv2_web_acl" "ip-restriction" {
#   name        = "${var.pjname}-${var.envname}-api-gateway-ip-restriction"
#   description = "ip-address-restriction"
#   scope       = "REGIONAL"

#   default_action {
#     allow {}
#   }

#   rule {
#     name     = "ip-restriction"
#     priority = 1

#     action {
#       block {}
#     }

#     statement {
#       ip_set_reference_statement {
#         arn = aws_wafv2_ip_set.ip-restriction.arn
#       }
#     }

#     visibility_config {
#       cloudwatch_metrics_enabled = false
#       metric_name                = "${var.pjname}-${var.envname}-api-gateway-ip-restriction_metric"
#       sampled_requests_enabled   = false
#     }
#   }

#   visibility_config {
#     cloudwatch_metrics_enabled = false
#     metric_name                = "${var.pjname}-${var.envname}-api-gateway-ip-restriction_metric"
#     sampled_requests_enabled   = false
#   }
# }


# //IP制限

# resource "aws_wafv2_ip_set" "ip-restriction" {
#   name               = "ip-restriction"
#   description        = "ip-set"
#   scope              = "REGIONAL"
#   ip_address_version = "IPV4"

#   addresses = var.ip-restriction-rist
# }

# //マネージドルールの適用
# resource "aws_wafv2_web_acl" "web_acl" {
#   name        = "${var.pjname}-${var.envname}-web-acl"
#   description = "managed-rule"
#   scope       = "REGIONAL"

#   default_action {
#     allow {}
#   }


#   rule {
#     name     = "AWSManagedRulesSQLiRuleSet" //除外ルール無し
#     priority = 10

#     override_action {
#       count {}
#     }

#     statement {
#       managed_rule_group_statement {
#         name        = "AWSManagedRulesSQLiRuleSet"
#         vendor_name = "AWS"
#       }
#     }
#     visibility_config {
#       cloudwatch_metrics_enabled = false
#       metric_name                = "${var.pjname}-${var.envname}apigateway-ip-restriction_metric"
#       sampled_requests_enabled   = false
#     }
#   }

#   visibility_config {
#     cloudwatch_metrics_enabled = false
#     metric_name                = "${var.pjname}-${var.envname}apigateway-ip-restriction_metric"
#     sampled_requests_enabled   = false
#   }


#   rule {
#     name     = "AWSManagedRulesUnixRuleSet" //除外ルール無し
#     priority = 20

#     override_action {
#       count {}
#     }

#     statement {
#       managed_rule_group_statement {
#         name        = "AWSManagedRulesUnixRuleSet"
#         vendor_name = "AWS"
#       }
#     }

#     visibility_config {
#       cloudwatch_metrics_enabled = false
#       metric_name                = "${var.pjname}-${var.envname}apigateway-ip-restriction_metric"
#       sampled_requests_enabled   = false
#     }
#   }

#   rule {
#     name     = "AWSManagedRulesLinuxRuleSet" //除外ルール無し
#     priority = 30

#     override_action {
#       count {}
#     }

#     statement {
#       managed_rule_group_statement {
#         name        = "AWSManagedRulesLinuxRuleSet"
#         vendor_name = "AWS"
#       }
#     }
#     visibility_config {
#       cloudwatch_metrics_enabled = false
#       metric_name                = "${var.pjname}-${var.envname}apigateway-ip-restriction_metric"
#       sampled_requests_enabled   = false
#     }
#   }

#   rule {
#     name     = "AWSManagedRulesCommonRuleSet" //除外ルールあり
#     priority = 50

#     visibility_config {
#       cloudwatch_metrics_enabled = false
#       metric_name                = "${var.pjname}-${var.envname}apigateway-ip-restriction_metric"
#       sampled_requests_enabled   = false
#     }
#     override_action {
#       count {}
#     }

#     statement {
#       managed_rule_group_statement {
#         name        = "AWSManagedRulesCommonRuleSet"
#         vendor_name = "AWS"

#         excluded_rule {
#           name = "NoUserAgent_HEADER"
#         }
#         excluded_rule {
#           name = "UserAgent_BadBots_HEADER"
#         }
#         excluded_rule {
#           name = "SizeRestrictions_QUERYSTRING"
#         }
#         excluded_rule {
#           name = "EC2MetaDataSSRF_BODY"
#         }
#         excluded_rule {
#           name = "EC2MetaDataSSRF_QUERYARGUMENTS"
#         }
#       }
#     }
#   }


#   rule {
#     name     = "AWSManagedRulesKnownBadInputsRuleSet" //除外ルールあり
#     priority = 70

#     override_action {
#       count {}
#     }

#     statement {
#       managed_rule_group_statement {
#         name        = "AWSManagedRulesKnownBadInputsRuleSet"
#         vendor_name = "AWS"

#         excluded_rule {
#           name = "PROPFIND_METHOD"
#         }
#         excluded_rule {
#           name = "ExploitablePaths_URIPATH"
#         }
#       }
#     }
#     visibility_config {
#       cloudwatch_metrics_enabled = false
#       metric_name                = "${var.pjname}-${var.envname}apigateway-ip-restriction_metric"
#       sampled_requests_enabled   = false
#     }
#   }
# }