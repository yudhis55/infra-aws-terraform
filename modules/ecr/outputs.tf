output "repository_url" {
  description = "URL of the application ECR repository."
  value       = aws_ecr_repository.app.repository_url
}
