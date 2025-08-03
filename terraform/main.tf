provider "aws" {
  profile = "eks-account"
  region  = "ap-south-1"
}

# Get default VPC and subnet
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
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

  # Internal cluster traffic - allow all traffic from instances with this SG
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

# EC2 instances
resource "aws_instance" "jenkins_builder" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.medium"
  key_name               = "EKS_SSH_Key"  # Updated key name
  vpc_security_group_ids = [aws_security_group.eks_cluster_sg.id]
  subnet_id              = data.aws_subnets.default.ids[0]

  tags = {
    Name = "jenkins-builder"
    Role = "Jenkins, Docker"
  }
}

resource "aws_instance" "k8s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.medium"
  key_name               = "EKS_SSH_Key"  # Updated key name
  vpc_security_group_ids = [aws_security_group.eks_cluster_sg.id]
  subnet_id              = data.aws_subnets.default.ids[0]

  tags = {
    Name = "k8s-master"
    Role = "Kubeadm control plane"
  }
}

resource "aws_instance" "k8s_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.medium"
  key_name               = "EKS_SSH_Key"  # Updated key name
  vpc_security_group_ids = [aws_security_group.eks_cluster_sg.id]
  subnet_id              = data.aws_subnets.default.ids[0]

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