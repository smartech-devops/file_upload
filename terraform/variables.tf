variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}


variable "notification_email" {
  description = "Email address for SNS notifications"
  type        = string
  default     = "smartech.devops.test@gmail.com"
}

