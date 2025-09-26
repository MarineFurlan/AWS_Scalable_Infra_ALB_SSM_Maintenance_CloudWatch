
 # AWS Scalable Infra : ALB + SSM Maintenance + CloudWatch

 \
 \
 \

 > [!NOTE]
> 1. Introduction
> - Contexte du projet (objectif, problématique adressée)
> > Ce projet présente une architecture scalable, sécurisée et monitorée sur AWS.      
> - Description générale de l’architecture (scalable, sécurisée, monitorée)
> > Il s'agit de déployer une application web derrière un Application Load Balancer (ALB) dans un VPC privé, avec un Auto Scaling Group d’instances EC2.   
> > La maintenance et la connectivité sont assurées via AWS Systems Manager (SSM), sans accès SSH direct, et la supervision est centralisée avec CloudWatch (métriques et alertes).   

 > [!NOTE]
> 2. Architecture Overview 
> - Schéma d’architecture (diagramme AWS)
> <img width="2028" height="1049" alt="WebApp_EmailAlarm_SSMConnect drawio(1)" src="https://github.com/user-attachments/assets/7dbff49e-2482-492d-9902-2619b60d88c5" />
>    
> - Composants principaux :
> > - ALB (Application Load Balancer) : routage du trafic HTTP/HTTPS   
> > - EC2 Auto Scaling Group : ajustement automatique du nombre d’instances selon la charge.   
> > - Private Subnets : instances isolées du trafic direct Internet.   
> > - VPC Endpoints : connectivité privée pour accéder à S3 (bootstrap) et SSM (maintenance).   
> > - CloudWatch Monitoring : suivi des métriques et configuration d’alarmes (erreurs 4XX).

 > [!NOTE]
> 3. Features 
> > - Scalabilité : auto scaling des instances EC2 en fonction des besoins.   
> > - Sécurité : aucune exposition SSH, maintenance uniquement via SSM Session Manager.   
> > - Monitoring : alarme CloudWatch pour erreurs 4XX.   
> > - Optimisation : instances privées avec accès S3 via un vpc endpoint pour charger les fichiers de configuration au boot.

 > [!NOTE]
> 4. Deployment Steps 
> Prérequis (AWS CLI, Terraform/CDK/CloudFormation si utilisé)
> Étapes de déploiement :
> > 1. Création du VPC et subnets
> > 2. Mise en place des VPC endpoints (SSM, S3, etc.)
> > 3. Déploiement de l’ALB et de l’ASG (EC2)
> > 4. Configuration du CloudWatch alarm
> > 5. Tests de connectivité et monitoring

 > [!NOTE]
> 5. Usage & Maintenance 
> - Comment accéder aux instances via SSM Session Manager
> - Comment surveiller l’infra via CloudWatch Dashboard
> - Bonnes pratiques (tags, IAM least privilege, etc.)

 > [!NOTE]
> 6. Alerts & Monitoring
> - Règles de déclenchement de l’alarme Target_4XXCount
> - Exemple d’alerte mail reçu
> - Possibilité d’extension (5XX errors, latency, etc.)

> [!NOTE]
> 7. Improvements & Next Steps
> - Intégration CI/CD (CodePipeline, CodeDeploy)
> - Ajout de WAF (Web Application Firewall)
> - Mise en place d’ALB HTTPS + ACM Certificates
> - Logging centralisé (CloudWatch Logs, S3, etc.)

> [!NOTE]
> 8. Conclusion
> - Résumé des points clés (scalabilité, sécurité, monitoring)
> - Valeur du projet pour ton portfolio


> [!NOTE]
> 9. References
> - Liens vers la doc AWS (ALB, ASG, SSM, CloudWatch)
> - Articles/tutos utiles
