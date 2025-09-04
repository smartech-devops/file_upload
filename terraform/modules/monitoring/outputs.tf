output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.notifications.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.notifications.name
}

output "error_alarm_arn" {
  description = "ARN of the error alarm"
  value       = aws_cloudwatch_metric_alarm.lambda_errors.arn
}

output "duration_alarm_arn" {
  description = "ARN of the duration alarm"
  value       = aws_cloudwatch_metric_alarm.lambda_duration.arn
}