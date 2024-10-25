#https://docs.aws.amazon.com/eks/latest/userguide/cluster-iam-role.html
# EKS Cluster Role
resource "aws_iam_role" "eksclusterrole" {
  name = "eksclusterroletf"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eksclusterrole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS Node Role
resource "aws_iam_role" "eksnoderole" {
  name = "eksnoderoletf"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eksnoderole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eksnoderole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eksnoderole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "AmazonEBSCSIDriverPolicy" {
  role       = aws_iam_role.eksnoderole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Add permissions for Cluster Autoscaler
resource "aws_iam_role_policy_attachment" "AutoScalingFullAccess" {
  role       = aws_iam_role.eksnoderole.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodeAutoscalerPolicy" {
  role       = aws_iam_role.eksnoderole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "EC2AutoScalingPolicy" {
  role       = aws_iam_role.eksnoderole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

# Cluster Autoscaler IAM Role with OIDC
resource "aws_iam_role" "cluster_autoscaler_iam_role" {
  name = "eks-autoscaler-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks-oidc.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "eks.amazonaws.com:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "cluster_autoscaler_policy" {
  name = "cluster-autoscaler-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_policy_attach" {
  role       = aws_iam_role.cluster_autoscaler_iam_role.name
  policy_arn = aws_iam_policy.cluster_autoscaler_policy.arn
}

# Attach necessary policies for Cluster Autoscaler to manage Auto Scaling
resource "aws_iam_role_policy_attachment" "cluster_autoscaler_AutoScalingFullAccess" {
  role       = aws_iam_role.cluster_autoscaler_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}

# OIDC for other service accounts
resource "aws_iam_role" "eks_oidc" {
  name = "eks-oidc"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRoleWithWebIdentity",
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks-oidc.arn
        },
        Condition = {
          StringEquals = {
            "aws_iam_openid_connect_provider.eks-oidc.url:sub" = "system:serviceaccount:hipstershop:my-service-account"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "eks-oidc-policy" {
  name = "Secrets-policy"

  policy = jsonencode({
    Statement = [{
      Effect = "Allow",
      Action = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue"
      ],
      Resource = "arn:aws:secretsmanager:us-east-1:091008253157:secret:my-registry-secret-wTqYoT"
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks-oidc-policy-attach" {
  role       = aws_iam_role.eks_oidc.name
  policy_arn = aws_iam_policy.eks-oidc-policy.arn
}

# Create the IAM Role for Jump Server and Attach the Administrator Policy
resource "aws_iam_role" "bootstrap_node_role" {
  name = "bootstrap_node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bootstrap_node_role_attach" {
  role       = aws_iam_role.bootstrap_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Create an Instance Profile and Attach the Role
resource "aws_iam_instance_profile" "bootstrap_node_instance_profile" {
  name = "bootstrap_node-instance-profile"
  role = aws_iam_role.bootstrap_node_role.name
}