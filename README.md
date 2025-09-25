
 # SECURE PUBLIC AND PRIVATE INSTANCES WITH INTERNET ACCESS

 \
 \
 \


<img width="2028" height="1049" alt="WebApp_EmailAlarm_SSMConnect drawio(1)" src="https://github.com/user-attachments/assets/7dbff49e-2482-492d-9902-2619b60d88c5" />

<!--
PART 1 : un résumé de haut niveau de ce que la chose fait, ainsi que de ce qu'elle est censée faire
-->

### This simple infrastructure is made to protect an undefined number of instances on different levels (instance and subnet level) while ensuring a good outbound connectivity. Deployed with Terraform, it is flexible and easily reproductible in different environments.


##  SECURITY
On the instance level, security is ensured with its security group using the priciple of "least amount of privilege".\
Because private instances have sensitive datas, accessing them must be restricted to the minimum : a bastion host. That way it is easier to control.\
This why I chose to allow only one IP to SSH into the public instances, for maintenance, and only the bastion host's IP to access private instances.\
 \
Here we can see that SSH connection is allowed if it comes from the security group of the bastion only.
    
```terraform
   resource "aws_security_group" "sg_private" {
      name        = "allow_bastion"
      description = "Allow SSH connect from bastion"
      vpc_id      = aws_vpc.main.id
    
      ingress {
        from_port = 22
        to_port   = 22
        protocol  = "tcp"
        security_groups = [aws_security_group.bastion.id]
      }
```

<!-- Parler du NACL stateless -->
To add another layer of security, on the subnet level I added a custom NACL for each subnet with the same settings of the security groups.\
Below is a visualization of the inbound (green) and outbound (purple) traffic going through the NACLs, initiated connections are in plain lines and responses in dotted ones.

<img width="751" height="735" alt="NACL(1)" src="https://github.com/user-attachments/assets/554dc5dc-494a-4175-8c7c-f6e4a905243a" />

And the code associated : 

``` terraform

# === NACL === #
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.public.id]

  // HTTP Connection from Internet
  ingress {
    rule_no = 100
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_block = "0.0.0.0/0"
    action = "allow"
  }

  // HTTPS Connection from Internet
  ingress {
    rule_no = 110
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_block = "0.0.0.0/0"
    action = "allow"
  }

  // Response from Internet and private subnet
  ingress {
    rule_no = 200
    from_port = 1024
    to_port = 65535
    protocol = "tcp"
    cidr_block = "0.0.0.0/0"
    action = "allow"
  }

  // SSH from my IP
  ingress {
    rule_no = 300
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_block = "${var.my_ip}/32"
    action = "allow"
  }

  // HTTP Connection to Internet
  egress {
    rule_no = 100
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_block = "0.0.0.0/0"
    action = "allow"
  }

   // HTTPS Connection to Internet
  egress {
    rule_no = 110
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_block = "0.0.0.0/0"
    action = "allow"
  }

  // Response from Internet and IP
  egress {
    rule_no = 200
    from_port = 1024
    to_port = 65535
    protocol = "tcp"
    cidr_block = "0.0.0.0/0"
    action = "allow"
  }


  // SSH from bastion to private subnet
  egress {
    rule_no = 300
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_block = aws_subnet.private.cidr_block
    action = "allow"
  }

  tags = {
    Name = "public_nacl"
  }
}

resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private.id]

  // SSH from bastion to private subnet
  ingress {
    rule_no = 100
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_block = aws_subnet.public.cidr_block
    action = "allow"
  }

  // Response from Internet
  ingress {
    rule_no = 200
    from_port = 1024
    to_port = 65535
    protocol = "tcp"
    cidr_block = "0.0.0.0/0"
    action = "allow"
  }

  // SSH response to bastion
  egress {
    rule_no = 100
    from_port = 1024
    to_port = 65535
    protocol = "tcp"
    cidr_block = aws_subnet.public.cidr_block
    action = "allow"
  }

  //HTTP Connection to Internet
  egress {
    rule_no = 200
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_block = "0.0.0.0/0"
    action = "allow"
  }

  //HTTPS Connection to Internet
  egress {
    rule_no = 210
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_block = "0.0.0.0/0"
    action = "allow"
  }

  tags = {
    Name = "private_nacl"
  }
}

```

To watch if cyberattacks are occuring or do some troubleshooting, I installed VPC flow logs to send data into CloudWatch. That way, it is possible to see which IPs try to connect into our resources and do some analytics.\
 \
Below we can see the log group in cloudwatch in which the VPC flowlog is allowed to write :
```terraform
resource "aws_cloudwatch_log_group" "flowlogs" {
  name              = "/aws/vpc/${var.project_name}-flow-logs"
  retention_in_days = 30
}

resource "aws_flow_log" "vpc_flow_log" {
  traffic_type         = ALL
  vpc_id               = aws_vpc.main.id
  iam_role_arn         = aws_iam_role.flowlogs_role.arn
  log_destination      = aws_cloudwatch_log_group.flowlogs.arn
  log_destination_type = "cloud-watch-logs"

  tags = {
    Name = "${var.project_name}-vpc-flow-log"
  }
}
```
 \
 And the IAM role policy allowing the VPC flowlog to write into cloudwatch :
```terraform
resource "aws_iam_role_policy" "flowlogs_policy" {
  name = "${var.project_name}flowlogs_policy"
  role = aws_iam_role.flowlogs_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
```

 <!--
PART 2 :  décrire des choses comme le problème qu'elle résout, les défis rencontrés, les hypothèses faites.
-->

<!--
> PART 3 : passe en revue les principaux composants à un niveau élevé - "ici, j'ai utilisé des données relationnelles car exigence xyz, ici, j'ai utilisé un pare-feu avec les ports xyz ouverts à cause des exigences, j'ai utilisé xyz pour DNS, etc."
-->

> [!NOTE]
> If we see, in these CloudWatch logs, a specific IP trying to force entry in our infrastructure we can add a rule at the nacl level to block it.
// CA POURRAIT MEME ETRE AUTOMATISE


## CONNECTIVITY

Because private instances are not able to access internet alone neither through a bastion host, I used a NAT Gateway so they can access it through the public subnet.\
 \
This is the part of the code that is creating it and associating it to the right instance

```terraform
    resource "aws_route_table" "rt_ngw" {
      vpc_id = aws_vpc.main.id
    
      route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.ngw.id
      }
    }
    
    resource "aws_route_table_association" "private" {
      route_table_id = aws_route_table.rt_ngw.id
      subnet_id      = aws_subnet.private.id
    }
```

## MODULARITY AND COLLABORATION

<!--
>PART 4 : abordez les éléments de niveau inférieur - conceptions de bases de données, exigences de débit, tailles d'enregistrements, découverte de services, stratégies de basculement.
-->
<!--
PART 5 : configuration où je documente toutes les configurations sensibles ou spéciales qui sont pertinentes. 
-->

<!--
PART 6 : section sur les opérations - quelles sont les tâches opérationnelles courantes dont cette chose peut avoir besoin, ou les choses dont les personnes de garde peuvent avoir besoin (comment arrêter/démarrer. Où sont les journaux, comment accéder aux choses, comment évoluer, quelles sont les limites du système), toutes les mises en garde ou la laideur qui existent, où se trouve le code, comment déployer avec teraform, etc. 
-->

<!--
PART 7 : quelques résultats de tests pertinents - combien d'écritures vous pouvez faire, à quelle vitesse nous reconvergeons en cas de basculement, combien de choses par unité nous pouvons faire avec la conception.
-->

<!--
!!! COMMENTER LE TERRAFORM !!!
-->
