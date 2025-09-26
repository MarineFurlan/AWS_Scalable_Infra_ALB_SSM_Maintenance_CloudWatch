
 # AWS Scalable Infra : ALB + SSM Maintenance + CloudWatch
 \
 \
 \
## 1. Introduction 
   
Ce projet présente une architecture scalable, sécurisée et monitorée sur AWS.      
Il s'agit de déployer une application web derrière un Application Load Balancer (ALB) dans un VPC privé, avec un Auto Scaling Group d’instances EC2.   
La maintenance et la connectivité sont assurées via AWS Systems Manager (SSM), sans accès SSH direct, et la supervision est centralisée avec CloudWatch (métriques et alertes).   
   
## 2. Architecture Overview
   
<img width="2028" height="1049" alt="WebApp_EmailAlarm_SSMConnect drawio(1)" src="https://github.com/user-attachments/assets/7dbff49e-2482-492d-9902-2619b60d88c5" />
      
<ins>Composants principaux :</ins>      
- ALB (Application Load Balancer) : routage du trafic HTTP/HTTPS   
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
5. Configurer CloudWatch Alarm sur Target_4XXCount.
6. Vérifier le fonctionnement :
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
