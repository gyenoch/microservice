#https://docs.aws.amazon.com/eks/latest/userguide/creating-a-vpc.html

resource "aws_eks_cluster" "eks" {
  count    = "1"
  name     = "mycluster"
  role_arn = aws_iam_role.eksclusterrole.arn
  version  = "1.29"

  upgrade_policy {
    support_type = "STANDARD"
  }

  vpc_config {
    subnet_ids              = [aws_subnet.private[0].id, aws_subnet.private[1].id, aws_subnet.private[2].id, aws_subnet.private[3].id]
    security_group_ids      = [aws_security_group.cluster_sg.id]
    endpoint_private_access = "true"
    endpoint_public_access  = "false"
  }

  access_config {
    authentication_mode                         = "CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = "true"
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy
  ]

  tags = {
    Name = "mycluster"
    Env  = "Dev"
  }
}

resource "aws_iam_openid_connect_provider" "eks-oidc" {
  url             = aws_eks_cluster.eks[0].identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks-certificate.certificates[0].sha1_fingerprint]
}

resource "aws_eks_addon" "example" {
  for_each      = local.addons
  cluster_name  = aws_eks_cluster.eks[0].name
  addon_name    = each.key
  addon_version = each.value

}

# worker nodes
# spot nodes

resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.eks[0].name
  node_group_name = "myspotnodes"
  node_role_arn   = aws_iam_role.eksnoderole.arn
  subnet_ids      = [aws_subnet.private[0].id, aws_subnet.private[1].id, aws_subnet.private[2].id, aws_subnet.private[3].id]
  disk_size       = "80"
  scaling_config {
    desired_size = 3
    max_size     = 6
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  #instance_types = ["t2.small"]
  instance_types = ["c5a.xlarge", "m5a.large", "m5a.xlarge", "c5.large", "m5.large", "t3a.large", "t3a.xlarge", "t3a.medium"]
  capacity_type  = "SPOT"

  labels = {
    type = "spot"
  }

  tags = {
    Name                                  = "spot-nodes"
    "k8s.io/cluster-autoscaler/enabled"   = "true"
    "k8s.io/cluster-autoscaler/mycluster" = "true"
  }

  depends_on = [
    aws_eks_cluster.eks,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.AmazonEBSCSIDriverPolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy
  ]

}