provider "aws" {
  profile = "default"
  region  = var.region
}

variable "region" {
  description = "region to deploy instances"
}

resource "aws_vpc" "cluster-vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "cluster-vpc"
  }
}

resource "aws_internet_gateway" "cluster-igw" {
  vpc_id = aws_vpc.cluster-vpc.id

  tags = {
    Name = "cluster-igw"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "cluster-subnet-public" {
  for_each          = toset(data.aws_availability_zones.available.names)
  availability_zone = each.value

  vpc_id                  = aws_vpc.cluster-vpc.id
  cidr_block              = cidrsubnet(aws_vpc.cluster-vpc.cidr_block, 8, index(data.aws_availability_zones.available.names, each.value) + 101)
  map_public_ip_on_launch = true

  tags = {
    Name = "cluster-subnet-public-${index(data.aws_availability_zones.available.names, each.value) + 1}"
  }
}

resource "aws_subnet" "cluster-subnet-private" {
  for_each          = toset(data.aws_availability_zones.available.names)
  availability_zone = each.value

  vpc_id                  = aws_vpc.cluster-vpc.id
  cidr_block              = cidrsubnet(aws_vpc.cluster-vpc.cidr_block, 8, index(data.aws_availability_zones.available.names, each.value) + 1)

  tags = {
    Name = "cluster-subnet-private-${index(data.aws_availability_zones.available.names, each.value) + 1}"
  }
}

resource "aws_route_table" "cluster-public-rtb" {
  vpc_id    = aws_vpc.cluster-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster-igw.id
  }

  tags = {
    Name = "cluster-public-rtb"
  }
}

resource "aws_route_table_association" "cluster-public-rtb-a" {
  for_each       = aws_subnet.cluster-subnet-public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.cluster-public-rtb.id
}

resource "aws_eip" "cluster-nat-eip" {
  vpc              = true
  public_ipv4_pool = "amazon"

  for_each         = aws_subnet.cluster-subnet-private

  tags = {
    Name = "cluster-nat-eip-${each.value.id}"
  }
}

resource "aws_nat_gateway" "cluster-nat" {
  for_each      = aws_subnet.cluster-subnet-public
  subnet_id     = each.value.id
  allocation_id = aws_eip.cluster-nat-eip[each.key].id

  tags = {
    Name = "cluster-nat-${each.value.id}"
  }
}

resource "aws_route_table" "cluster-private-rtb" {
  for_each = aws_subnet.cluster-subnet-private
  vpc_id   = aws_vpc.cluster-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.cluster-nat[each.key].id
  }

  tags = {
    Name = "cluster-private-rtb-${each.value.id}"
  }
}

resource "aws_route_table_association" "cluster-private-rtb-a" {
  for_each       = aws_subnet.cluster-subnet-private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.cluster-private-rtb[each.key].id
}

resource "aws_security_group" "cluster-base-sg" {
  vpc_id = aws_vpc.cluster-vpc.id
  name   = "cluster-base-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cluster-base-sg"
  }
}

data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
