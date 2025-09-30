### === SECURITY GROUP === ###
/* Defines firewall rules to control inbound/outbound
traffic to the endpoints.*/
resource "aws_security_group" "endpoints" {
  name        = "${var.name}-endpoints-sg"
  vpc_id      = var.vpc_id
  description = "Allow HTTPS traffic from VPC to VPC Endpoints"

  ingress {                                                          // Allows VPC HTTPS traffic to reach endpoints
    from_port = 443                                                  // Traffic between services is crypted
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {                                                            // No restrictions : security groups are stateful so what enters can leave.
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-endpoints-sg" }
}


### === S3 ENDPOINT === ###
// Enables private access to S3 without using the internet.
resource "aws_vpc_endpoint" "s3" {
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"                                        // Gateway Endpoints are used for S3 and DynamoDB only.
  vpc_id            = var.vpc_id

  route_table_ids = var.private_rt_id                                  // Traffic is routed between private subnets and s3 via endpoint.

  tags = { Name = "${var.name}-s3-endpoint" }
}


### === EC2 MESSAGES ENDPOINT === ###
// Used by SSM agent to communicate with EC2 messages service privately.
resource "aws_vpc_endpoint" "ec2_messages" {
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"                                     // If the used service is not S3 or DynamoDB.
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnets_ids                         // Because instances are in private subnets
  security_group_ids = [aws_security_group.endpoints.id]                // Restrict inbound traffic to HTTPS
  private_dns_enabled = true                                            // Override public DNS with private DNS

  tags = { Name = "${var.name}-ec2messages-endpoint" }
}


### === SSM ENDPOINT === ###
// Allows EC2 instances in private subnets to communicate with SSM privately.
resource "aws_vpc_endpoint" "ssm" {
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnets_ids
  security_group_ids = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.name}-ssm-endpoint" }
}


### === SSM MESSAGES ENDPOINT === ###
// Required for Session Manager
resource "aws_vpc_endpoint" "ssmmessages" {
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnets_ids
  security_group_ids = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.name}-ssmmessages-endpoint" }
}