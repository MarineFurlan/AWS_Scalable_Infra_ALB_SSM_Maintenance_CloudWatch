resource "aws_security_group" "endpoints" {
  name        = "${var.name}-endpoints-sg"
  vpc_id      = var.vpc_id
  description = "Allow HTTPS traffic from VPC to VPC Endpoints"

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-endpoints-sg" }
}

resource "aws_vpc_endpoint" "s3" {
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  vpc_id            = var.vpc_id

  route_table_ids = var.private_rt_id

  tags = { Name = "${var.name}-s3-endpoint" }
}

resource "aws_vpc_endpoint" "ec2_messages" {
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnets_ids
  security_group_ids = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.name}-ec2messages-endpoint" }
}

resource "aws_vpc_endpoint" "ssm" {
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnets_ids
  security_group_ids = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.name}-ssm-endpoint" }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnets_ids
  security_group_ids = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.name}-ssmmessages-endpoint" }
}