provider "aws" {
  region     = "us-west-2"
  access_key = ""
  secret_key = ""
}
resource "aws_vpc" "techops_vpc" {
  cidr_block = "10.10.10.0/24"
  tags = {
    name = "techops_vpc"
  }
}
resource "aws_subnet" "subnet-A" {
  cidr_block        = "10.10.10.0/26"
  vpc_id            = aws_vpc.techops_vpc.id
  availability_zone = "us-west-2a"
  tags = {
    name = "subnet_A"
  }
}
resource "aws_subnet" "subnet-B" {
  cidr_block        = "10.10.10.64/26"
  vpc_id            = aws_vpc.techops_vpc.id
  availability_zone = "us-west-2b"
  tags = {
    name = "subnet_B"
  }
}
resource "aws_subnet" "subnet-C" {
  cidr_block        = "10.10.10.128/25"
  vpc_id            = aws_vpc.techops_vpc.id
  availability_zone = "us-west-2c"
  tags = {
    name = "subnet_C"
  }
}
resource "aws_internet_gateway" "techops_igw" {
  vpc_id = aws_vpc.techops_vpc.id
  tags = {
    name = "techops_igw"
  }
}
resource "aws_nat_gateway" "techops_ngw" {
  allocation_id = aws_eip.elastic_ip.id
  subnet_id     = aws_subnet.subnet-A.id
  tags = {
    name = "techops_NatGW"
  }
}
resource "aws_eip" "elastic_ip" {
  vpc = true
}
resource "aws_route_table" "public-RT" {
  vpc_id = aws_vpc.techops_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.techops_igw.id

  }
  tags = {
    name = "public-RT"
  }
}
resource "aws_route_table_association" "routeA_association" {
  subnet_id      = aws_subnet.subnet-A.id
  route_table_id = aws_route_table.public-RT.id
}
resource "aws_route_table_association" "routeB_association" {
  subnet_id      = aws_subnet.subnet-B.id
  route_table_id = aws_route_table.public-RT.id
}
resource "aws_route_table_association" "routeC_association" {
  subnet_id      = aws_subnet.subnet-C.id
  route_table_id = aws_route_table.private-RT.id
}
resource "aws_route_table" "private-RT" {
  vpc_id = aws_vpc.techops_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.techops_ngw.id
  }
  tags = {
    name = "private-RT"
  }
}
resource "aws_security_group" "techops_SG-ssh" {
  name   = "allow_ssh"
  vpc_id = aws_vpc.techops_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.10.0/24"]
    description = "SSH from the vpc"
  }
  tags = {
    name = "ssh traffic"
  }
}
resource "aws_security_group" "techops_SG-https" {
  vpc_id = aws_vpc.techops_vpc.id
  name   = "allow_https"
  ingress {
    description = "HTTP/S from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "https traffic from the internet"
  }
}
resource "aws_security_group" "techops_SG-https-quake3-arena" {
  vpc_id = aws_vpc.techops_vpc.id
  name   = "Allow https connections to Q3-arena"
  ingress {
    from_port   = 8080
    to_port     = 27950
    protocol    = "tcp"
    cidr_blocks = ["10.10.10.0/26", "10.10.10.64/26"]
  }
  tags = {
    name = "https connections to Q3-arena"
  }
}
resource "aws_security_group" "techops_SG-ssh-quake3-arena" {
  vpc_id = aws_vpc.techops_vpc.id
  name   = "Allow ssh connections to Q3-arena"
  ingress {
    from_port   = 22
    to_port     = 27952
    protocol    = "tcp"
    cidr_blocks = ["10.10.10.0/24"]
  }
  tags = {
    name = "ssh connections to Q3-arena"
  }
}
resource "aws_elb" "techops_elb" {
  availability_zones = ["us-west-2a", "us-west-2b"]
  subnets            = [aws_subnet.subnet-A.id, aws_subnet.subnet-B.id]
  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  security_groups = [aws_security_group.techops_SG-ssh.id, aws_security_group.techops_SG-https.id]
  health_check {
    healthy_threshold   = 5
    unhealthy_threshold = 5
    timeout             = 5
    target              = "https:8000/index.html"
    interval            = 30
  }
  instances                   = [aws_instance.web_server1.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    name = "techops_laod_balancer"
  }
}
# data "aws_ami" "linux_ami" {
#   executable_users = ["self"]
#   most_recent      = true
#   owners           = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["self"]
#   }
#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-*-*-x86_64-*"]
#   }

#   filter {
#     name   = "root-device-type"
#     values = ["ebs"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }
resource "aws_instance" "web_server1" {
  ami                    = "ami-00f7e5c52c0f43726"
  instance_type          = "t2.small"
  subnet_id              = aws_subnet.subnet-A.id
  vpc_security_group_ids = [aws_security_group.techops_SG-https.id, aws_security_group.techops_SG-ssh.id]
  availability_zone      = "us-west-2a"
}
resource "aws_eip" "eip_web_server1" {
  instance = aws_instance.web_server1.id
  vpc      = true
}
resource "aws_instance" "web_server2" {
  ami                    = "ami-00f7e5c52c0f43726"
  instance_type          = "t2.small"
  subnet_id              = aws_subnet.subnet-B.id
  vpc_security_group_ids = [aws_security_group.techops_SG-https.id, aws_security_group.techops_SG-ssh.id]
  availability_zone      = "us-west-2b"
}
resource "aws_eip" "eip_web_server2" {
  instance = aws_instance.web_server2.id
  vpc      = true
}
resource "aws_instance" "private_instance" {
  ami                    = "ami-00f7e5c52c0f43726"
  instance_type          = "t2.small"
  subnet_id              = aws_subnet.subnet-C.id
  vpc_security_group_ids = [aws_security_group.techops_SG-https-quake3-arena.id, aws_security_group.techops_SG-ssh-quake3-arena.id]
  availability_zone      = "us-west-2c"
}
resource "aws_s3_bucket" "techops_bucket" {
  bucket = "my-techops-test-bucket"
  acl    = "private"

  tags = {
    Name        = "Techops bucket"
    Environment = "Testing"
  }
}
