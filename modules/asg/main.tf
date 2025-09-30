### === SECURITY GROUP === #
/* Defines firewall rules to control inbound/outbound
traffic to the instances.*/
resource "aws_security_group" "webApp" {
  name        = "${var.name}-ec2-sg"
  vpc_id      = var.vpc_id
  description = "Allow HTTP traffic from ALB"

  ingress {                                                                // Allows forwarded HTTP traffic by the ALB to reach EC2s.
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    security_groups = [var.alb_sg_id]                                      // Only traffic coming from the ALB is authorized.
  }

  egress {                                                                 // No restrictions : security groups are stateful so what enters can leave.
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-ec2-sg" }
}


### === AUTO-SCALING GROUP === ###
// Ensures the correct number of EC2 instances are running.
resource "aws_autoscaling_group" "this" {
  name = "${var.name}-asg"

  min_size            = var.min_capacity
  max_size            = var.max_capacity
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.private_subnets_ids                              // Instances are launched in private subnets.

  launch_template {                                                          // Define which configuration template to use when launching instances.
    id      = aws_launch_template.webApp.id
    version = "$Latest"
  }

  target_group_arns = [var.tg_arn]                                            // Instances in the asg will receive traffic from the ALB.
  health_check_type         = "ELB"
  health_check_grace_period = 60                                              // Seconds to wait before evaluating health after launch to avoid inaccurate "unhealthy" status.

  lifecycle {
    create_before_destroy = true
  }

  tag {                                                                       // Apply tags automatically to instances created by the ASG.
    key                 = "Name"
    value               = "${var.name}-asg"
    propagate_at_launch = true
  }

}


### === AUTO-SCALING POLICY === ###
/* Dynamically adjusts the ASG size based on ALB request load.
Uses target tracking on the "ALBRequestCountPerTarget" metric.*/
resource "aws_autoscaling_policy" "alb_request_target" {
  autoscaling_group_name = aws_autoscaling_group.this.name
  name                   = "${var.name}-alb-requests"
  policy_type            = "TargetTrackingScaling"                          // Good AWS-recommended policy for unpredictable load

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"                   // AWS-recommended metric with "TargetTrackingScaling". Best suited for a web application when a lot of requests are forwarded.
      resource_label         = "${var.alb_arn_suffix}/${var.tg_arn_suffix}" // Also, ALBs do not necessarily distributes traffic equally so another metric like "CPUUtilization" would not be adequate.
    }

    target_value     = 100.0                                               // Scales to keep ~100 requests per instance
    disable_scale_in = false                                               // Allows removing instances when traffic decreases.
  }
}


### === LAUNCH TEMPLATE === ###
// Defines how EC2 instances are configured at launch
resource "aws_launch_template" "webApp" {
  name_prefix   = "${var.name}-lt"
  image_id      = var.ami
  instance_type = var.instance_type

  iam_instance_profile {                                                    // Grants access to SSM
    name = var.instance_profile_name
  }

  // User data script to install and configure Apache HTTP Server
  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd

              # Simple landing page displaying hostname
              echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
              EOF
  )

  network_interfaces {
    associate_public_ip_address = false                                     // Instances are private
    security_groups = [aws_security_group.webApp.id]                        // Attaches SG defined above
  }

  lifecycle {
    create_before_destroy = true
  }
}
