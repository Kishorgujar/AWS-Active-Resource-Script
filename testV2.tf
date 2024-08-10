terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.9.0"
}

#Provider
provider "aws" {
  region = "ap-south-1" 
}

# Private VPC
resource "aws_vpc" "private_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "Private_VPC"
  }
}

# Private Subnets
resource "aws_subnet" "private_ec2_sub" {
  vpc_id            = aws_vpc.private_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "Private_Ec2_Sub"
  }
}

resource "aws_subnet" "private_tgw_sub" {
  vpc_id            = aws_vpc.private_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "Private_TGW_Sub"
  }
}

# Private Route Tables
resource "aws_route_table" "private_ec2_route" {
  vpc_id = aws_vpc.private_vpc.id
  tags = {
    Name = "Private_ec2_route"
  }
}

resource "aws_route_table" "private_tgw_route" {
  vpc_id = aws_vpc.private_vpc.id
  tags = {
    Name = "Private_TGW_route"
  }
}

resource "aws_route_table_association" "private_ec2_sub_association" {
  subnet_id      = aws_subnet.private_ec2_sub.id
  route_table_id = aws_route_table.private_ec2_route.id
}

resource "aws_route_table_association" "private_tgw_sub_association" {
  subnet_id      = aws_subnet.private_tgw_sub.id
  route_table_id = aws_route_table.private_tgw_route.id
}

# Public VPC
resource "aws_vpc" "public_vpc" {
  cidr_block = "192.168.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "Public_VPC"
  }
}

# Public Subnets
resource "aws_subnet" "public_pub_sub" {
  vpc_id            = aws_vpc.public_vpc.id
  cidr_block        = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "Public_Pub_Sub"
  }
}

resource "aws_subnet" "public_tgw_sub" {
  vpc_id            = aws_vpc.public_vpc.id
  cidr_block        = "192.168.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "Public_TGW_Sub"
  }
}


# Internet Gateway
resource "aws_internet_gateway" "public_igw" {
  vpc_id = aws_vpc.public_vpc.id
  tags = {
    Name = "Public_igw"
  }
}

# Public Route Tables
resource "aws_route_table" "public_pub_route" {
  vpc_id = aws_vpc.public_vpc.id
  tags = {
    Name = "Public_Pub_route"
  }
}


resource "aws_route_table" "public_tgw_route" {
  vpc_id = aws_vpc.public_vpc.id
  tags = {
    Name = "Public_TGW_route"
  }
}

resource "aws_route_table_association" "public_pub_sub_association" {
  subnet_id      = aws_subnet.public_pub_sub.id
  route_table_id = aws_route_table.public_pub_route.id
}

resource "aws_route_table_association" "public_tgw_sub_association" {
  subnet_id      = aws_subnet.public_tgw_sub.id
  route_table_id = aws_route_table.public_tgw_route.id
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_pub_route.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.public_igw.id
}

# Security Group
resource "aws_security_group" "test_sg" {
  name        = "Test"
  vpc_id      = aws_vpc.private_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#VPC Endpoints
resource "aws_vpc_endpoint" "ec2" {
  vpc_id            = aws_vpc.private_vpc.id
  service_name      = "com.amazonaws.ap-south-1.ssm"
  subnet_ids = [aws_subnet.private_ec2_sub.id]
  vpc_endpoint_type = "Interface"
  security_group_ids = [aws_security_group.test_sg.id]
  private_dns_enabled = true
  tags ={
    Name = "ec2"
}
}

resource "aws_vpc_endpoint" "ssm_msg" {
  vpc_id            = aws_vpc.private_vpc.id
  service_name      = "com.amazonaws.ap-south-1.ssmmessages"
  subnet_ids = [aws_subnet.private_ec2_sub.id]
  vpc_endpoint_type = "Interface"
  security_group_ids = [aws_security_group.test_sg.id]
  private_dns_enabled = true 
  tags ={
    Name = "ssm_msg"
}

}

# Transit Gateway
resource "aws_ec2_transit_gateway" "test_tgw" {
  description = "Test Transit Gateway"
  tags = {
    Name = "Test_TGW"
  }
}

# Transit Gateway Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "public_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.test_tgw.id
  vpc_id             = aws_vpc.public_vpc.id
  subnet_ids          = [aws_subnet.public_tgw_sub.id]
  transit_gateway_default_route_table_association = false
  tags = {
    Name = "Public_attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "private_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.test_tgw.id
  vpc_id             = aws_vpc.private_vpc.id
  subnet_ids = [aws_subnet.private_ec2_sub.id]
  transit_gateway_default_route_table_association = false
  tags = {
    Name = "Private_attachment"
  }
}

# Transit Gateway Route Tables
resource "aws_ec2_transit_gateway_route_table" "public_tgw_route" {
  transit_gateway_id = aws_ec2_transit_gateway.test_tgw.id
  tags = {
    Name = "Public_TGW_route"
  }
}

resource "aws_ec2_transit_gateway_route_table" "private_tgw_route" {
  transit_gateway_id = aws_ec2_transit_gateway.test_tgw.id
  tags = {
    Name = "Private_TGW_route"
  }
}

resource "aws_ec2_transit_gateway_route" "public_route" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.public_tgw_route.id
  destination_cidr_block         = "10.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.private_attachment.id
}

resource "aws_ec2_transit_gateway_route" "private_route" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.private_tgw_route.id
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.public_attachment.id
}

# Associate the public route table with the public attachment
resource "aws_ec2_transit_gateway_route_table_association" "public_route_table_association" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.public_tgw_route.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.public_attachment.id
}

# Associate the private route table with the private attachment
resource "aws_ec2_transit_gateway_route_table_association" "private_route_table_association" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.private_tgw_route.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.private_attachment.id
}

# Allocate Elastic IP
resource "aws_eip" "test_eip" {
}

# Create NAT Gateway
resource "aws_nat_gateway" "test_nat" {
  allocation_id = aws_eip.test_eip.id
  subnet_id     = aws_subnet.public_pub_sub.id

  tags = {
    Name = "Test_NAT"
  }
}

 # Edit Private VPC route tables

resource "aws_route" "private_ec2_route" {
    route_table_id = aws_route_table.private_ec2_route.id
  destination_cidr_block    = "0.0.0.0/0"
  transit_gateway_id = aws_ec2_transit_gateway.test_tgw.id
}

# Edit Public VPC route tables

resource "aws_route" "public_NAT_tgw_route" {
  route_table_id = aws_route_table.public_tgw_route.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.test_nat.id
}

resource "aws_route" "Public_Pub_route" {
  route_table_id = aws_route_table.public_pub_route.id
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id = aws_ec2_transit_gateway.test_tgw.id
}

#EC2 Instance
resource "aws_instance" "Test" {
  ami = "ami-068e0f1a600cd311c"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.test_sg.id]
  key_name = "BomBay_Linux"
  associate_public_ip_address = false
  iam_instance_profile = "core"
  subnet_id = aws_subnet.private_ec2_sub.id

  tags = {
    Name = "Test"
  }
}



# Create Key Pair
#resource "aws_key_pair" "BomBay_Linux" {
 # key_name   = "BomBay_Linux"
  #public_key = file("/home/accuser/Downloads/")    #Adjust Path as per your choice
#}

# Create IAM Role
#resource "aws_iam_role" "core" {
 # name = "core"
  
  #assume_role_policy = jsonencode({
   # Version = "2012-10-17"
    #Statement = [
     # {
      #  Action = "sts:AssumeRole"
       # Effect = "Allow"
        #Principal = {
         # Service = "ec2.amazonaws.com"
        #}
      #}
    #]
  #})
#}

# Attach the AmazonSSMManagedInstanceCore policy to the role
#resource "aws_iam_role_policy_attachment" "core_ssm_policy" {
 # policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  #role     = aws_iam_role.core.name
#}
