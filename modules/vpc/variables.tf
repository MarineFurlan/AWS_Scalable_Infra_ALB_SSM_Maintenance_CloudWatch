variable "azs" { type = list(string) }
variable "name" { type = string }
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "vpc_cidr" { type = string }
