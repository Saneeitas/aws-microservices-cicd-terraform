output "ecr_repository_urls" {
  description = "ECR repository URL per service"
  value       = { for k, r in aws_ecr_repository.repo : k => r.repository_url }
}

output "log_group" {
  value = aws_cloudwatch_log_group.app.name
}

output "db_endpoint" {
  value = local.db_endpoint
}
