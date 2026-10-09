# ==============================================================================
# Network Outputs
# ==============================================================================
output "vpc_id" {
  description = "The Unique Identification code generated for your custom VPC"
  value       = aws_vpc.mtec_vpc.id
}
# ==============================================================================
# 6. MANAGEMENT INTERFACE OUTPUTS
# ==============================================================================

output "public_subnets" {
  description = "List containing IDs of all provisioned public subnets"
  value       = [aws_subnet.mtec_pub1a.id, aws_subnet.mtec_pub1b.id]
}
output "rds_endpoint" {
  description = "Copy this database address and paste it into your backend deployment file"
  value       = aws_db_instance.mtec_database.endpoint
}

output "backend_ecr_url" {
  description = "Copy this exact URL and paste it into your backend-deployment.yaml image field"
  value       = aws_ecr_repository.backend_repo.repository_url
}

output "frontend_ecr_url" {
  description = "Copy this exact URL and paste it into your frontend-deployment.yaml image field"
  value       = aws_ecr_repository.frontend_repo.repository_url
}
