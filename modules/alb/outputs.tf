output "alb_arn_suffix" { value = aws_lb.this.arn_suffix }

output "alb_dns_name" { value = aws_lb.this.dns_name }

output "alb_name" { value = aws_lb.this.name }

output "alb_sg_id" { value = aws_security_group.alb.id }

output "tg_arn" { value = aws_lb_target_group.alb.arn }

output "tg_arn_suffix" { value = aws_lb_target_group.alb.arn_suffix }