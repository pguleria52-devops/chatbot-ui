provider "aws" {
  region = "us-east-1" # Change as needed
}

# Fetch VPC Data (Change VPC ID if needed)
data "aws_vpc" "default" {
  default = true
}

# Fetch Public and Private Subnets for EKS
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 🔹 IAM Role for EKS Cluster
data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "eks-cluster-cloud"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

# Attach EKS Cluster Policies
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# 🔹 EKS Cluster
resource "aws_eks_cluster" "example" {
  name     = "EKS_CLOUD"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = data.aws_subnets.private.ids # Use Private Subnets for Security
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# 🔹 IAM Role for Worker Nodes (Node Group)
data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_node_role" {
  name               = "eks-node-group-cloud"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
}

# Attach EKS Node Policies
resource "aws_iam_role_policy_attachment" "eks_node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ])
  policy_arn = each.value
  role       = aws_iam_role.eks_node_role.name
}

# 🔹 EKS Node Group
resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "Node-cloud"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = data.aws_subnets.private.ids # Use Private Subnets for Worker Nodes

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policies
  ]
}

# 🔹 Outputs
output "eks_cluster_endpoint" {
  value = aws_eks_cluster.example.endpoint
}

output "eks_cluster_id" {
  value = aws_eks_cluster.example.id
}

output "node_group_arn" {
  value = aws_eks_node_group.example.arn
}
