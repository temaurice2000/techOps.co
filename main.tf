provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "techops_vpc" {
  cidr_block = "10.10.10.0/24"

  tags = {
    Name = "techops_vpc"
  }
}
resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.techops_vpc.id
  cidr_block        = "10.10.10.0/26"
  availability_zone = "us-west-2a"
  tags = {
    Name = "public_subnet_a"
  }
}
resource "aws_subnet" "public_subnet_b" {
  vpc_id            = aws_vpc.techops_vpc.id
  cidr_block        = "10.10.10.64/26"
  availability_zone = "us-west-2b"
  tags = {
    Name = "public_subnet_b"
  }
}
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.techops_vpc.id
  cidr_block        = "10.10.10.128/25"
  availability_zone = "us-west-2c"
  tags = {
    Name = "private_subnet_C"
  }
}
resource "aws_internet_gateway" "techops_igw" {
  vpc_id = aws_vpc.techops_vpc.id
  tags = {
    name = "internet_GW"
  }
}
resource "aws_route_table" "public_RT" {
  vpc_id = aws_vpc.techops_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.techops_igw.id
  }
}
resource "aws_route_table_association" "asubnet_rt" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_RT.id
}
resource "aws_route_table_association" "bsubnet_rt" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_RT.id
}
resource "aws_nat_gateway" "techops_nat" {
  allocation_id = aws_eip.elastic_ip.id
  subnet_id     = aws_subnet.public_subnet_b.id

  tags = {
    Name = "techops_nat"
  }
}

resource "aws_eip" "elastic_ip" {
  vpc = true
}
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.techops_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.techops_nat.id
  }
}
resource "aws_route_table_association" "csubnet_rt" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_instance" "web-instance001" {
  ami                    = "ami-0892d3c7ee96c0bf7"
  instance_type          = "t2.small"
  subnet_id              = aws_subnet.public_subnet_a.id
  availability_zone = "us-west-2a"
  security_groups        = [aws_security_group.techops_SG-SSH.id, aws_security_group.techops_SG-https.id]
  tags = {
    name = "web-server-001"
  }
}
resource "aws_eip" "webserver001-eip" {
  vpc      = true
  instance = aws_instance.web-instance001.id
}
resource "aws_instance" "web-instance002" {
  ami                    = "ami-0892d3c7ee96c0bf7"
  instance_type          = "t2.small"
  subnet_id              = aws_subnet.public_subnet_b.id
  availability_zone = "us-west-2b"
  key_name = "terraform_key_pair"
  security_groups        = [aws_security_group.techops_SG-SSH.id, aws_security_group.techops_SG-https.id]
  tags = {
    name = "web-server-002"
  }
}
resource "aws_eip" "webserver002-eip" {
  vpc      = true
  instance = aws_instance.web-instance002.id
}
resource "aws_instance" "private-instance" {
  ami                    = "ami-0892d3c7ee96c0bf7"
  instance_type          = "t2.small"
  subnet_id              = aws_subnet.private_subnet.id
  availability_zone = "us-west-2c"
  security_groups        = [aws_security_group.techops_SG-2.id]
  tags = {
    name = "private-instance"
  }
}
resource "aws_security_group" "techops_SG-2" {
  name = "quake III access"
  description = "allow access to Quake III"
  vpc_id = aws_vpc.techops_vpc.id  
  ingress  {
    description = "allow access to Quake III"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["10.10.10.0/26", "10.10.10.64/26"]
  }
  ingress  {
    description = "allow ssh from vpc"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["10.10.10.0/24"]             
  }
}
resource "aws_security_group" "techops_SG-SSH" {
  vpc_id      = aws_vpc.techops_vpc.id
  description = "Allow ssh inbound traffic"
  name        = "techops_SG-SSH"
  ingress {
    description      = "SSh from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["10.10.10.0/24"]
  }
  tags = {
    "name" = "allow ssh from VPC"
  }
}
resource "aws_security_group" "techops_SG-https" {
  name        = "techops_SG-https"
  description = "Allow HTTPs from Internet"
  vpc_id      = aws_vpc.techops_vpc.id
  ingress {
    description      = "https from internet"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags = {
    "name" = "https traffic from internet"
  }
}