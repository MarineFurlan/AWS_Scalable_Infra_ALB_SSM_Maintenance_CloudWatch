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

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ssm_role.name
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${var.name}-${var.role_name}-instance-profile"
  role = aws_iam_role.ssm_role.name
}