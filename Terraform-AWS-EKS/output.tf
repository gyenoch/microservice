output "availability_zones" {
  value = data.aws_availability_zones.available.names
}

output "endpoint" {
  value = aws_eks_cluster.eks[0].endpoint
}

output "eks-certificate" {
  value = aws_eks_cluster.eks[0].identity[0].oidc[0].issuer
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.eks[0].certificate_authority[0].data
}

output "provider" {
  value = aws_iam_openid_connect_provider.eks-oidc
}

# Output For EC2 Instance
output "SonarqubeIP" {
  value = aws_instance.web.public_ip
}

output "SonarqubeURL" {
  value = "http://${aws_instance.web.public_ip}:9000"
}