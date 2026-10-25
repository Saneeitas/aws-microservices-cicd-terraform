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

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecs_services" {
  value = { for k, s in aws_ecs_service.svc : k => s.name }
}

output "codecommit_clone_urls" {
  value = { for k, r in aws_codecommit_repository.repo : k => r.clone_url_http }
}
