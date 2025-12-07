###############################################
# FULLY AUTOMATED, RERUNNABLE RDS SQL Server
# Password output is NOT sensitive (Option 3)
###############################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2" # London
}

###############################################
# RANDOM VALUES TO AVOID ALL NAMING COLLISIONS
###############################################

resource "random_pet" "suffix" {
  length = 2
}

resource "random_string" "username" {
  length  = 8
  upper   = false
  special = false
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@#!"
}

###############################################
# VPC WITH REQUIRED DNS SETTINGS
###############################################

resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-${random_pet.suffix.id}"
  }
}

###############################################
# PUBLIC SUBNETS IN 2 AZs
###############################################

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-a-${random_pet.suffix.id}"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-b-${random_pet.suffix.id}"
  }
}

###############################################
# INTERNET GATEWAY + ROUTING
###############################################

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${random_pet.suffix.id}"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "rt-${random_pet.suffix.id}"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.rt.id
}

###############################################
# SECURITY GROUP — ALLOW SQL SERVER
###############################################

resource "aws_security_group" "sql_sg" {
  name        = "sql-sg-${random_pet.suffix.id}"
  description = "Allow SQL Server access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # fully open for disposable environment
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-${random_pet.suffix.id}"
  }
}

###############################################
# RDS SUBNET GROUP - RANDOM NAME
###############################################

resource "aws_db_subnet_group" "sql_subnets" {
  name       = "rds-subnet-${random_pet.suffix.id}"
  subnet_ids = [
    aws_subnet.subnet_a.id,
    aws_subnet.subnet_b.id
  ]

  tags = {
    Name = "rds-subnet-${random_pet.suffix.id}"
  }
}

###############################################
# RDS SQL SERVER EXPRESS (FREE TIER)
###############################################

resource "aws_db_instance" "sqlserver" {
  identifier               = "sql-${random_pet.suffix.id}"
  engine                   = "sqlserver-ex"
  instance_class           = "db.t3.micro"
  allocated_storage        = 20

  username = random_string.username.result
  password = random_password.password.result

  db_subnet_group_name   = aws_db_subnet_group.sql_subnets.name
  vpc_security_group_ids = [aws_security_group.sql_sg.id]

  publicly_accessible = true
  skip_final_snapshot = true

  tags = {
    Name = "sql-${random_pet.suffix.id}"
  }
}

###############################################
# OUTPUTS (PASSWORD IS NOT SENSITIVE)
###############################################

output "rds_host" {
  value = aws_db_instance.sqlserver.address
}

output "rds_port" {
  value = aws_db_instance.sqlserver.port
}

output "username" {
  value = random_string.username.result
}

output "password" {
  value     = random_password.password.result
  sensitive = false   # <-- YOU CAN SEE THE PASSWORD IN OCTOPUS NOW
}

output "instance_identifier" {
  value = aws_db_instance.sqlserver.identifier
}
