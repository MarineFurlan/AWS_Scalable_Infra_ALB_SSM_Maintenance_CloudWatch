
# AWS Scalable Infrastructure : ALB + SSM Maintenance + CloudWatch
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
- [Pricing](#6-pricing)
- [Improvements & Next Steps](#7-improvements--next-steps)
- [References](#8-references)
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
&emsp;&emsp;L'utilisation d' IaC (Infrastructure as Code) permet de versionner et reproduire facilement l’environnement, créer des modules réutilisables, déployer de manière automatisée en respectant les bonnes pratiques cloud et détruire l'infrastructure en une seule commande lorsqu'elle n'est plus nécessaire afin de respecter un budget.    

### <ins>2 subnets privés pour l’ASG</ins>
&emsp;&emsp;Ce choix permet de garantir la haute disponibilité et la résilience de l’application en cas de panne d’une AZ (Availability Zone). Cela s’aligne sur les bonnes pratiques AWS pour les architectures critiques.

### <ins>VPC Endpoint S3 plutôt qu’une NAT Gateway (coût et besoin limité d’accès Internet)</ins> 
&emsp;&emsp;Les instances EC2 sont déployées dans des subnets privés pour gagner en sécurité et n’ont pas besoin d’un accès Internet permanent.    
Plutôt que de créer une NAT Gateway qui génère des coûts supplémentaires, un VPC Endpoint S3 a été utilisé pour permettre le bootstrap des instances en ayant accès aux fichiers nécessaires stockés dans S3 de manière sécurisée et privée.  
Cette solution est économique car on utilise ici un endpoint de type "Gateway" qui n'engendre aucun frais.
Aussi, le traffic entre les deux services est sécurisé car il est d'office crypté via HTTPS.  
  
### <ins>Session Manager pour ajouter de la securité en fermant le port SSH</ins>
&emsp;&emsp;Pour limiter l’exposition des instances, le port SSH 22 reste fermé.  
Leur accès est géré via AWS Systems Manager Session Manager, ce qui permet d’effectuer la maintenance et le debug directement depuis la console ou l’interface CLI, sans ouvrir de ports réseau.  
Ce choix renforce donc la sécurité et simplifie la gestion des accès car il suffit de quelques clics pour accéder aux instances tout en ayant un contrôle aisé sur les comptes ayant la permission de se connecter avec.
  
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

<br/>

- **_Scalabilité_** : auto scaling des instances EC2 en fonction des besoins.
  
<br/>

- **_Haute disponibilité_** : Les instances de l’ASG sont déployées sur deux subnets privés dans des AZs différentes, assurant la résilience et la continuité du service.
  
<br/> 

- **_Sécurité_** : instances dans un réseau privé, aucune exposition SSH, maintenance uniquement via SSM Session Manager accessible via VPC endpoint.
  
<br/>

- **_Monitoring_** : alarme CloudWatch pour erreurs 4XX.

<br/>

- **_Reproductibilité et automatisation_** : déploiement automatisé et reproductible via Terraform.

<br/>  

- **_Optimisation_** : instances privées avec accès S3 via un vpc endpoint pour charger les fichiers de configuration au boot et réduire les coûts.

<br/>
<br/>
<br/>

## 5. Deployment Steps
<a name="#5-deployment-steps"></a>
&emsp;&emsp;L’infrastructure est déployée avec Terraform, permettant un déploiement rapide, répétable, automatisé et versionné.  
Voici les étapes principales pour reproduire l’environnement :  
### <ins>Prérequis :</ins>
   
- Compte AWS actif.   
- AWS CLI configurée.   
- Terraform   
  
### <ins>Étapes de déploiement :</ins>   

1. Ecriture du [VPC](./modules/vpc/main.tf) avec subnets publics et privés.
2. Ecriture des [VPC endpoints](./modules/vpc_endpoints/main.tf) SSM et S3.
3. Ecriture de l’[Application Load Balancer (ALB)](./modules/alb/main.tf).
4. Ecriture de l'[Auto Scaling Group](./modules/asg/main.tf) d’instances EC2 dans les subnets privés.
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

5. Ecriture de la [CloudWatch Alarm](./modules/cloudwatch/main.tf) sur Target_4XXCount.
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

6. Lancer la commande *terraform init* pour initialiser les modules.

7. Lancer la commande *terraform plan* pour vérifier ce qui va être créé. Votre adresse mail sera demandée dans la console pour y permettre l'envoi d'alarmes sécurité.

8. Lancer la commande *terraform apply* et confirmer son adresse mail dans la console.
L'infrastructure se déploie.

9. Accepter l'abonnement aux alarmes sécurité dans sa boîte mail.
    
![Email_notif](https://github.com/user-attachments/assets/df101df1-d6b3-4f3d-9888-5a7e0b9f3934)
   
### <ins>Tests</ins>

&emsp;&emsp;Après vérification dans la console AWS de la concordance des ressources créées en rapport à l'infrastructure souhaitée nous pouvons faire les tests suivants :

### _Accès applicatif via ALB_

- Copier l'adresse du ALB dans la sortie outputs de la console et y accéder sur navigateur.

![dns_output](https://github.com/user-attachments/assets/905eece7-aba0-4811-a524-35eb39e3ff18)
  
- Si la connexion est établie, la page affichera "Hello from {current-instance}" et sur plusieurs refresh de la page, le message basculera donc de l'instance 1 à 2.

<img width="776" height="82" alt="First_instance_in_server" src="https://github.com/user-attachments/assets/b6ce9de0-f6ba-44b8-aec8-e854bf093089" />
<img width="776" height="82" alt="Second_instance_in_server" src="https://github.com/user-attachments/assets/4bc10bc6-3aed-4ce4-b3cb-2cf701de04a3" />

- Dans les screenshots ci-dessous, on peut observer quelle instance possède quelle IP pour mieux les identifier :
<img width="776" height="82" alt="First_instance_ip" src="https://github.com/user-attachments/assets/5316ee90-05e6-409e-b3bf-d8b3353c7116" />
<img width="776" height="82" alt="Second_instance_ip" src="https://github.com/user-attachments/assets/0438c297-6f23-4363-be60-181b15186cf0" />

- Dans la console AWS, le target group contenant les instances les montrera saines et présentes dans des AZs différentes :
<img width="832" height="791" alt="target_group" src="https://github.com/user-attachments/assets/4418ea7a-f2bb-4194-a283-3faef77cdd63" />


### _Connexion maintenance via SSM_

- Se connecter à l'instance via SSM Connect
<img width="1776" height="498" alt="ssm_connect" src="https://github.com/user-attachments/assets/9100b977-c117-46f3-a782-3a042fd2b21f" />

### _Resiliency in case of failure_

- Stopper une instance afin de simuler un problème de zone.  
Immédiatement, dans la section Target Group de la console AWS on peut observer la mise à jour de l'instance en "unhealthy", tandis que les refresh de la page du serveur ne pointe plus que vers l'instance restante.
<img width="776" height="82" alt="Stopped_instance" src="https://github.com/user-attachments/assets/6ddd16cb-dac6-415f-9133-3e40adca58ed" />


Après quelques temps, l'instance est drainée pour finalement disparaître et une nouvelle est créée pour la remplacer.
<img width="776" height="82" alt="Draining_instance" src="https://github.com/user-attachments/assets/4d3f13a2-279f-4571-84b7-c09ac1662cf3" />
<img width="776" height="82" alt="New_instance_booted" src="https://github.com/user-attachments/assets/9bf8858f-2737-42ae-8ac5-684167405cf2" />


Dorénavant, le refresh de la page affichera le texte associée à la nouvelle instance.
<img width="776" height="82" alt="new_instance_ip" src="https://github.com/user-attachments/assets/c9bba3d2-5dd7-48fc-9e42-2597cae48f04" />
<img width="776" height="82" alt="Third_instance_in_server" src="https://github.com/user-attachments/assets/b5d1790e-8665-441a-b0ef-428eb9b632af" />



### _Déclenchement de l’alarme en cas d’erreurs 4XX_

- Dans Amazon SNS > Rubriques > vpc_alerts_webApp : Verifier l'abonnement email afin de recevoir les alertes.

<img width="776" height="82" alt="Email_confirmed" src="https://github.com/user-attachments/assets/e4dafef2-5bf2-423c-a8e9-51cef8ceb3cf" />

- Simulate 4xx errors to trigger alarm with, for instance, this code in PowerShell :

```PowerShell
1..12 | ForEach-Object { try { Invoke-WebRequest "http://{alb_dns}/chemin-invalide$($_)?r=$(Get-Random)" -Method GET -ErrorAction Stop -TimeoutSec 5 | Out-Null; "200" } catch { if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "ERR" } } }
```

After 4 to 5 minutes, the email alert is now received

![email_alarm](https://github.com/user-attachments/assets/95abb978-4a51-48a7-aa14-5ed9e17a5ad8)




11. Si besoin, détruire l'infrastructure avec la commande "*terraform destroy*.
<br/>
<br/>

## 6. Pricing
<a name="#6-pricing"></a>
&emsp;&emsp;L’infrastructure a été pensée avec une approche coût/efficacité, afin de concilier bonnes pratiques AWS et optimisation budgétaire.  
L’estimation ci-dessous est basée sur la [AWS Pricing Calculator](https://calculator.aws) et les pages officielles de tarification des services.  

| Service                      | Choix effectué                   | Estimation mensuelle*  | Justification |
|------------------------------|----------------------------------|------------------------|---------------|
| **EC2 (Auto Scaling Group)** | 2 instances t2.micro en EC2 Instance Savings Plan (1an)   | ~13,43 USD             | Famille d'instance stable. 1 seule région. ~2.05 USD d'économies par rapport à un Compute Savings Plan.
| **Application Load Balancer**| 1 ALB actif                      | 19.32 USD             | Requis pour gérer le routage HTTP vers plusieurs instances. |
| **VPC Endpoint (S3)**        | 1 Gateway Endpoint               | 0 USD                 | Gratuit à l’usage contrairement à une NAT Gateway |
| **VPC Endpoint (SSM)**       | 3 Interface Endpoint (ssm, ec2messages, ssmmessages) x 2 AZs           | 48.18 USD                 | Plus de securité et d'économies car 24,82 USD/mois moins cher qu'une NAT Gateway.             
| **CloudWatch**               | 1 alarme + métriques de base     | 0 USD                 | Gratuit dans la limite du Free Tier étant de 10 métriques et 10 alarmes/mois + 5Go logs ingérés/mois. La configuration actuelle s'inscrit donc dans le FreeTier même en ajoutant des logs pour stocker les informations de chaque session de maintenance étant généralement inférieures à 50Mo/mois|
| **SSM Session Manager**      | Inclus dans Free Tier            | 0 USD                 | Pas de coût additionnel pour l’accès basique via Session Manager sans logging vers CloudWatch. |
| **TOTAL**                    |                                  | **67,8 USD**         

\* Les montants sont donnés à titre indicatif pour la région "eu-west-3" et n'inclus que les coûts fixes des services sans les coûts liés au traffic.

<br/> 

<br/> 

<br/> 

### <ins>Décisions budgétaires clés</ins>
<br/>

| Service                      | Choix effectué                   | Estimation mensuelle*  |
|------------------------------|----------------------------------|------------------------|
| _NAT Gateway_                | _1 NAT x 2 AZs_                  | _73 USD_              |

<br/>

- **VPC endpoints vs NAT Gateway** :  
Coûts fixes réduits de 24,82 USD/mois

<br/> 

- **EC2 Instance Savings Plans vs Compute Savings Plan** :  
&emsp;&emsp;Le scaling de l'infrastructure est horizontal, le type des instances n'a donc pas vocation a être modifié et le VPC est dans une région unique. Le "EC2 Instance Savings Plan" propose un discount lorsque les instances utilisées sont de la même famille et situées dans la même région, il est donc plus adpaté à l'infrastructure créée.  
Aussi, pour un engagement d'1 an, son coût est de 6,72 USD/mois/instance contre 7,74 USD/mois/instance pour le "Compute Savings Plans".  
L'économie est donc de 1,02 USD/mois/instance soit ~2,05 USD/mois pour cette infrastructure.  
<br/> 
<br/>
<br/>

## 7. Improvements & Next Steps
<a name="#7-improvements--next-steps"></a>
Plusieurs options sont envisageables pour faire évoluer l'infrastructure, dont :  
- **Intégrer un WAF (Web Application Firewall)** pour renforcer la protection contre les attaques et élargir le champ de surveillance.

<br/>

- Configurer l’ALB en **HTTPS avec un certificat ACM** afin de chiffrer le trafic et encore augmenter la sécurité.  

<br/>

- **Étendre le monitoring** (logs applicatifs, métriques supplémentaires, création de dashboard personnalisés) pour mieux anticiper les problèmes et mieux suivre l'utilisation de l'application.  
<br/>
<br/>
<br/>

## 8. References
<a name="#8-references"></a>   
:link:[Application Load Balancer – AWS Docs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)  
:link:[Auto Scaling Groups – AWS Docs](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html)  
:link:[PrivateLinks – AWS Docs](https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html)  
:link:[AWS Systems Manager (SSM) – AWS Docs](https://docs.aws.amazon.com/systems-manager/)  
:link:[Amazon CloudWatch Monitoring – AWS Docs](https://docs.aws.amazon.com/cloudwatch/)  
:link:[AWS Pricing Calculator](https://calculator.aws/#/)  

