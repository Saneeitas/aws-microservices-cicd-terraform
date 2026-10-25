# Fail early with a clear message instead of a provider error mid-apply.
resource "terraform_data" "db_input_check" {
  lifecycle {
    precondition {
      condition     = !var.create_rds || length(var.db_password) >= 8
      error_message = "create_rds = true requires db_password (min 8 characters). Set TF_VAR_db_password."
    }
    precondition {
      condition     = var.create_rds || var.db_endpoint != ""
      error_message = "create_rds = false requires db_endpoint."
    }
  }
}

resource "aws_security_group" "rds" {
  count       = var.create_rds ? 1 : 0
  name        = "microservices-rds-sg"
  description = "MySQL from the microservices security group"
  vpc_id      = local.vpc_id

  tags = { Name = "microservices-rds-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "rds_mysql" {
  count = var.create_rds ? 1 : 0

  security_group_id            = aws_security_group.rds[0].id
  description                  = "MySQL from microservices-sg"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.microservices.id
}

resource "aws_db_subnet_group" "main" {
  count      = var.create_rds ? 1 : 0
  name       = "coffee-db-subnets"
  subnet_ids = local.public_subnet_ids
}

resource "aws_db_instance" "main" {
  count = var.create_rds ? 1 : 0

  identifier             = "coffee-suppliers"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "COFFEE"
  username               = "admin"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]
  publicly_accessible    = false
  skip_final_snapshot    = true # demo/reproducible environment; remove for production

  depends_on = [terraform_data.db_input_check]
}

locals {
  # Single DB host value for task definitions and docs, whichever mode is used.
  db_endpoint = var.create_rds ? aws_db_instance.main[0].address : var.db_endpoint
}
