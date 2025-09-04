variable "lambda_vpc_cidr" {
  description = "CIDR block for Lambda VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "rds_vpc_cidr" {
  description = "CIDR block for RDS VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "lambda_subnet_a_cidr" {
  description = "CIDR block for Lambda subnet A"
  type        = string
  default     = "10.0.1.0/24"
}

variable "lambda_subnet_b_cidr" {
  description = "CIDR block for Lambda subnet B"
  type        = string
  default     = "10.0.2.0/24"
}

variable "rds_subnet_a_cidr" {
  description = "CIDR block for RDS subnet A"
  type        = string
  default     = "10.1.1.0/24"
}

variable "rds_subnet_b_cidr" {
  description = "CIDR block for RDS subnet B"
  type        = string
  default     = "10.1.2.0/24"
}