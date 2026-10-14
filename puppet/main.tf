terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for the Puppet lab"
  type        = string
  default     = "ap-south-1"
}

variable "ssh_cidr" {
  description = "CIDR range allowed to SSH to both instances"
  type        = string
  default     = "0.0.0.0/0"
}

locals {
  puppet_server_private_ip  = "10.20.1.10"
  puppet_client1_private_ip = "10.20.1.11"
}

data "aws_ami" "rocky_linux_9" {
  most_recent = true
  owners      = ["792107900819"]

  filter {
    name   = "name"
    values = ["Rocky-9-EC2-Base-9.*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_key_pair" "puppet_lab" {
  key_name   = "puppet-lab-key"
  public_key = file(pathexpand("~/.ssh/puppet-lab.pub"))
}

resource "aws_vpc" "puppet_lab" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "puppet-lab"
    Environment = "puppet-lab"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.puppet_lab.id
  cidr_block              = "10.20.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name        = "puppet-lab-public"
    Environment = "puppet-lab"
  }
}

resource "aws_internet_gateway" "puppet_lab" {
  vpc_id = aws_vpc.puppet_lab.id

  tags = {
    Name        = "puppet-lab-igw"
    Environment = "puppet-lab"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.puppet_lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.puppet_lab.id
  }

  tags = {
    Name        = "puppet-lab-public"
    Environment = "puppet-lab"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "puppet_server" {
  name        = "puppet-lab-server"
  description = "SSH and Puppet server access"
  vpc_id      = aws_vpc.puppet_lab.id

  tags = {
    Environment = "puppet-lab"
    role        = "puppet-server"
  }
}

resource "aws_security_group" "puppet_client" {
  name        = "puppet-lab-client1"
  description = "SSH access to Puppet client"
  vpc_id      = aws_vpc.puppet_lab.id

  tags = {
    Environment = "puppet-lab"
    role        = "puppet-client1"
  }
}

resource "aws_vpc_security_group_egress_rule" "puppet_server_all_ipv4" {
  security_group_id = aws_security_group.puppet_server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "puppet_client_all_ipv4" {
  security_group_id = aws_security_group.puppet_client.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "server_ssh" {
  security_group_id = aws_security_group.puppet_server.id
  description       = "SSH access"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_cidr
}

resource "aws_vpc_security_group_ingress_rule" "puppet_from_client" {
  security_group_id            = aws_security_group.puppet_server.id
  description                  = "Puppet agent traffic from the client"
  ip_protocol                  = "tcp"
  from_port                    = 8140
  to_port                      = 8140
  referenced_security_group_id = aws_security_group.puppet_client.id
}

resource "aws_vpc_security_group_ingress_rule" "client_ssh" {
  security_group_id = aws_security_group.puppet_client.id
  description       = "SSH access"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_cidr
}

resource "aws_instance" "puppet_server" {
  ami                         = data.aws_ami.rocky_linux_9.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public.id
  private_ip                  = local.puppet_server_private_ip
  vpc_security_group_ids      = [aws_security_group.puppet_server.id]
  key_name                    = aws_key_pair.puppet_lab.key_name
  associate_public_ip_address = true
  user_data_replace_on_change = true
  user_data                   = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    hostnamectl set-hostname puppet-server
    timedatectl set-timezone Asia/Kolkata
    cat >> /etc/hosts <<'HOSTS'
    ${local.puppet_server_private_ip} puppet puppet-server puppet-server.${var.aws_region}.compute.internal
    HOSTS
    dnf -y update
    dnf -y install https://yum.puppet.com/puppet8-release-el-9.noarch.rpm
    dnf -y install puppetserver vim traceroute
    cp -fvrad /etc/sysconfig/puppetserver /etc/sysconfig/puppetserver-`date +%F`
    if grep -q '^JAVA_ARGS=' /etc/sysconfig/puppetserver; then
      sed -i 's|^JAVA_ARGS=.*|JAVA_ARGS="-Xms512m -Xmx512m"|' /etc/sysconfig/puppetserver
    else
      echo 'JAVA_ARGS="-Xms512m -Xmx512m"' >> /etc/sysconfig/puppetserver
    fi
    systemctl enable puppetserver --now
  EOT

  tags = {
    Name        = "puppet-server"
    Environment = "puppet-lab"
    role        = "puppet-server"
  }
}

resource "aws_instance" "puppet_client" {
  ami                         = data.aws_ami.rocky_linux_9.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  private_ip                  = local.puppet_client1_private_ip
  vpc_security_group_ids      = [aws_security_group.puppet_client.id]
  key_name                    = aws_key_pair.puppet_lab.key_name
  associate_public_ip_address = true
  user_data_replace_on_change = true
  user_data                   = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    hostnamectl set-hostname puppet-client1
    timedatectl set-timezone Asia/Kolkata
    cat >> /etc/hosts <<'HOSTS'
    ${local.puppet_server_private_ip} puppet puppet-server puppet-server.${var.aws_region}.compute.internal
    ${local.puppet_client1_private_ip} puppet-client1
    HOSTS
    dnf -y update
    dnf -y install https://yum.puppet.com/puppet8-release-el-9.noarch.rpm
    dnf -y install puppet-agent vim traceroute
  EOT

  tags = {
    Name        = "puppet-client1"
    Environment = "puppet-lab"
    role        = "puppet-client1"
  }
}

resource "aws_eip" "puppet_server" {
  domain   = "vpc"
  instance = aws_instance.puppet_server.id

  tags = {
    Name        = "puppet-server-eip"
    Environment = "puppet-lab"
    role        = "puppet-server"
  }
}

resource "aws_eip" "puppet_client" {
  domain   = "vpc"
  instance = aws_instance.puppet_client.id

  tags = {
    Name        = "puppet-client1-eip"
    Environment = "puppet-lab"
    role        = "puppet-client1"
  }
}

output "puppet_server_private_ip" {
  value = aws_instance.puppet_server.private_ip
}

output "puppet_client1_private_ip" {
  value = aws_instance.puppet_client.private_ip
}

output "puppet_server_public_ip" {
  value = aws_eip.puppet_server.public_ip
}

output "puppet_client1_public_ip" {
  value = aws_eip.puppet_client.public_ip
}
