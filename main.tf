terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

### === APPLICATION LOAD BALANCER === ###
// Distributes incoming traffic across EC2 instances

module "alb" {
  source = "./modules/alb"

  name               = var.name
  public_subnets_ids = module.vpc.public_subnets_id            // ALB is deployed in public subnets
  vpc_id             = module.vpc.vpc_id                       // Attach ALB to the VPC
}

### === AUTO SCALING GROUP === ###
// Manages EC2 instances that automatically scale in/out based on defined capacity and traffic demands.

module "asg" {
  source = "./modules/asg"

  alb_arn_suffix        = module.alb.alb_arn_suffix             // Connect ASG to ALB
  alb_sg_id             = module.alb.alb_sg_id                  // Use ALB security group
  ami                   = "ami-03601e822a943105f"               // Amazon Linux 2023 kernel-6.1 : 2023 version is needed to ensure the SSM agent is already installed
  desired_capacity      = 2                                   
  instance_profile_name = module.ssm.instance_profile_name      // Grants access to SSM
  instance_type         = "t2.micro"
  min_capacity          = 2
  max_capacity          = 3
  name                  = var.name
  private_subnets_ids   = module.vpc.private_subnets_id        // Place EC2 in private subnets (not directly exposed to internet)
  tg_arn                = module.alb.tg_arn                    // Target Group for ALB traffic forwarding
  tg_arn_suffix         = module.alb.tg_arn_suffix
  vpc_id                = module.vpc.vpc_id
}

### === CLOUDWATCH ALARM === ###
// Sets up monitoring, logging, and alerting. Useful for tracking health, traffic, and security events.

module "cloudwatch" {
  source = "./modules/cloudwatch"

  alb_arn_suffix = module.alb.alb_arn_suffix
  name           = var.name
  log_group_name = "/aws/${var.name}/vpc_flowlogs"
  email_address  = var.email_address                         // Sends alerts to this email
  vpc_id         = module.vpc.vpc_id
}

### === SESSION MANAGER CONNECT === ###
// Provides secure management of EC2 instances without requiring SSH keys or direct internet access.

module "ssm" {
  source = "./modules/ssm"

  name      = var.name
  role_name = "ec2-private-ssm"                            // IAM role allowing SSM agent to connect
}

### === VIRTUAL PRIVATE CLOUD === ###
// Creates the network base with subnets and routing configuration.
module "vpc" {
  source = "./modules/vpc"

  azs = ["eu-west-3a", "eu-west-3b"]                      // 2 availibility zones for high availability
  name            = var.name
  public_subnets  = var.public_subnets                    // 2 public subnets for ALB
  private_subnets = var.private_subnets                   // 2 private subnets for ASG of EC2 instances
  vpc_cidr        = var.vpc_cidr
}

### === VPC ENDPOINTS === ###
// Creates private connections to S3 and SSM services.

module "vpc_endpoints" {
  source = "./modules/vpc_endpoints"

  name                = var.name
  private_rt_id       = module.vpc.private_rt_id
  private_subnets_ids = module.vpc.private_subnets_id
  region              = var.region
  vpc_cidr            = var.vpc_cidr
  vpc_id              = module.vpc.vpc_id
}
