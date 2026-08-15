# AWS kubeadm + Terraform 개인 프로젝트 - Infra

아키텍처의 1단계 인프라를 Terraform으로 생성합니다.

## 생성 리소스

- VPC
- Public Subnet
- Internet Gateway
- Route Table
- Security Group
- EC2 Master Node (기본 t3.medium)
- EC2 Worker Node (기본 t3.large)
- ECR Private Repository
- EC2 IAM Role / Instance Profile
- EC2 Key Pair (로컬에서 만든 공개키만 AWS에 등록)

Terraform 적용 시 EC2의 cloud-init(user_data)이 다음 항목까지 설치합니다.

- containerd
- kubeadm
- kubelet
- kubectl
- Kubernetes 기본 커널/sysctl 설정
- swap 비활성화
- systemd cgroup 설정

> `kubeadm init`, CNI 설치, Worker join, Argo CD 설치는 Terraform 이후 단계에서 수행합니다.

## 로컬 사전 준비

Windows PowerShell 기준:

```powershell
terraform version
aws --version
git --version
ssh -V
```

AWS 인증:

```powershell
aws configure
aws sts get-caller-identity
```

SSH Key 생성:

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\aws-k8s-cicd" -C "aws-k8s-cicd"
```

현재 외부 Public IP 확인:

```powershell
(Invoke-RestMethod https://checkip.amazonaws.com).Trim()
```

## 실행

```powershell
cd terraform
Copy-Item terraform.tfvars.example terraform.tfvars
code terraform.tfvars
```

`terraform.tfvars`에서 `my_ip_cidr`를 본인의 공인 IP `/32`로 변경합니다.

예:

```hcl
my_ip_cidr = "203.0.113.10/32"
```

그 다음:

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

출력 확인:

```powershell
terraform output
```

Master 접속:

```powershell
ssh -i "$env:USERPROFILE\.ssh\aws-k8s-cicd" ubuntu@<MASTER_PUBLIC_IP>
```

Worker 접속:

```powershell
ssh -i "$env:USERPROFILE\.ssh\aws-k8s-cicd" ubuntu@<WORKER_PUBLIC_IP>
```

각 노드에서 cloud-init 완료 확인:

```bash
cloud-init status --wait
containerd --version
kubeadm version
kubelet --version
kubectl version --client
```

## 삭제

실습이 끝난 뒤 비용 방지를 위해:

```powershell
terraform destroy
```

## 다음 단계

1. Master에서 `kubeadm init`
2. CNI 설치
3. Worker `kubeadm join`
4. Argo CD 설치
5. FastAPI 애플리케이션 저장소 구성
6. GitHub Actions → ECR
7. GitOps 저장소(Kustomize) 이미지 태그 갱신
8. Argo CD Auto Sync
9. NodePort 30080으로 FastAPI 확인
