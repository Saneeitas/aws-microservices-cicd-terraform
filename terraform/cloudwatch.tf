resource "aws_cloudwatch_log_group" "app" {
  name              = "awslogs-capstone"
  retention_in_days = 7
}
