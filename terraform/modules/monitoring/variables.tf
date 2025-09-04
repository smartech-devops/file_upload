variable "notification_email" {
  description = "Email address for SNS notifications"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to monitor"
  type        = string
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarms"
  type        = number
  default     = 1
}

variable "alarm_period" {
  description = "Period in seconds for alarm evaluation"
  type        = number
  default     = 300
}

variable "error_threshold" {
  description = "Threshold for error count alarm"
  type        = number
  default     = 0
}

variable "duration_threshold" {
  description = "Threshold for duration alarm in milliseconds"
  type        = number
  default     = 5000
}