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


module "alb" {
  source = "./modules/alb"

  name               = var.name
  public_subnets_ids = module.vpc.public_subnets_id
  vpc_id             = module.vpc.vpc_id
}

module "asg" {
  source = "./modules/asg"

  alb_arn_suffix        = module.alb.alb_arn_suffix
  alb_sg_id             = module.alb.alb_sg_id
  ami                   = "ami-03601e822a943105f"
  desired_capacity      = 2
  instance_profile_name = module.ssm.instance_profile_name
  instance_type         = "t2.micro"
  min_capacity          = 2
  max_capacity          = 3
  name                  = var.name
  private_subnets_ids   = module.vpc.private_subnets_id
  tg_arn                = module.alb.tg_arn
  tg_arn_suffix         = module.alb.tg_arn_suffix
  vpc_id                = module.vpc.vpc_id
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  alb_arn_suffix = module.alb.alb_arn_suffix
  name           = var.name
  log_group_name = "/aws/${var.name}/vpc_flowlogs"
  email_address  = var.email_address
  vpc_id         = module.vpc.vpc_id
}

module "ssm" {
  source = "./modules/ssm"

  name      = var.name
  role_name = "ec2-private-ssm"
}

module "vpc" {
  source = "./modules/vpc"

  azs = ["eu-west-3a", "eu-west-3b"]
  name            = var.name
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  vpc_cidr        = var.vpc_cidr
}

module "vpc_endpoints" {
  source = "./modules/vpc_endpoints"

  name                = var.name
  private_rt_id       = module.vpc.private_rt_id
  private_subnets_ids = module.vpc.private_subnets_id
  region              = var.region
  vpc_cidr            = var.vpc_cidr
  vpc_id              = module.vpc.vpc_id
}
