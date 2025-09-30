### === CLOUDWATCH 4XX ALARM === ###
// Triggers an alert when the ALB returns a high number of client errors (HTTP 4XX).
resource "aws_cloudwatch_metric_alarm" "alb_4xx_alarm" {
  alarm_name          = "${var.name}-ALB-4xx-alarm"
  alarm_description   = "Alarm when ALB returns too many 4XX responses"
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"

  // Aggregate 4xx responses each minute
  evaluation_periods  = 1
  period              = 60
  statistic           = "Sum"

  // Trigger alarm if 10 or more 4xx errors in one period. This value is low here for testing purposes, it would be higher in a production environment.
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 10

  dimensions = { LoadBalancer = var.alb_arn_suffix }                 // Specify which ALB to monitor
  alarm_actions = [aws_sns_topic.alerts.arn]                         // When alarm is triggered : sends mail via SNS
}


### === SNS ALERTS TOPIC === ###
// Notification channel for sending alerts
resource "aws_sns_topic" "alerts" {
  name = "vpc_alerts_${var.name}"
}


### === SNS EMAIL SUBSCRIPTION === ###
// Connects the SNS topic to an email address
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn                             // To which topic this email address is linked
  protocol  = "email"
  endpoint  = var.email_address
}

