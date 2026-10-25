variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# ---- Mode switches -------------------------------------------------------

variable "use_existing_vpc" {
  description = "true: look up an existing VPC named LabVPC and its public subnets. false: create VPC, 2 public subnets, IGW and route table."
  type        = bool
  default     = true
}

variable "use_existing_iam_roles" {
  description = "true: look up roles PipelineRole and DeployRole. false: create them (plus the EventBridge role and triggers)."
  type        = bool
  default     = true
}

variable "create_rds" {
  description = "true: create the MySQL instance. false: use var.db_endpoint."
  type        = bool
  default     = false
}

variable "create_cloud9" {
  description = "Create the MicroservicesIDE Cloud9 environment (AWS may not offer Cloud9 to new accounts)."
  type        = bool
  default     = false
}

# ---- Database ------------------------------------------------------------

variable "db_endpoint" {
  description = "Hostname of an existing MySQL database. Used when create_rds = false."
  type        = string
  default     = ""
}

variable "db_password" {
  description = "Master password for the created RDS instance. Required when create_rds = true."
  type        = string
  default     = ""
  sensitive   = true
}

# ---- Application ---------------------------------------------------------

variable "admin_allowed_cidr" {
  description = "If set (e.g. 203.0.113.25/32), /admin/* ALB rules only match this source CIDR."
  type        = string
  default     = ""

  validation {
    condition     = var.admin_allowed_cidr == "" || can(cidrhost(var.admin_allowed_cidr, 0))
    error_message = "admin_allowed_cidr must be empty or a valid CIDR such as 203.0.113.25/32."
  }
}

variable "customer_desired_count" {
  description = "Number of customer tasks (set to 3 to demonstrate scaling)."
  type        = number
  default     = 1
}

# ---- Network (only used when use_existing_vpc = false) -------------------

variable "vpc_cidr" {
  description = "CIDR of the created VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs of the two created public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs are required."
  }
}
