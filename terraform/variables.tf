variable "project_name" {
  description = "Project name prefix used for resource names."
  type        = string
  default     = "aws-k8s-skdy-lab"
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "lab"
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform."
  type        = string
  default     = "default"
}

variable "availability_zone" {
  description = "Optional AZ. If null, Terraform selects the first available AZ."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR."
  type        = string
  default     = "10.10.1.0/24"
}


variable "nodeport_allowed_cidrs" {
  description = "CIDRs allowed to access FastAPI NodePort 30080. 0.0.0.0/0 is public Internet access."
  type        = set(string)
  default     = ["0.0.0.0/0"]
}


variable "master_instance_type" {
  description = "EC2 instance type for kubeadm control-plane node."
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker node."
  type        = string
  default     = "t3.large"
}

variable "root_volume_size" {
  description = "Root EBS volume size (GiB) for each node."
  type        = number
  default     = 20
}

variable "kubernetes_minor_version" {
  description = "Kubernetes package repository minor version."
  type        = string
  default     = "v1.36"
}

variable "ecr_repository_name" {
  description = "ECR private repository name."
  type        = string
  default     = "python-api"
}
