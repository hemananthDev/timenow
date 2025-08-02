output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "ecr_repo_url" {
  value = aws_ecr_repository.app_repo.repository_url
}
