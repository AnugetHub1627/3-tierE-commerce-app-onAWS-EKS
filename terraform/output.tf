# ==============================================================================
# 1. NETWORK TOPOLOGY OUTPUTS
# ==============================================================================
output "vpc_id" {
  description = "The Unique Identification code generated for your custom VPC"
  value       = aws_vpc.mtec_vpc.id
}

output "public_subnets" {
  description = "List containing IDs of all provisioned public subnets"
  value       = [aws_subnet.mtec_pub1a.id, aws_subnet.mtec_pub1b.id]
}

output "nat_gateway_public_ip" {
  description = "The public IP of the NAT Gateway used by your private workloads"
  value       = aws_nat_gateway.mtec_nat.public_ip
}

# ==============================================================================
# 2. AMAZON EKS CLUSTER OUTPUTS
# ==============================================================================
output "eks_cluster_name" {
  description = "The target cluster name for updating kubeconfig contexts"
  value       = aws_eks_cluster.mtec-EKS.name
}

output "eks_cluster_endpoint" {
  description = "The endpoint URL for your Kubernetes API server connection"
  value       = aws_eks_cluster.mtec-EKS.endpoint
}

# ==============================================================================
# 3. AWS RDS MYSQL DATABASE OUTPUTS
# ==============================================================================
output "rds_endpoint" {
  description = "Automated Endpoint injection key for backend microservices"
  value       = aws_db_instance.mtec_database.endpoint
}

output "database_name" {
  description = "The initial database schema name configured inside MySQL"
  value       = aws_db_instance.mtec_database.db_name
}

# ==============================================================================
# 4. AMAZON ECR REGISTRY OUTPUTS
# ==============================================================================
output "backend_ecr_url" {
  description = "Target registry path for pushing backend container builds"
  value       = aws_ecr_repository.backend_repo.repository_url
}

output "frontend_ecr_url" {
  description = "Target registry path for pushing frontend container builds"
  value       = aws_ecr_repository.frontend_repo.repository_url
}
