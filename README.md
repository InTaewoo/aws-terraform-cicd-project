# AWS Terraform 기반 Kubernetes GitOps 인프라

이 저장소는 개인 CI/CD 실습 환경의 기반 AWS 인프라를 Terraform으로 관리합니다. Ubuntu EC2 두 대에 `kubeadm` 기반 Kubernetes 클러스터를 구성할 수 있도록 네트워크, 컴퓨팅, IAM, ECR 및 노드 초기 설정을 코드로 정의했습니다.

Terraform은 AWS 리소스와 Kubernetes 설치에 필요한 노드 패키지까지 준비합니다. `kubeadm init`, Worker 조인, Calico, Argo CD, Istio 및 애플리케이션 배포는 인프라 생성 후 클러스터 단계에서 수행합니다.

## 전체 프로젝트에서의 역할

이 프로젝트는 다음 세 저장소로 분리되어 있습니다.

| 저장소 | 역할 |
| --- | --- |
| [aws-terraform-cicd-project](https://github.com/InTaewoo/aws-terraform-cicd-project) | AWS 네트워크, EC2, IAM, ECR 및 GitHub OIDC 구성 |
| [gitops-version-dashboard](https://github.com/InTaewoo/gitops-version-dashboard) | Node.js 대시보드 애플리케이션과 GitHub Actions CI |
| [gitops-version-dashboard-config](https://github.com/InTaewoo/gitops-version-dashboard-config) | Argo CD, Kustomize, Istio 카나리 배포 및 mTLS 정책 |

전체 배포 흐름은 다음과 같습니다.

```text
개발자가 애플리케이션 저장소에 Push
  → GitHub Actions 테스트
  → Docker 이미지 빌드
  → GitHub OIDC로 AWS IAM Role 수임
  → Amazon ECR에 Commit SHA 태그 이미지 Push
  → GitOps 저장소의 v2 이미지 태그와 배포 메타데이터 변경
  → Argo CD가 변경 감지 및 자동 동기화
  → Kubernetes v2 Deployment 갱신
  → Istio가 v1 90%, v2 10%로 트래픽 분배
```

## 구성한 AWS 아키텍처

```text
AWS ap-northeast-2
└── VPC 10.10.0.0/16
    ├── Internet Gateway
    ├── Public Subnet 10.10.1.0/24
    │   ├── EC2 k8s-master
    │   └── EC2 k8s-worker
    ├── Kubernetes 공용 Security Group
    ├── EC2 IAM Role / Instance Profile
    │   ├── SSM Session Manager 접속 권한
    │   └── 전용 ECR 저장소 Pull 권한
    ├── GitHub Actions OIDC Provider / IAM Role
    │   └── 전용 ECR 저장소 Push 권한
    └── ECR gitops-version-dashboard
```

## Terraform으로 구현한 내용

### 네트워크

- `10.10.0.0/16` VPC 생성
- DNS 지원 및 DNS Hostname 활성화
- `10.10.1.0/24` Public Subnet 생성
- Internet Gateway와 기본 경로 `0.0.0.0/0` 구성
- Subnet과 Public Route Table 연결
- 가용 영역을 지정하지 않으면 사용 가능한 첫 번째 가용 영역 선택

### Kubernetes 노드

- Ubuntu 24.04 LTS 최신 x86_64 AMI 자동 조회
- Control Plane 용도의 `k8s-master` EC2 생성
- Worker 용도의 `k8s-worker` EC2 생성
- 기본 인스턴스 유형
  - Master: `t3.medium`
  - Worker: `t3.large`
- 암호화된 `gp3` 루트 볼륨 사용
- EC2 Instance Metadata Service는 IMDSv2만 허용
- 두 노드에 공통 IAM Instance Profile과 Security Group 연결

### cloud-init 노드 초기화

EC2 생성 시 `terraform/scripts/bootstrap-k8s.sh.tftpl`을 `user_data`로 실행하여 다음 작업을 자동화합니다.

- 노드 Hostname을 `k8s-master`, `k8s-worker`로 설정
- Swap 비활성화
- `overlay`, `br_netfilter` 커널 모듈 활성화
- Bridge 트래픽의 iptables 처리와 IPv4 Forwarding 활성화
- containerd 설치
- containerd의 `SystemdCgroup` 활성화
- Kubernetes 공식 패키지 저장소 등록
- kubelet, kubeadm, kubectl 설치 및 버전 고정
- 설치 완료 여부를 `/var/tmp/k8s-bootstrap-complete.txt`에 기록

Terraform은 패키지 설치까지만 담당합니다. 클러스터 초기화와 운영 컴포넌트 설치를 분리하여 AWS 인프라 변경과 Kubernetes 운영 변경의 책임 범위를 구분했습니다.

### ECR

- `gitops-version-dashboard` Private Repository 생성
- 이미지 태그를 `IMMUTABLE`로 설정하여 같은 태그 덮어쓰기 방지
- 이미지 Push 시 취약점 스캔 활성화
- 최신 20개 이미지만 유지하는 Lifecycle Policy 적용
- Kubernetes 노드는 해당 저장소의 이미지 Pull만 가능
- GitHub Actions Role은 해당 저장소의 이미지 Push/Pull 작업만 가능

### GitHub Actions OIDC

장기 AWS Access Key를 GitHub Secret에 저장하지 않고 GitHub Actions OIDC 토큰으로 AWS Role을 수임합니다.

- OIDC Provider: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- 지정한 GitHub 소유자, 저장소, 브랜치에서 발급된 토큰만 허용
- GitHub의 불변 Owner ID와 Repository ID가 포함된 Subject 형식 지원
- 호환성을 위해 기존 `owner/repository` Subject 형식도 함께 지원
- 권한은 프로젝트 ECR 저장소와 인증 토큰 발급 범위로 제한

## Security Group 정책

| 구분 | 허용 범위 | 목적 |
| --- | --- | --- |
| 클러스터 내부 | 같은 Security Group의 모든 트래픽 | API Server, kubelet, CNI 및 노드 간 통신 |
| Calico Pod CIDR | `192.168.0.0/16`의 모든 트래픽 | Pod 간 통신 |
| NodePort | 설정된 CIDR에서 TCP `30080` | 기존 애플리케이션 직접 접근 실습 |
| Outbound | `0.0.0.0/0`의 모든 트래픽 | SSM, 패키지 설치, ECR 및 외부 저장소 접근 |

현재 `terraform_tfvars`의 `nodeport_allowed_cidrs`는 실습 편의를 위해 `0.0.0.0/0`으로 설정되어 있습니다. 실제 운영에서는 반드시 개인 공인 IP `/32`로 제한하거나 해당 규칙을 제거해야 합니다.

Istio 도입 후 정상 사용자 트래픽은 애플리케이션 NodePort `30080`이 아니라 Istio Ingress Gateway NodePort `30081`을 통과합니다. `STRICT mTLS` 적용 상태에서는 `30080` 평문 직접 접근이 차단됩니다.

## 디렉터리 구조

```text
.
├── README.md
├── check-local.ps1
└── terraform
    ├── compute.tf
    ├── data.tf
    ├── ecr.tf
    ├── github_oidc.tf
    ├── iam.tf
    ├── locals.tf
    ├── network.tf
    ├── outputs.tf
    ├── providers.tf
    ├── security.tf
    ├── variables.tf
    ├── versions.tf
    ├── terraform.tfvars.example
    └── scripts
        └── bootstrap-k8s.sh.tftpl
```

## 사전 준비

- Terraform `1.10` 이상 `2.0` 미만
- AWS CLI
- Git
- AWS 계정과 Terraform 리소스 생성 권한
- 로컬 AWS CLI Profile
- SSM Session Manager Plugin

Windows PowerShell에서 로컬 도구와 AWS 인증 상태를 확인할 수 있습니다.

```powershell
.\check-local.ps1
```

직접 확인하려면 다음 명령을 사용합니다.

```powershell
terraform version
aws --version
aws sts get-caller-identity
```

## 변수 설정

```powershell
cd terraform
Copy-Item terraform.tfvars.example terraform.tfvars
```

주요 변수는 다음과 같습니다.

| 변수 | 설명 | 현재 프로젝트 값 |
| --- | --- | --- |
| `aws_region` | AWS Region | `ap-northeast-2` |
| `vpc_cidr` | VPC CIDR | `10.10.0.0/16` |
| `public_subnet_cidr` | Public Subnet CIDR | `10.10.1.0/24` |
| `master_instance_type` | Master 인스턴스 유형 | `t3.medium` |
| `worker_instance_type` | Worker 인스턴스 유형 | `t3.large` |
| `root_volume_size` | 루트 볼륨 크기 | `20 GiB` |
| `kubernetes_minor_version` | Kubernetes 패키지 저장소 버전 | `v1.36` |
| `ecr_repository_name` | ECR 저장소 이름 | `gitops-version-dashboard` |
| `github_owner` | GitHub 사용자 또는 조직 | `InTaewoo` |
| `github_repository` | OIDC를 허용할 애플리케이션 저장소 | `gitops-version-dashboard` |
| `github_branch` | OIDC를 허용할 브랜치 | `master` |

`terraform.tfvars`와 Terraform State에는 환경 정보가 들어갈 수 있으므로 Git에 커밋하지 않습니다.

## Terraform 실행

```powershell
cd terraform
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

출력값 확인:

```powershell
terraform output
```

주요 출력값:

- VPC 및 Public Subnet ID
- Master/Worker Public IP와 Private IP
- Master/Worker EC2 Instance ID
- ECR Repository URL
- GitHub Actions IAM Role ARN
- Master/Worker SSM 접속 명령

## 노드 접속과 초기화 확인

보안그룹에 SSH를 열지 않고 SSM Session Manager를 사용합니다.

```powershell
aws ssm start-session --target <MASTER_INSTANCE_ID> --region ap-northeast-2
aws ssm start-session --target <WORKER_INSTANCE_ID> --region ap-northeast-2
```

각 노드에서 cloud-init과 런타임 설치 상태를 확인합니다.

```bash
cloud-init status --wait
cat /var/tmp/k8s-bootstrap-complete.txt
containerd --version
kubeadm version
kubelet --version
kubectl version --client
```

## Terraform 이후 단계

1. Master에서 `kubeadm init` 실행
2. kubectl kubeconfig 설정
3. Calico CNI 설치
4. Worker에서 `kubeadm join` 실행
5. Argo CD 설치
6. Istio Base, istiod, Ingress Gateway 설치
7. GitOps 저장소의 Argo CD Application 등록
8. v1/v2 카나리 배포와 `STRICT mTLS` 검증

애플리케이션 및 Kubernetes 배포 설정은 각각 별도 저장소에서 관리합니다.

## 운영 확인 명령

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get svc -A
```

GitHub Actions OIDC로 생성된 최근 인증 이벤트와 ECR 이미지는 AWS CLI로 확인할 수 있습니다.

```powershell
aws cloudtrail lookup-events `
  --region ap-northeast-2 `
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity

aws ecr describe-images `
  --region ap-northeast-2 `
  --repository-name gitops-version-dashboard
```

## 비용 관리와 삭제

EC2, EBS 및 기타 리소스는 실행 중 비용이 발생합니다. 실습을 종료하고 리소스가 더 이상 필요하지 않으면 Terraform으로 제거합니다.

```powershell
cd terraform
terraform plan -destroy
terraform destroy
```

ECR Repository에는 `force_delete = true`가 설정되어 있으므로 이미지가 남아 있어도 Terraform Destroy 시 함께 삭제됩니다. 삭제 전 필요한 이미지와 Terraform State를 별도로 보관해야 합니다.

## 현재 범위와 개선 방향

- 현재는 Master 1대, Worker 1대 구조이므로 고가용성 구성이 아닙니다.
- Terraform State는 로컬에서 관리합니다. 협업 환경에서는 S3 Backend와 State Lock 구성이 필요합니다.
- 실습용 Public Subnet 단일 구조입니다. 운영 환경에서는 Public/Private Subnet 분리와 NAT 또는 VPC Endpoint를 고려해야 합니다.
- 애플리케이션 NodePort `30080`의 공개 규칙은 Istio Gateway 검증 후 제거하는 것이 좋습니다.
- 상시 외부 서비스가 필요하면 NodePort 직접 공개 대신 Load Balancer, 도메인 및 HTTPS를 구성하는 것이 적절합니다.
- Argo CD 관리자 UI는 공개하지 않고 SSM 또는 사설 네트워크로만 접근하는 방식을 권장합니다.
