provider "aws" {
  region = "ap-south-1"
}

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# ==============================================================================
# 1. NETWORK TOPOLOGY (Multi-AZ VPC for EKS)
# ==============================================================================
resource "aws_vpc" "mtec_vpc" {
  cidr_block           = var.mtec_vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name                             = var.mtec_vpc_name
    "kubernetes.io/cluster/mtec-EKS" = "shared"
  }
}

resource "aws_internet_gateway" "mtec_igw" {
  vpc_id = aws_vpc.mtec_vpc.id

  tags = {
    Name = var.mtec_igw_name
  }
}

resource "aws_subnet" "mtec_pub1a" {
  vpc_id                  = aws_vpc.mtec_vpc.id
  cidr_block              = var.mtec_pub1a_cidr
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name                             = var.mtec_pub1a_name
    "kubernetes.io/cluster/mtec-EKS" = "shared"
    "kubernetes.io/role/elb"          = "1" # Correct for public-facing ALBs
  }
}

resource "aws_subnet" "mtec_pub1b" {
  vpc_id                  = aws_vpc.mtec_vpc.id
  cidr_block              = var.mtec_pub1b_cidr
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name                             = var.mtec_pub1b_name
    "kubernetes.io/cluster/mtec-EKS" = "shared"
    "kubernetes.io/role/elb"          = "1" # Correct for public-facing ALBs
  }
}

resource "aws_subnet" "mtec_pvt1a" {
  vpc_id            = aws_vpc.mtec_vpc.id
  cidr_block        = var.mtec_pvt1a_cidr
  availability_zone = "ap-south-1a"

  tags = {
    Name                             = var.mtec_pvt1a_name
    "kubernetes.io/cluster/mtec-EKS" = "shared"
    "kubernetes.io/role/internal-elb" = "1" # FIX: For internal load balancers
  }
}

resource "aws_subnet" "mtec_pvt1b" {
  vpc_id            = aws_vpc.mtec_vpc.id
  cidr_block        = var.mtec_pvt1b_cidr
  availability_zone = "ap-south-1b"

  tags = {
    Name                             = var.mtec_pvt1b_name
    "kubernetes.io/cluster/mtec-EKS" = "shared" # FIX: Changed from ci-cd-EKS to mtec-EKS
    "kubernetes.io/role/internal-elb" = "1" # FIX: For internal load balancers
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "mtec_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.mtec_pub1a.id

  tags = {
    Name = var.mtec_nat_name
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.mtec_vpc.id
  name = "public-rt"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mtec_igw.id
  }
}

resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.mtec_vpc.id
  name = "private-rt"
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mtec_nat.id
  }
}

resource "aws_route_table_association" "ass_pub_1a" {
  subnet_id      = aws_subnet.mtec_pub1a.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "ass_pub_1b" {
  subnet_id      = aws_subnet.mtec_pub1b.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "pvt_1a" {
  subnet_id      = aws_subnet.mtec_pvt1a.id
  route_table_id = aws_route_table.private-rt.id
}

resource "aws_route_table_association" "pvt_1b" {
  subnet_id      = aws_subnet.mtec_pvt1b.id
  route_table_id = aws_route_table.private-rt.id
}

# ==============================================================================
# 3. AMAZON EKS CONTROL PLANE RESOURCES
# ==============================================================================
resource "aws_iam_role" "eks_cluster_role" {
  name = "devops-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_eks_cluster" "mtec-EKS" {
  name     = "mtec-EKS"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.mtec_pub1a.id,
      aws_subnet.mtec_pub1b.id,
      aws_subnet.mtec_pvt1a.id,
      aws_subnet.mtec_pvt1b.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

# ==============================================================================
# 4. AMAZON EKS MANAGED NODE GROUP
# ==============================================================================
resource "aws_iam_role" "eks_node_role" {
  name = "devops-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.mtec-EKS.name
  node_group_name = "mtec-microservice-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.mtec_pvt1a.id, aws_subnet.mtec_pvt1b.id]
  instance_types  = ["m7i-flex.large"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.eks_registry,
  ]
}
# ==============================================================================
# 4. ISOLATED DATABASE TIER (AWS RDS MySQL)
# ==============================================================================
resource "aws_security_group" "db_sg" {
  name        = "mtec-database-sg"
  description = "Allow inbound traffic only from EKS cluster worker nodes"
  vpc_id      = aws_vpc.mtec_vpc.id

  ingress {
    description     = "MySQL access from EKS nodes"
    from_port       = 3306 # MySQL standard port
    to_port         = 3306 
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.mtec-EKS.vpc_config.cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "mtec_db_subnets" {
  name       = "mtec-db-subnet-group"
  subnet_ids = [aws_subnet.mtec_pvt1a.id, aws_subnet.mtec_pvt1b.id]

  tags = {
    Name = "mtec-db-subnet-group"
  }
}

resource "aws_db_instance" "mtec_database" {
  allocated_storage      = 20
  max_allocated_storage  = 50
  db_name                = "ecommerce" # Matches your 'CREATE DATABASE ecommerce'
  engine                 = "mysql"     # Configured for MySQL
  engine_version         = "8.0"       # Stable MySQL version
  instance_class         = "db.t3.micro"
  username               = "dbadmin"
  password               = "LearningSecurePassword123!"
  db_subnet_group_name   = aws_db_subnet_group.mtec_db_subnets.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
}

# ==============================================================================
# 5. AMAZON CONTAINER REGISTRIES (ECR)
# ==============================================================================
resource "aws_ecr_repository" "backend_repo" {
  name                 = "ecommerce-backend"
  image_tag_mutability = "MUTABLE"
  force_destroy        = true # Allows rapid clean-up when you delete your infrastructure
}

resource "aws_ecr_repository" "frontend_repo" {
  name                 = "ecommerce-frontend"
  image_tag_mutability = "MUTABLE"
  force_destroy        = true
}
# ==============================================================================
# 6. OIDC PROVIDER (Required for IAM Roles for Service Accounts / IRSA)
# ==============================================================================
data "tls_certificate" "eks" {
  url = aws_eks_cluster.mtec-EKS.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["://amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.mtec-EKS.identity[0].oidc[0].issuer
}

# ==============================================================================
# 7. IAM ROLE & POLICY FOR AWS LOAD BALANCER CONTROLLER
# ==============================================================================
# Download the official AWS Load Balancer Controller IAM Policy
data "http" "aws_lb_controller_policy" {
  url = "https://githubusercontent.com"
}

resource "aws_iam_policy" "aws_lb_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "Permissions required by the AWS Load Balancer Controller pod"
  policy      = data.http.aws_lb_controller_policy.response_body
}

resource "aws_iam_role" "aws_lb_controller" {
  name = "mtec-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AuthorizedService = "urn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.mtec-EKS.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller" {
  policy_arn = aws_iam_policy.aws_lb_controller.arn
  role       = aws_iam_role.aws_lb_controller.name
}

# ==============================================================================
# 8. HELM INSTALLATION OF THE AWS LOAD BALANCER CONTROLLER
# ==============================================================================
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.mtec-EKS.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.mtec-EKS.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.mtec-EKS.name]
      command     = "aws"
    }
  }
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://github.io"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.mtec-EKS.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_lb_controller.arn
  }

  depends_on = [aws_eks_node_group.nodes]
}


