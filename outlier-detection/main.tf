# -----------------------------------------------------------------------------
# Terraform & AWS Provider Configuration
# -----------------------------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# Data Sources (e.g., finding the latest Amazon Linux 2 AMI)
# -----------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# Locals (Common variables)
# -----------------------------------------------------------------------------
locals {
  # Tags applied to all 10 instances for easy discovery
  common_tags = {
    team = "Demo Engineering"
    app  = "outlier_detection"
  }
}

# -----------------------------------------------------------------------------
# Networking (VPC, Subnet, IGW, Route Table)
# -----------------------------------------------------------------------------
resource "aws_vpc" "outlier_demo_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "outlier-demo-vpc"
  }
}

resource "aws_internet_gateway" "outlier_demo_igw" {
  vpc_id = aws_vpc.outlier_demo_vpc.id
  tags = {
    Name = "outlier-demo-igw"
  }
}

resource "aws_subnet" "outlier_demo_subnet" {
  vpc_id                  = aws_vpc.outlier_demo_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Needed for instances to download packages
  tags = {
    Name = "outlier-demo-subnet"
  }
}

resource "aws_route_table" "outlier_demo_rt" {
  vpc_id = aws_vpc.outlier_demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.outlier_demo_igw.id
  }
  tags = {
    Name = "outlier-demo-rt"
  }
}

resource "aws_route_table_association" "outlier_demo_rta" {
  subnet_id      = aws_subnet.outlier_demo_subnet.id
  route_table_id = aws_route_table.outlier_demo_rt.id
}

# -----------------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------------
resource "aws_security_group" "outlier_demo_fleet_sg" {
  name        = "outlier-demo-fleet-sg"
  description = "Allow all outbound and SSH inbound"
  vpc_id      = aws_vpc.outlier_demo_vpc.id

  # Allow SSH for debugging
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  # Allow all outbound for yum updates and stress-ng installation
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "outlier-demo-fleet-sg"
  }
}

# -----------------------------------------------------------------------------
# The "Fleet" (9 Normal Nodes via Auto Scaling Group)
# -----------------------------------------------------------------------------
resource "aws_launch_template" "outlier_demo_fleet_template" {
  name_prefix   = "outlier-demo-fleet-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  key_name      = var.ec2_key_name # Changed from hardcoded string

  vpc_security_group_ids = [aws_security_group.outlier_demo_fleet_sg.id]

  # This block applies the tags to the INSTANCES themselves
  tag_specifications {
    resource_type = "instance"
    tags          = local.common_tags
  }

  # Load the user data script for normal load
  # We now pass in the New Relic variables to the template file.
  user_data = base64encode(templatefile("${path.module}/normal_load_user_data.sh", {
    nr_api_key    = var.new_relic_api_key
    nr_account_id = var.new_relic_account_id
  }))

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "outlier_demo_fleet_asg" {
  name = "outlier-demo-fleet-asg"

  # Fleet size of 9
  desired_capacity = 9
  min_size         = 9
  max_size         = 9

  vpc_zone_identifier = [aws_subnet.outlier_demo_subnet.id]

  launch_template {
    id      = aws_launch_template.outlier_demo_fleet_template.id
    version = "$Latest"
  }
}

# -----------------------------------------------------------------------------
# The "Outlier" (1 Anomaly Node via Standalone Instance)
# -----------------------------------------------------------------------------
resource "aws_instance" "outlier_demo_outlier_node" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.medium"
  key_name      = var.ec2_key_name
  subnet_id     = aws_subnet.outlier_demo_subnet.id

  vpc_security_group_ids = [aws_security_group.outlier_demo_fleet_sg.id]
  tags                   = local.common_tags

  # Load the user data script that includes the normal load + the spike
  # We also pass in the New Relic variables here.
  user_data_base64 = base64encode(templatefile("${path.module}/outlier_load_user_data.sh", {
    nr_api_key    = var.new_relic_api_key
    nr_account_id = var.new_relic_account_id
  }))
}

# -----------------------------------------------------------------------------
# Print the results
# -----------------------------------------------------------------------------
data "aws_instances" "outlier_demo_instances" {
    depends_on = [
        aws_autoscaling_group.outlier_demo_fleet_asg
        ,aws_instance.outlier_demo_outlier_node
     ]
    
    # find the instances matching the app tag from the launch template
    filter {
        name = "tag:app"
        values = [local.common_tags.app]
    }
    filter {
        name = "instance-state-name"
        values = ["running"]
    }
}

output "outlier_demo_instance_details" {
  description = "Details for the 10 instances."
  value = [
    # Loop over the instance IDs found by the data source
    for i, id in data.aws_instances.outlier_demo_instances.ids : {
      public_ip   = data.aws_instances.outlier_demo_instances.public_ips[i]
      instance_id = id
    }
  ]
}
