# Created only when use_existing_vpc = false. Tasks get public IPs, so no NAT.

resource "aws_vpc" "main" {
  count                = var.use_existing_vpc ? 0 : 1
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "LabVPC" }
}

resource "aws_internet_gateway" "main" {
  count  = var.use_existing_vpc ? 0 : 1
  vpc_id = aws_vpc.main[0].id

  tags = { Name = "LabVPC-igw" }
}

resource "aws_subnet" "public" {
  count                   = var.use_existing_vpc ? 0 : 2
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "Public Subnet ${count.index + 1}" }
}

resource "aws_route_table" "public" {
  count  = var.use_existing_vpc ? 0 : 1
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = { Name = "Public Route Table" }
}

resource "aws_route_table_association" "public" {
  count          = var.use_existing_vpc ? 0 : 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# ---- Security group (always created) --------------------------------------
# One SG shared by the ALB and the ECS tasks, as in the lab.
resource "aws_security_group" "microservices" {
  name        = "microservices-sg"
  description = "ALB and ECS tasks: HTTP 80 and 8080"
  vpc_id      = local.vpc_id

  tags = { Name = "microservices-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(["80", "8080"])

  security_group_id = aws_security_group.microservices.id
  description       = "HTTP ${each.key} from anywhere"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.microservices.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
