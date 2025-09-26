
# AWS Scalable Infra : ALB + SSM Maintenance + CloudWatch

## Sommaire
- [Introduction](#1-introduction)
- [Architecture Overview](#2-architecture-overview)
- [Features](#3-features)
- [Deployment Steps](#4-deployment-steps)
- [Usage & Maintenance](#5-usage--maintenance)
- [Alerts & Monitoring](#6-alerts--monitoring)
- [Improvements & Next Steps](#7-improvements--next-steps)
- [Conclusion](#8-conclusion)
- [References](#9-references)
  
## 1. Introduction 
    
Ce projet présente une architecture scalable, sécurisée et monitorée sur AWS.<a name="#1-introduction"></a>          
Il s'agit de déployer une application web derrière un Application Load Balancer (ALB) dans un VPC privé, avec un Auto Scaling Group d’instances EC2.   
La maintenance et la connectivité sont assurées via AWS Systems Manager (SSM), sans accès SSH direct, et la supervision est centralisée avec CloudWatch (métriques et alertes).   
   
## 2. Architecture Overview
    
<img width="2028" height="1049" alt="WebApp_EmailAlarm_SSMConnect drawio(1)" src="https://github.com/user-attachments/assets/7dbff49e-2482-492d-9902-2619b60d88c5" /> <a name="#2-architecture-overview"></a>    
      
### Composants principaux : 
   
:open_file_folder:[ALB (Application Load Balancer)](./modules/alb/main.tf) : routage du trafic HTTP/HTTPS   
```terraform
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  subnets            = var.public_subnets_ids
  internal           = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb.id]

  tags = { Name = "${var.name}-alb-tg" }
}
```

```terraform
resource "aws_lb_target_group" "alb" {
  name     = "${var.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 10
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
    matcher             = "200-399"
  }

  deregistration_delay = 60
}
```

```terraform
resource "aws_lb_listener" "alb" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb.arn
  }
}
```
  
:open_file_folder:[EC2 Auto Scaling Group](./modules/asg/main.tf) : ajustement automatique du nombre d’instances selon la charge.   
   
:open_file_folder:[Private Subnets](./modules/vpc/main.tf) : instances isolées du trafic direct Internet.   
   
:open_file_folder:[VPC Endpoints](./modules/vpc_endpoints/main.tf) : connectivité privée pour accéder à S3 (bootstrap) et SSM (maintenance).   
   
   
```terraform
resource "aws_vpc_endpoint" "s3" {
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  vpc_id            = var.vpc_id

  route_table_ids = var.private_rt_id

  tags = { Name = "${var.name}-s3-endpoint" }
}
```

```terraform
resource "aws_vpc_endpoint" "ssm" {
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnets_ids
  security_group_ids = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.name}-ssm-endpoint" }
}
```
   
:open_file_folder:[CloudWatch Monitoring](./modules/cloudwatch/main.tf) : suivi des métriques et configuration d’alarmes (erreurs 4XX).


## 3. Features
   
- Scalabilité : auto scaling des instances EC2 en fonction des besoins.<a name="#3-features"></a>      
- Sécurité : aucune exposition SSH, maintenance uniquement via SSM Session Manager.   
- Monitoring : alarme CloudWatch pour erreurs 4XX.   
- Optimisation : instances privées avec accès S3 via un vpc endpoint pour charger les fichiers de configuration au boot.


## 4. Deployment Steps
<a name="#4-deployment-steps"></a>   
### Prérequis
   
- Compte AWS actif.   
- AWS CLI configurée.   
- Terraform   
  
### Étapes de déploiement :     
1. Création du [VPC](./modules/vpc/main.tf) avec subnets publics et privés.
2. Mise en place des [VPC endpoints](./modules/vpc_endpoints/main.tf) SSM et S3.
3. Mettre en place l’[Application Load Balancer (ALB)](./modules/alb/main.tf).
4. Déployer un [Auto Scaling Group](./modules/asg/main.tf) d’instances EC2 dans les subnets privés.
```terraform
resource "aws_autoscaling_group" "this" {
  name = "${var.name}-asg"

  min_size            = var.min_capacity
  max_size            = var.max_capacity
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.private_subnets_ids

  launch_template {
    id      = aws_launch_template.webApp.id
    version = "$Latest"
  }

  target_group_arns = [var.tg_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 30

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-asg"
    propagate_at_launch = true
  }

}
```
```terraform

resource "aws_launch_template" "webApp" {
  name_prefix   = "${var.name}-lt"
  image_id      = var.ami
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd

              INSTANCE_ID = $(curl -s http://169.254.169.254/latest/meta-data/instance-id)


              echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
              EOF
  )

  network_interfaces {
    associate_public_ip_address = false
    security_groups = [aws_security_group.webApp.id]
  }

  lifecycle {
    create_before_destroy = true
  }
}
```
   
6. Configurer [CloudWatch Alarm](./modules/cloudwatch/main.tf) sur Target_4XXCount.
```terraform
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
```
   
8. Vérifier le fonctionnement :
- Accès applicatif via ALB.
- Connexion maintenance via SSM.
- Déclenchement de l’alarme en cas d’erreurs 4XX.

## 5. Usage & Maintenance
<a name="#5-usage--maintenance"></a>
- Accès aux instances : utiliser AWS Systems Manager → Session Manager (aucun besoin de clé SSH).
- Monitoring : suivre les métriques et alarmes dans CloudWatch Dashboard.
- Bonnes pratiques :
- IAM avec le principe de least privilege.
- Tagging des ressources pour une meilleure gestion.
- Logs centralisés (CloudWatch Logs).   


## 6. Alerts & Monitoring
<a name="#6-alerts--monitoring"></a>
- Alarme principale : Target_4XXCount déclenche une notification email via SNS si un seuil est dépassé.
- Extensions possibles :   
- Ajout d’alertes sur les 5XX errors.   
- Suivi de la latence des requêtes.   
- Création de dashboards personnalisés dans CloudWatch.   


## 7. Improvements & Next Steps
<a name="#7-improvements--next-steps"></a>
- Ajouter un WAF (Web Application Firewall) pour renforcer la sécurité.
- Configurer l’ALB en HTTPS avec un certificat ACM.
- Étendre le monitoring (logs applicatifs, métriques supplémentaires).   


> [!NOTE]
> 8. Conclusion
<a name="#8-conclusion"></a>
> - Résumé des points clés (scalabilité, sécurité, monitoring)
> - Valeur du projet pour ton portfolio


> [!NOTE]
> 9. References
<a name="#9-references"></a>
> > Application Load Balancer – AWS Docs
> > Auto Scaling Groups – AWS Docs
> > AWS Systems Manager (SSM)
> > Amazon CloudWatch Monitoring
