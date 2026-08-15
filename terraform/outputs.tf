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

output "ssh_master" {
  value = "ssh -i ~/.ssh/aws-k8s-cicd ubuntu@${aws_instance.master.public_ip}"
}

output "ssh_worker" {
  value = "ssh -i ~/.ssh/aws-k8s-cicd ubuntu@${aws_instance.worker.public_ip}"
}
