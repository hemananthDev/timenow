provider "aws" {
  profile = "eks-account"
  region  = "ap-south-1"
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get list of all availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Get supported subnets in ap-south-1 (excluding problematic ones)
data "aws_subnets" "supported" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  # Filter out ap-south-1c if it exists in the available AZs
  filter {
    name   = "availability-zone"
    values = [for az in data.aws_availability_zones.available.names : az if az != "ap-south-1c"]
  }
}

# Security group with all required rules
resource "aws_security_group" "eks_cluster_sg" {
  name        = "eks-cluster-sg"
  description = "Security group for EKS cluster nodes"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins access
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NodePort services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Internal cluster traffic
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-cluster-sg"
  }
}

# Find available instance types in the region
data "aws_ec2_instance_type_offerings" "supported" {
  filter {
    name   = "instance-type"
    values = ["t2.medium", "t3.medium"] # Try both options
  }

  location_type = "availability-zone"
}

# EC2 instances - using supported instance types and subnets
resource "aws_instance" "jenkins_builder" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = contains(data.aws_ec2_instance_type_offerings.supported.instance_types, "t2.medium") ? "t2.medium" : "t3.medium"
  key_name               = "EKS_SSH_Key"
  vpc_security_group_ids = [aws_security_group.eks_cluster_sg.id]
  subnet_id              = data.aws_subnets.supported.ids[0]

  tags = {
    Name = "jenkins-builder"
    Role = "Jenkins, Docker"
  }
}

resource "aws_instance" "k8s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = contains(data.aws_ec2_instance_type_offerings.supported.instance_types, "t2.medium") ? "t2.medium" : "t3.medium"
  key_name               = "EKS_SSH_Key"
  vpc_security_group_ids = [aws_security_group.eks_cluster_sg.id]
  subnet_id              = data.aws_subnets.supported.ids[0]

  tags = {
    Name = "k8s-master"
    Role = "Kubeadm control plane"
  }
}

resource "aws_instance" "k8s_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = contains(data.aws_ec2_instance_type_offerings.supported.instance_types, "t2.medium") ? "t2.medium" : "t3.medium"
  key_name               = "EKS_SSH_Key"
  vpc_security_group_ids = [aws_security_group.eks_cluster_sg.id]
  subnet_id              = data.aws_subnets.supported.ids[0]

  tags = {
    Name = "k8s-worker"
    Role = "Worker node"
  }
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

output "instance_public_ips" {
  value = {
    jenkins_builder = aws_instance.jenkins_builder.public_ip
    k8s_master      = aws_instance.k8s_master.public_ip
    k8s_worker      = aws_instance.k8s_worker.public_ip
  }
}

output "used_instance_type" {
  value = contains(data.aws_ec2_instance_type_offerings.supported.instance_types, "t2.medium") ? "t2.medium" : "t3.medium"
}

output "used_subnet" {
  value = data.aws_subnets.supported.ids[0]
}