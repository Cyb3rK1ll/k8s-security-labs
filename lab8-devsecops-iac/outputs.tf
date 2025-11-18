output "cluster_name" {
  value = module.eks.cluster_name
}

output "threatvision_url" {
  value       = "https://${var.domain_name}"
  description = "TU LINK PARA CALLAR BOCAS"
}

output "gitlab_role_arn" {
  value = data.aws_iam_role.gitlab_ci.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.juice_shop.repository_url
}
