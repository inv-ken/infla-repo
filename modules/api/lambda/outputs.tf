output "repository_url" {
  value       = aws_ecr_repository.this.repository_url
}

output "iam_role_arn" {
  value       = aws_iam_role.this.arn
}

output "iam_role_id" {
  value       = aws_iam_role.this.id
}