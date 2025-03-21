# VPC

resource "aws_vpc" "my_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
}

# Internet gateway

resource "aws_internet_gateway" "heapoverflow_db_gateway" {
  vpc_id = aws_vpc.my_vpc.id
}

# Public subnets

resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, 1)
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, 2)
  availability_zone = "us-east-1b"
}

# Routing

resource "aws_route_table" "routedb" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.heapoverflow_db_gateway.id
  }
}

# Public Subnets group

resource "aws_db_subnet_group" "heapoverflow_db_subnet_group" {
  name       = "aws_subnet_group_heapoverflow"
  subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
}

resource "aws_route_table_association" "subnet_a_association" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.routedb.id
}

resource "aws_route_table_association" "subnet_b_association" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.routedb.id
}

# Security Group

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.my_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_tcp" {
  security_group_id = aws_security_group.allow_tls.id
  from_port         = var.db_port
  to_port           = var.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "allow_tcp" {
  security_group_id = aws_security_group.allow_tls.id
  from_port         = var.db_port
  to_port           = var.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# RDS instance

resource "aws_db_instance" "heapoverflow_instance" {
  identifier          = "heapoverflow-db"
  storage_type        = "gp2"
  engine              = "Postgres"
  engine_version      = "17.4"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  publicly_accessible = true

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:05:00-sun:06:00"
  skip_final_snapshot     = true

  port                   = var.db_port
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.heapoverflow_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
}


# EC2

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow app traffic"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "springboot_app" {
  ami                    = "ami-07fa5275316057f54"  # Update with the correct AMI ID
  instance_type          = "t3.micro"
  security_groups        = [aws_security_group.ec2_sg.name]
  user_data = <<-EOF
              #!/bin/bash
              # Update packages and install Docker
              sudo yum update -y
              sudo amazon-linux-extras install docker
              sudo service docker start
              sudo usermod -a -G docker ec2-user

              # Enable Docker service to start on boot
              sudo systemctl enable docker

              # Install Git (if needed for the repo)
              sudo yum install -y git

              # Pull Docker image from Docker Hub
              docker pull your-dockerhub-username/demo-app:latest

              # Stop and remove any existing container (if it exists)
              docker stop springboot-app || true
              docker rm springboot-app || true

              # Run the Docker container
              docker run -d -p 8080:8080 --name springboot-app your-dockerhub-username/demo-app:latest
              EOF
}
