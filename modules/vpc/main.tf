### === VIRTUAL PRIVATE CLOUD === ###
// Creates the network base with subnets and routing configuration.
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true                                                   // Needed when using VPC endpoints.
  enable_dns_support = true                                                     // Needed when using other AWS services.

  tags = { Name = "${var.name}-vpc" }
}


### === PUBLIC SUBNETS === ###
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  map_public_ip_on_launch = true                                                 // Makes the subnets public.
  availability_zone       = var.azs[count.index]                                 // Multiple AZs are required to use an ALB.

  tags = {
    Name = "${var.name}-public-${count.index}"
  }
}


### === PRIVATE SUBNETS === ###
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnets[count.index]
  map_public_ip_on_launch = false                                                // Makes the subnets private.
  availability_zone       = var.azs[count.index]                                 // Multiple AZs to grant high availability to our private instances.

  tags = { Name = "${var.name}-private-${count.index}" }
}


### === INTERNET GATEWAY === ###
// Allow ALB to reach internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-igw" }
}


### === PUBLIC ROUTE TABLE === ###
// Routes traffic to internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.name}-public-rt" }
}

// Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)                                           // Traffic in all public subnets in this VPC is routed to igw.
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


### === PRIVATE ROUTE TABLE === ###
// Traffic does not go to the internet but to VPC Endpoints instead
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-private-rt" }
}

// Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
