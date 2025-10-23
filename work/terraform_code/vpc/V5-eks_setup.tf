########################################
# Provider
########################################
provider "aws" {
  region = "us-east-1"
}

########################################
# Data source – dynamically fetch AZs
########################################
data "aws_availability_zones" "available" {}

########################################
# VPC
########################################
resource "aws_vpc" "dpp-vpc" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "dpp-vpc"
  }
}

########################################
# Subnets
########################################
resource "aws_subnet" "dpp-public-subnet-01" {
  vpc_id                  = aws_vpc.dpp-vpc.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "dpp-public-subnet-01"
  }
}

resource "aws_subnet" "dpp-public-subnet-02" {
  vpc_id                  = aws_vpc.dpp-vpc.id
  cidr_block              = "10.1.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "dpp-public-subnet-02"
  }
}

########################################
# Internet Gateway
########################################
resource "aws_internet_gateway" "dpp-igw" {
  vpc_id = aws_vpc.dpp-vpc.id

  tags = {
    Name = "dpp-igw"
  }
}

########################################
# Route Table & Associations
########################################
resource "aws_route_table" "dpp-public-rt" {
  vpc_id = aws_vpc.dpp-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dpp-igw.id
  }

  tags = {
    Name = "dpp-public-rt"
  }
}

resource "aws_route_table_association" "dpp-rta-public-subnet-01" {
  subnet_id      = aws_subnet.dpp-public-subnet-01.id
  route_table_id = aws_route_table.dpp-public-rt.id
}

resource "aws_route_table_association" "dpp-rta-public-subnet-02" {
  subnet_id      = aws_subnet.dpp-public-subnet-02.id
  route_table_id = aws_route_table.dpp-public-rt.id
}

########################################
# Security Group
########################################
resource "aws_security_group" "demo-sg" {
  name        = "demo-sg"
  description = "Allow SSH and Jenkins"
  vpc_id      = aws_vpc.dpp-vpc.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "demo-sg"
  }
}

########################################
# EC2 Instances
########################################
locals {
  # Spread instances across both subnets
  subnet_map = {
    "jenkins-master" = aws_subnet.dpp-public-subnet-01.id
    "build-slave"    = aws_subnet.dpp-public-subnet-02.id
    "ansible"        = aws_subnet.dpp-public-subnet-01.id
  }
}

resource "aws_instance" "demo-server" {
  for_each = toset(["jenkins-master", "build-slave", "ansible"])

  ami                    = "ami-0360c520857e3138f"
  instance_type          = "t3.micro"
  key_name               = "dpp"
  vpc_security_group_ids = [aws_security_group.demo-sg.id]
  subnet_id              = local.subnet_map[each.value]

  tags = {
    Name = each.value
  }
}

########################################
# Modules (Optional: EKS + SGs)
########################################
module "sgs" {
  source = "../sg_eks"
  vpc_id = aws_vpc.dpp-vpc.id
}

module "eks" {
  source     = "../eks"
  vpc_id     = aws_vpc.dpp-vpc.id
  subnet_ids = [
    aws_subnet.dpp-public-subnet-01.id,
    aws_subnet.dpp-public-subnet-02.id
  ]
  sg_ids = module.sgs.security_group_public
}
