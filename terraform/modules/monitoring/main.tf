# SNS Topic
resource "aws_sns_topic" "notifications" {
  name = "csv-processor-notifications"

  tags = {
    Name = "csv-processor-sns-topic"
  }
}

# SNS Topic Subscription - Primary Email
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# CloudWatch Alarm for Lambda Errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "csv-processor-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.alarm_period
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "This metric monitors Lambda function errors"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = [aws_sns_topic.notifications.arn]

  tags = {
    Name = "csv-processor-error-alarm"
  }
}

# CloudWatch Alarm for Lambda Duration
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "csv-processor-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.duration_threshold
  alarm_description   = "This metric monitors Lambda function duration"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = [aws_sns_topic.notifications.arn]

  tags = {
    Name = "csv-processor-duration-alarm"
  }
}