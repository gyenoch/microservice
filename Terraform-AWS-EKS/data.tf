data "aws_availability_zones" "available" {
  state = "available"
}

data "tls_certificate" "eks-certificate" {
  url = aws_eks_cluster.eks[0].identity[0].oidc[0].issuer
}

data "aws_eks_cluster" "eks_ready" {
  name = aws_eks_cluster.eks[0].name
}

data "aws_eks_cluster_auth" "eks_auth" {
  name = aws_eks_cluster.eks[0].name
}

#data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"] #ami-0e86e20dae9224db8
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}