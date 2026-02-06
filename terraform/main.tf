terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Configuration
resource "aws_vpc" "hadoop_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "hadoop-grafana-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "hadoop_igw" {
  vpc_id = aws_vpc.hadoop_vpc.id

  tags = {
    Name = "hadoop-grafana-igw"
  }
}

# Public Subnet
resource "aws_subnet" "hadoop_public_subnet" {
  vpc_id                  = aws_vpc.hadoop_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "hadoop-grafana-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "hadoop_public_rt" {
  vpc_id = aws_vpc.hadoop_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hadoop_igw.id
  }

  tags = {
    Name = "hadoop-grafana-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "hadoop_public_rta" {
  subnet_id      = aws_subnet.hadoop_public_subnet.id
  route_table_id = aws_route_table.hadoop_public_rt.id
}

# Security Group
resource "aws_security_group" "hadoop_sg" {
  name        = "hadoop-grafana-sg"
  description = "Security group for Hadoop and Grafana POC"
  vpc_id      = aws_vpc.hadoop_vpc.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # Hadoop NameNode UI
  ingress {
    description = "NameNode UI"
    from_port   = 9870
    to_port     = 9870
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # Hadoop ResourceManager UI
  ingress {
    description = "ResourceManager UI"
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # Prometheus
  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # Grafana
  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # JMX Exporters
  ingress {
    description = "JMX Exporters"
    from_port   = 9101
    to_port     = 9105
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Internal Hadoop communication
  ingress {
    description = "Hadoop Internal"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hadoop-grafana-sg"
  }
}

# Master Node (NameNode, ResourceManager, Prometheus, Grafana)
resource "aws_instance" "hadoop_master" {
  ami                    = var.ami_id
  instance_type          = "t3.large"
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.hadoop_public_subnet.id
  vpc_security_group_ids = [aws_security_group.hadoop_sg.id]
  
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "hadoop-master"
    Role = "master"
  }

  user_data = templatefile("${path.module}/user_data_master.sh", {
    worker1_private_ip = aws_instance.hadoop_worker[0].private_ip
    worker2_private_ip = aws_instance.hadoop_worker[1].private_ip
  })

  depends_on = [aws_instance.hadoop_worker]
}

# Worker Nodes (DataNodes, NodeManagers)
resource "aws_instance" "hadoop_worker" {
  count                  = 2
  ami                    = var.ami_id
  instance_type          = "t3.medium"
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.hadoop_public_subnet.id
  vpc_security_group_ids = [aws_security_group.hadoop_sg.id]
  
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "hadoop-worker-${count.index + 1}"
    Role = "worker"
  }

  user_data = file("${path.module}/user_data_worker.sh")
}

# Outputs
output "master_public_ip" {
  value       = aws_instance.hadoop_master.public_ip
  description = "Public IP of the Hadoop Master Node"
}

output "master_private_ip" {
  value       = aws_instance.hadoop_master.private_ip
  description = "Private IP of the Hadoop Master Node"
}

output "worker_public_ips" {
  value       = aws_instance.hadoop_worker[*].public_ip
  description = "Public IPs of Worker Nodes"
}

output "worker_private_ips" {
  value       = aws_instance.hadoop_worker[*].private_ip
  description = "Private IPs of Worker Nodes"
}

output "grafana_url" {
  value       = "http://${aws_instance.hadoop_master.public_ip}:3000"
  description = "Grafana Dashboard URL"
}

output "namenode_url" {
  value       = "http://${aws_instance.hadoop_master.public_ip}:9870"
  description = "Hadoop NameNode UI URL"
}

output "resourcemanager_url" {
  value       = "http://${aws_instance.hadoop_master.public_ip}:8088"
  description = "Hadoop ResourceManager UI URL"
}

output "prometheus_url" {
  value       = "http://${aws_instance.hadoop_master.public_ip}:9090"
  description = "Prometheus UI URL"
}
