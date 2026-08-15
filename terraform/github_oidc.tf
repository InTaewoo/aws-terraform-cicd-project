# ============================================================
# GitHub Actions OIDC Provider
# ============================================================

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name = "${var.project_name}-github-oidc"
  }
}


# ============================================================
# IAM Role for GitHub Actions
#
# Only GitHub Actions running from:
#   InTaewoo/python-api
#   main branch
#
# can assume this role.
# ============================================================

resource "aws_iam_role" "github_actions_ecr" {
  name = "${var.project_name}-github-actions-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"

            "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.github_repository}:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions-ecr-role"
  }
}


# ============================================================
# ECR permissions for GitHub Actions
# ============================================================

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "${var.project_name}-github-actions-ecr-policy"
  role = aws_iam_role.github_actions_ecr.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      # ECR Docker login requires this action.
      # GetAuthorizationToken cannot be restricted to one repository ARN.
      {
        Sid      = "ECRAuthorization"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },

      # Push/Pull permissions are restricted to this project's ECR repo.
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]

        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}