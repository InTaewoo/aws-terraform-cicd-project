# ============================================================
# Kubernetes Master / Worker Security Group
# ============================================================

resource "aws_security_group" "k8s" {
  name        = "${var.project_name}-k8s-sg"
  description = "Security group for kubeadm master and worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-k8s-sg"
  }
}


# ============================================================
# Kubernetes Cluster Internal Traffic
#
# Master <-> Worker communication
# kube-apiserver / kubelet / CNI / etc.
# ============================================================

resource "aws_vpc_security_group_ingress_rule" "cluster_internal" {
  security_group_id            = aws_security_group.k8s.id
  referenced_security_group_id = aws_security_group.k8s.id

  ip_protocol = "-1"

  description = "All traffic inside kubeadm cluster security group"
}


# ============================================================
# FastAPI NodePort
#
# Only allow configured client CIDRs.
# Example:
# nodeport_allowed_cidrs = {
#   home = "1.2.3.4/32"
# }
# ============================================================

resource "aws_vpc_security_group_ingress_rule" "nodeport" {
  for_each = var.nodeport_allowed_cidrs

  security_group_id = aws_security_group.k8s.id

  cidr_ipv4 = each.value

  from_port   = 30080
  to_port     = 30080
  ip_protocol = "tcp"

  description = "FastAPI NodePort 30080"
}


# ============================================================
# Outbound Internet Access
#
# Required for:
# - SSM communication
# - apt/yum package installation
# - Kubernetes image pull
# - ECR access
# - GitHub / external repositories
# ============================================================

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.k8s.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Outbound Internet access"
}