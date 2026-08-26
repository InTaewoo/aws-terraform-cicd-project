output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "master_private_ip" {
  value = aws_instance.master.private_ip
}

output "worker_public_ip" {
  value = aws_instance.worker.public_ip
}

output "worker_private_ip" {
  value = aws_instance.worker.private_ip
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "fastapi_nodeport_url" {
  description = "This becomes reachable after Kubernetes, FastAPI and NodePort Service are deployed."
  value       = "http://${aws_instance.worker.public_ip}:30080"
}

output "master_instance_id" {
  value = aws_instance.master.id
}

output "worker_instance_id" {
  value = aws_instance.worker.id
}

output "ssm_master_command" {
  value = "aws ssm start-session --target ${aws_instance.master.id}"
}

output "ssm_worker_command" {
  value = "aws ssm start-session --target ${aws_instance.worker.id}"
}

output "github_actions_role_arn" {
  description = "IAM Role ARN used by GitHub Actions OIDC"
  value       = aws_iam_role.github_actions_ecr.arn
}