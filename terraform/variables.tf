# terraform/variables.tf

variable "region" {
  default = "ap-south-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

provider "aws" {
  region  = var.region
  profile = "eks-account"
}
