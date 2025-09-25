resource "aws_cloudwatch_metric_alarm" "alb_4xx_alarm" {
  alarm_name          = "${var.name}-ALB-4xx-alarm"
  alarm_description   = "Alarm when ALB returns too many 4XX responses"
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  evaluation_periods  = 1
  period              = 60
  statistic           = "Sum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 10
  dimensions = { LoadBalancer = var.alb_arn_suffix }
  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_sns_topic" "alerts" {
  name = "vpc_alerts_${var.name}"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.email_address
}

