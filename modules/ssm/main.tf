### === IAM ROLE FOR SSM ACCESS === ###
/* Creates a role that EC2 instances can assume to communicate
 with AWS Systems Manager (SSM).*/
resource "aws_iam_role" "ssm_role" {
  name = "${var.name}-${var.role_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = { Name = var.role_name }
}


### === ATTACH MANAGED SSM POLICY === ###
/* Grants the role permissions to use core SSM features :
      - Session Manager for remote instance management
      - Run Command for executing scripts
      - Inventory and patching features*/
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ssm_role.name                                      // To which role this policy must be attached
}


### === IAM INSTANCE PROFILE === ###
// Required to attach the IAM role to EC2 instances.
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${var.name}-${var.role_name}-instance-profile"
  role = aws_iam_role.ssm_role.name                                            // Which role is attached to this instance profile
}