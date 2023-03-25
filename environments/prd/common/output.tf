# output "kms_arn" {
#   value = aws_kms_key.kms-key.arn
# }

# output "log_kms_arn" {
#   value = aws_kms_key.kms-key-log.arn
# }

# output "vpc_id" {
#   value       = module.vpc.vpc_id
#   description = "VPC IDs"
# }

output "access-log-bucket" {
  value       = module.accesslog-bucket
  description = "access log id"
}
