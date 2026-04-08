output "asg_name" {
  value = aws_autoscaling_group.this.name
}

output "ec2_sg_id" {
  value = aws_security_group.webApp.id
}

/*output "ec2_id" {
  value =
}*/