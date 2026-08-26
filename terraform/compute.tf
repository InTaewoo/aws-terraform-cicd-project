resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.master_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k8s.id]
  #associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.node.name

  user_data = templatefile("${path.module}/scripts/bootstrap-k8s.sh.tftpl", {
    node_name                = "k8s-master"
    kubernetes_minor_version = var.kubernetes_minor_version
  })

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-master"
    Role = "control-plane"
  }
}

resource "aws_instance" "worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k8s.id]
  #associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.node.name

  user_data = templatefile("${path.module}/scripts/bootstrap-k8s.sh.tftpl", {
    node_name                = "k8s-worker"
    kubernetes_minor_version = var.kubernetes_minor_version
  })

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-worker"
    Role = "worker"
  }
}


## EC2 리소스 일시 중지
resource "aws_ec2_instance_state" "master" {
  instance_id = aws_instance.master.id
  state       = "running"
}

resource "aws_ec2_instance_state" "worker" {
  instance_id = aws_instance.worker.id
  state       = "running"
}