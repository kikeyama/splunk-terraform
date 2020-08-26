provider "aws" {
  profile = "default"
  region  = var.region
}

variable "instance_count" {
  description = "number of instances to launch"
}

variable "region" {
  description = "region to deploy instances"
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

resource "aws_vpc" "workshop-vpc" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "workshop-vpc"
  }
}

resource "aws_internet_gateway" "workshop-igw" {
  vpc_id = aws_vpc.workshop-vpc.id

  tags = {
    Name = "workshop-igw"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "workshop-subnet" {
#  for_each = [for az in data.aws_availability_zones.available.names: {
#    cidr_block = cidrsubnet(aws_vpc.workshop-vpc.cidr_block, 8, az.number)
#  }]

  vpc_id                  = aws_vpc.workshop-vpc.id
  cidr_block              = cidrsubnet(aws_vpc.workshop-vpc.cidr_block, 8, 0)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "workshop-subnet-0"
  }
}

resource "aws_route_table" "workshop-rtb" {
  vpc_id    = aws_vpc.workshop-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.workshop-igw.id
  }

  tags = {
    Name = "workshop-rtb"
  }
}

resource "aws_route_table_association" "workshop-rtb-a" {
  subnet_id      = aws_subnet.workshop-subnet.id
  route_table_id = aws_route_table.workshop-rtb.id
}

resource "aws_security_group" "workshop-sg" {
  vpc_id = aws_vpc.workshop-vpc.id
  name   = "workshop-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9997
    to_port     = 9997
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "workshop-sg"
  }
}

resource "aws_instance" "workshop-instances" {
  count                  = var.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = "key_for_GeneralWS"
  vpc_security_group_ids = [aws_security_group.workshop-sg.id]
  subnet_id              = aws_subnet.workshop-subnet.id
  user_data              = file("basic_setup.sh")

  root_block_device {
    volume_size = 16
  }

  tags = {
    Name = "workshop-instance-${count.index}"
  }

  volume_tags = {
    Name = "workshop-instance-${count.index}"
  }
}

output "ip" {
  value = aws_instance.workshop-instances.*.public_ip
}
