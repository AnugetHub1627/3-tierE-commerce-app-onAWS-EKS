# ==============================================================================
# Network Outputs
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
  description = "The public IP of the NAT Gateway"
  value       = aws_nat_gateway.mtec_nat.public_ip
}

# ==============================================================================
# AMAZON EKS CLUSTER OUTPUTS
# ==============================================================================
output "eks_cluster_name" {
  description = "The name of the EKS Cluster"
  value       = aws_eks_cluster.mtec-EKS.name
}

output "eks_cluster_endpoint" {
  description = "The endpoint URL for your Kubernetes API server connection"
  value       = aws_eks_cluster.mtec-EKS.endpoint
}
# ==============================================================================
# AWS RDS MYSQL DATABASE OUTPUTS
# ==============================================================================
output "database_endpoint" {
  description = "ACTION REQUIRED: Copy this exact string and paste it into the DB_HOST value in backend-deployment.yaml"
  value       = aws_db_instance.mtec_database.endpoint
}

output "database_name" {
  description = "The initial database schema name configured inside MySQL"
  value       = aws_db_instance.mtec_database.db_name
}
# ==============================================================================
# AMAZON ECR REGISTRY OUTPUTS
# ==============================================================================
output "backend_ecr_url" {
  description = "Copy this exact URL and paste it into your backend-deployment.yaml image field"
  value       = aws_ecr_repository.backend_repo.repository_url
}

output "frontend_ecr_url" {
  description = "Copy this exact URL and paste it into your frontend-deployment.yaml image field"
  value       = aws_ecr_repository.frontend_repo.repository_url
}
