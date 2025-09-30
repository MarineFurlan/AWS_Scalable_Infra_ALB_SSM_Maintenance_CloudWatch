### === SECURITY GROUP === #
/* Defines firewall rules to control inbound/outbound
traffic to the Load Balancer.*/
resource "aws_security_group" "alb" {
  vpc_id      = var.vpc_id
  name        = "${var.name}-alb-tg"
  description = "Allow HTTP traffic from internet"

  ingress {                                                   // allows any client having the alb's dns name to connect to the server over the internet.
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {                                                    // No restrictions : security groups are stateful so what enters can leave.
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-alb-tg" }
}



### === APPLICATION LOAD BALANCER === ###
// Attached to the security group above
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  subnets            = var.public_subnets_ids                 // 2 public subnets are needed for every ALB
  internal           = false                                  // Is in public subnets so it can be accessed by a client.
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb.id]               // Attaches the security group written above.

  tags = { Name = "${var.name}-alb-tg" }
}



### === ALB LISTENER === ###
/* What kind of incoming traffic the ALB will distributes
to its target group.*/
resource "aws_lb_listener" "alb" {                            // Distributes HTTP traffic on port 80.
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"                              // To distributes traffic among a target group
    target_group_arn = aws_lb_target_group.alb.arn
  }
}



### === TARGET GROUP === ###
/* Defines the group of instances that will receive the
traffic from the ALB. Also configures health checks */
resource "aws_lb_target_group" "alb" {
  name     = "${var.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {                                              // Ensures only healthy EC2s receive traffic
    path                = "/"
    interval            = 10                                  // All those parameters are quite low to ensure a fast detection of unhealthy instances. It avoids 5xx errors when instances shut down.
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
    matcher             = "200-399"                           // Acceptable HTTP status codes
  }

  deregistration_delay = 60                                   // Instances end their connections before being removed : Avoids routing to instances in shutdown.
}