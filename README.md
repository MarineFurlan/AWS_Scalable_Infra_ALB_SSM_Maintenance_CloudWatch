
# AWS Scalable Infra : ALB + SSM Maintenance + CloudWatch
<br/>
<br/>
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;<img width="107" height="60" alt="Amazon-Web-Services-AWS-Logo" src="https://github.com/user-attachments/assets/f7829385-3361-48fc-8099-849da5534de5" />
&emsp;<img width="75" height="86" alt="Terraform-Logo" src="https://github.com/user-attachments/assets/b037706b-3866-4376-9b2d-55c91b6dafc0" />


## Sommaire
- [Introduction](#1-introduction)
- [Design Decisions](#2-design-decisions)
- [Architecture Overview](#3-architecture-overview)
- [Features](#4-features)
- [Deployment Steps](#5-deployment-steps)
- [Usage & Maintenance](#6-usage--maintenance)
- [Alerts & Monitoring](#7-alerts--monitoring)
- [Improvements & Next Steps](#8-improvements--next-steps)
- [Conclusion](#9-conclusion)
- [References](#10-references)
<br/>
<br/>
<br/>

## 1. Introduction 
<a name="#1-introduction"></a>     
&emsp;&emsp;Ce projet présente une architecture scalable, sécurisée et monitorée sur AWS.         
Il s'agit de déployer une application web derrière un Application Load Balancer (ALB) dans un VPC privé, avec un Auto Scaling Group d’instances EC2.   
La maintenance et la connectivité sont assurées via AWS Systems Manager (SSM), sans accès SSH direct, et la supervision est centralisée avec CloudWatch (métriques et alertes).  
<br/>
<br/>

## 2. Design Decisions   
<a name="#2-design-decisions"></a>
### <ins>Terraform</ins>
&emsp;&emsp;L'utilisation d'Infrastructure as Code permet de versionner et reproduire facilement l’environnement, créer des modules réutilisables, déployer de manière automatisée en respectant les bonnes pratiques cloud et détruire l'infrastructure en une seule commande lorsqu'elle n'est plus nécessaire afin de respecter un budget.    

### <ins>2 subnets privés pour l’ASG</ins>
&emsp;&emsp;Ce choix permet de garantir la haute disponibilité et la résilience de l’application en cas de panne d’une AZ. Cela s’aligne sur les bonnes pratiques AWS pour les architectures critiques.

### <ins>VPC Endpoint S3 plutôt qu’une NAT Gateway (coût et besoin limité d’accès Internet)</ins> 
&emsp;&emsp;Les instances EC2 sont déployées dans des subnets privés et n’ont pas besoin d’un accès Internet permanent.    
Plutôt que de créer une NAT Gateway (qui génère des coûts supplémentaires), un VPC Endpoint S3 a été utilisé pour permettre le bootstrap et l’accès aux artefacts stockés dans S3 de manière sécurisée et privée.  
Cette solution est à la fois économique et conforme aux bonnes pratiques de sécurité AWS pour les environnements privés.  
  
### <ins>Session Manager pour ajouter de la securité en fermant le port SSH</ins>
&emsp;&emsp;Pour limiter l’exposition des instances, le port SSH 22 reste fermé.  
L’accès est géré via AWS Systems Manager Session Manager, ce qui permet d’effectuer la maintenance et le debug directement depuis la console ou l’interface CLI, sans ouvrir de ports réseau.  
Ce choix renforce la sécurité et simplifie la gestion des accès tout en restant compatible avec les meilleures pratiques de gouvernance AWS.  
  
### <ins>Alarme CloudWatch unique pour simplifier la démonstration</ins>
&emsp;&emsp;Pour ce projet, une seule alarme CloudWatch a été créée sur le compteur d’erreurs 4XX.  
L’objectif est de démontrer le mécanisme de monitoring et de notification sans complexifier le déploiement ni augmenter les coûts.  
Cette approche permet de montrer la logique de création et de gestion des alarmes, tout en restant extensible et reproductible pour d’autres métriques ou besoins futurs. 
<br/>
<br/>
<br/>

## 3. Architecture Overview
<a name="#3-architecture-overview"></a>      
<img width="2028" height="1049" alt="WebApp_EmailAlarm_SSMConnect drawio(1)" src="https://github.com/user-attachments/assets/7dbff49e-2482-492d-9902-2619b60d88c5" />   
      
### Composants principaux : 
   
:open_file_folder:[ALB (Application Load Balancer)](./modules/alb/main.tf) : routage du trafic
<details>
  
<summary>See ALB code</summary>
  
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

</details>

<details>
  
<summary>See target group code</summary>

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
</details>

<details>
  
<summary>See listener code</summary>

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
 </details> 
 
:open_file_folder:[EC2 Auto Scaling Group](./modules/asg/main.tf) : ajustement automatique du nombre d’instances selon la charge.   
   
:open_file_folder:[Private Subnets](./modules/vpc/main.tf) : instances isolées du trafic direct Internet.   
   
:open_file_folder:[VPC Endpoints](./modules/vpc_endpoints/main.tf) : connectivité privée pour accéder à S3 (bootstrap) et SSM (maintenance).   
> [!NOTE]
> Pour comprendre le choix d’utiliser ces deux VPC endpoints plutôt qu'une NAT Gateway ou une connexion en SSH, voir la section (voir [Design Decisions](#2-design-decisions)). 

<details>
  
<summary>See VPC endpoint for s3 code</summary>

```terraform
resource "aws_vpc_endpoint" "s3" {
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  vpc_id            = var.vpc_id

  route_table_ids = var.private_rt_id

  tags = { Name = "${var.name}-s3-endpoint" }
}
```
</details>

<details>
  
<summary>See VPC endpoint for ssm code</summary>

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
</details>

:open_file_folder:[CloudWatch Monitoring](./modules/cloudwatch/main.tf) : suivi des métriques et configuration d’alarmes (erreurs 4XX).
<br/>
<br/>
<br/>

## 4. Features
<a name="#4-features"></a>    
- **Scalabilité** : auto scaling des instances EC2 en fonction des besoins.
- **Haute disponibilité** : Les instances de l’ASG sont déployées sur deux subnets privés dans des Availability Zones différentes, assurant la résilience et la continuité du service. 
- **Sécurité** : aucune exposition SSH, maintenance uniquement via SSM Session Manager.   
- **Monitoring** : alarme CloudWatch pour erreurs 4XX.
- **Reproductibilité et automatisation** : déploiement automatisé et reproductible via Terraform.   
- **Optimisation** : instances privées avec accès S3 via un vpc endpoint pour charger les fichiers de configuration au boot.

<br/>
<br/>
<br/>

## 5. Deployment Steps
<a name="#5-deployment-steps"></a>
&emsp;&emsp;L’infrastructure est déployée avec Terraform, permettant un déploiement rapide, répétable, automatisé et versionné.  
Voici les étapes principales pour reproduire l’environnement :  
### <ins>Prérequis</ins>
   
- Compte AWS actif.   
- AWS CLI configurée.   
- Terraform   
  
### <ins>Étapes de déploiement :</ins>     
1. Création du [VPC](./modules/vpc/main.tf) avec subnets publics et privés.
2. Mise en place des [VPC endpoints](./modules/vpc_endpoints/main.tf) SSM et S3.
3. Mettre en place l’[Application Load Balancer (ALB)](./modules/alb/main.tf).
4. Déployer un [Auto Scaling Group](./modules/asg/main.tf) d’instances EC2 dans les subnets privés.
<details>
  
<summary>See asg code</summary>

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
</details>

<details>
  
<summary>See launch template code</summary>

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
</details>

5. Configurer [CloudWatch Alarm](./modules/cloudwatch/main.tf) sur Target_4XXCount.
<details>
  
<summary>See alarm code</summary>

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
</details>

6. Lancer la commande *terraform init* pour initialiser les modules. Puis, *terraform plan* pour vérifier ce qui va être créé et enfin *terraform apply* pour déployer l'infrastructure.
   
7. Vérifier le fonctionnement :
- Accès applicatif via ALB.
- Connexion maintenance via SSM.
- Déclenchement de l’alarme en cas d’erreurs 4XX.

8. Si besoin, détruire l'infrastructure avec la commande "*terraform destroy*.
<br/>
<br/>

## 6. Usage & Maintenance
<a name="#6-usage--maintenance"></a>
- Accès aux instances : utiliser AWS Systems Manager → Session Manager (aucun besoin de clé SSH).
- Monitoring : suivre les métriques et alarmes dans CloudWatch Dashboard.
- Bonnes pratiques :  
&emsp;&emsp;- IAM avec le principe de least privilege.  
&emsp;&emsp;- Tagging des ressources pour une meilleure gestion.  
&emsp;&emsp;- Logs centralisés (CloudWatch Logs).     
<br/>
<br/>
<br/>

## 7. Alerts & Monitoring
<a name="#7-alerts--monitoring"></a>
- Alarme principale : Target_4XXCount déclenche une notification email via SNS si un seuil est dépassé.
- Extensions possibles :   
- Ajout d’alertes sur les 5XX errors.   
- Suivi de la latence des requêtes.   
- Création de dashboards personnalisés dans CloudWatch.   
<br/>
<br/>
<br/>

## 8. Improvements & Next Steps
<a name="#8-improvements--next-steps"></a>
- Ajouter un WAF (Web Application Firewall) pour renforcer la sécurité.
- Configurer l’ALB en HTTPS avec un certificat ACM.
- Étendre le monitoring (logs applicatifs, métriques supplémentaires).   
<br/>
<br/>
<br/>

## 9. Conclusion
<a name="#9-conclusion"></a>
- Résumé des points clés (scalabilité, sécurité, monitoring)
- Valeur du projet pour ton portfolio
<br/>
<br/>
<br/>

## 10. References
<a name="#10-references"></a>   
:link:[Application Load Balancer – AWS Docs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)  
:link:[Auto Scaling Groups – AWS Docs](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html)  
:link:[PrivateLinks – AWS Docs](https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html)  
:link:[AWS Systems Manager (SSM)](https://docs.aws.amazon.com/systems-manager/)  
:link:[Amazon CloudWatch Monitoring](https://docs.aws.amazon.com/cloudwatch/)  
