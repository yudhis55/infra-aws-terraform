output "repository_url" {
  description = "Immutable ECR repository URL used by the application pipeline"
  value       = module.ecr.repository_url
}
