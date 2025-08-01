resource "aws_ecr_repository" "timenow_repo" {
  name                 = "timenow-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "TimeNowAppECR"
    Environment = "Dev"
  }
}

output "ecr_repo_url" {
  value = aws_ecr_repository.timenow_repo.repository_url
}
