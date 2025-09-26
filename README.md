
# AWS Scalable Infra : ALB + SSM Maintenance + CloudWatch   
 
## 1. Introduction 
   
Ce projet présente une architecture scalable, sécurisée et monitorée sur AWS.      
Il s'agit de déployer une application web derrière un Application Load Balancer (ALB) dans un VPC privé, avec un Auto Scaling Group d’instances EC2.   
La maintenance et la connectivité sont assurées via AWS Systems Manager (SSM), sans accès SSH direct, et la supervision est centralisée avec CloudWatch (métriques et alertes).   
   
## 2. Architecture Overview
   
<img width="2028" height="1049" alt="WebApp_EmailAlarm_SSMConnect drawio(1)" src="https://github.com/user-attachments/assets/7dbff49e-2482-492d-9902-2619b60d88c5" />
      
<ins>Composants principaux :</ins>      
- ALB (Application Load Balancer) : routage du trafic HTTP/HTTPS   
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
   
- EC2 Auto Scaling Group : ajustement automatique du nombre d’instances selon la charge.   
- Private Subnets : instances isolées du trafic direct Internet.   
- VPC Endpoints : connectivité privée pour accéder à S3 (bootstrap) et SSM (maintenance).   
- CloudWatch Monitoring : suivi des métriques et configuration d’alarmes (erreurs 4XX).


## 3. Features
- Scalabilité : auto scaling des instances EC2 en fonction des besoins.   
- Sécurité : aucune exposition SSH, maintenance uniquement via SSM Session Manager.   
- Monitoring : alarme CloudWatch pour erreurs 4XX.   
- Optimisation : instances privées avec accès S3 via un vpc endpoint pour charger les fichiers de configuration au boot.


## 4. Deployment Steps
   
<ins>Prérequis</ins> 
   
Compte AWS actif.   
AWS CLI configurée.   
Terraform   
  
<ins>Étapes de déploiement :</ins>   
1. Création du VPC avec subnets publics et privés.
2. Mise en place des VPC endpoints SSM et S3.
3. Mettre en place l’Application Load Balancer (ALB).
4. Déployer un Auto Scaling Group d’instances EC2 dans les subnets privés.
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
   
6. Configurer CloudWatch Alarm sur Target_4XXCount.
7. Vérifier le fonctionnement :
- Accès applicatif via ALB.
- Connexion maintenance via SSM.
- Déclenchement de l’alarme en cas d’erreurs 4XX.

## 5. Usage & Maintenance
- Accès aux instances : utiliser AWS Systems Manager → Session Manager (aucun besoin de clé SSH).
- Monitoring : suivre les métriques et alarmes dans CloudWatch Dashboard.
- Bonnes pratiques :
- IAM avec le principe de least privilege.
- Tagging des ressources pour une meilleure gestion.
- Logs centralisés (CloudWatch Logs).   


## 6. Alerts & Monitoring
- Alarme principale : Target_4XXCount déclenche une notification email via SNS si un seuil est dépassé.
- Extensions possibles :   
- Ajout d’alertes sur les 5XX errors.   
- Suivi de la latence des requêtes.   
- Création de dashboards personnalisés dans CloudWatch.   


## 7. Improvements & Next Steps
- Ajouter un WAF (Web Application Firewall) pour renforcer la sécurité.
- Configurer l’ALB en HTTPS avec un certificat ACM.
- Étendre le monitoring (logs applicatifs, métriques supplémentaires).   

> [!NOTE]
> 8. Conclusion
> - Résumé des points clés (scalabilité, sécurité, monitoring)
> - Valeur du projet pour ton portfolio


> [!NOTE]
> 9. References
> > Application Load Balancer – AWS Docs
> > Auto Scaling Groups – AWS Docs
> > AWS Systems Manager (SSM)
> > Amazon CloudWatch Monitoring
