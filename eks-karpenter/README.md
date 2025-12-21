# EKS Cluster with Karpenter Autoscaling

This repository contains Terraform/Terragrunt code to deploy an Amazon EKS cluster with Karpenter for node autoscaling, supporting both x86 (AMD64) and ARM64 (Graviton) instances with Spot and On-Demand capacity.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                         VPC                                │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │  │
│  │  │  Public     │  │  Public     │  │  Public     │       │  │
│  │  │  Subnet AZ1 │  │  Subnet AZ2 │  │  Subnet AZ3 │       │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘       │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │  │
│  │  │  Private    │  │  Private    │  │  Private    │       │  │
│  │  │  Subnet AZ1 │  │  Subnet AZ2 │  │  Subnet AZ3 │       │  │
│  │  │             │  │             │  │             │       │  │
│  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │       │  │
│  │  │ │Karpenter│ │  │ │Karpenter│ │  │ │Karpenter│ │       │  │
│  │  │ │  Nodes  │ │  │ │  Nodes  │ │  │ │  Nodes  │ │       │  │
│  │  │ │(x86/ARM)│ │  │ │(x86/ARM)│ │  │ │(x86/ARM)│ │       │  │
│  │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │       │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘       │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │              EKS Control Plane                       │ │  │
│  │  │  • Kubernetes 1.32                                   │ │  │
│  │  │  • Karpenter (Fargate)                              │ │  │
│  │  │  • CoreDNS (Fargate)                                │ │  │
│  │  └─────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Features

- **EKS Cluster**: Kubernetes 1.32 with public endpoint access
- **Karpenter**: Latest v1.0.x for intelligent node autoscaling
- **Multi-Architecture Support**: Both AMD64 (x86) and ARM64 (Graviton) instances
- **Cost Optimization**: Spot instances prioritized over On-Demand
- **Fargate Profiles**: Karpenter and kube-system pods run on Fargate
- **Instance Flexibility**: Supports c, m, r, and t instance families

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.3.0
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= 0.50.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) >= 1.28
- [Helm](https://helm.sh/docs/intro/install/) >= 3.0

> **Note**: This project requires AWS Provider < 6.0.0 due to breaking changes in the EKS module.

### Installation (if not already installed)

**macOS:**
```bash
brew install terraform terragrunt awscli kubectl helm
```

**Linux:**
```bash
# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Terragrunt
wget https://github.com/gruntwork-io/terragrunt/releases/latest/download/terragrunt_linux_amd64 -O terragrunt
chmod +x terragrunt && sudo mv terragrunt /usr/local/bin/
```

**Windows (PowerShell as Administrator):**
```powershell
choco install awscli terraform terragrunt kubernetes-cli kubernetes-helm -y
```

## Quick Start

### 1. Configure AWS Credentials

```bash
aws configure
# Or use environment variables:
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

Verify your credentials:
```bash
aws sts get-caller-identity
```

### 2. Update Configuration

Edit the following files with your AWS account details:

```bash
# Update AWS Account ID and Profile
vi terragrunt-environments/production/account.hcl
```

```hcl
locals {
  account_name   = "production"
  aws_account_id = "YOUR_AWS_ACCOUNT_ID"  # Replace with your account ID
  aws_profile    = "default"               # Replace with your AWS profile
}
```

### 3. Create Terraform State Backend

```bash
# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create S3 bucket for state
aws s3 mb s3://terraform-state-${ACCOUNT_ID}-us-east-1 --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-${ACCOUNT_ID}-us-east-1 \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**Windows (PowerShell):**
```powershell
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
aws s3 mb "s3://terraform-state-$ACCOUNT_ID-us-east-1" --region us-east-1
aws s3api put-bucket-versioning --bucket "terraform-state-$ACCOUNT_ID-us-east-1" --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name terraform-locks --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region us-east-1
```

### 4. Deploy Infrastructure

```bash
# Navigate to the environment
cd terragrunt-environments/production/us-east-1/infra

# Review the plan for all modules
terragrunt run-all plan

# Deploy all modules (VPC -> EKS -> Karpenter)
terragrunt run-all apply
```

> **Note**: Deployment takes approximately 15-20 minutes. EKS cluster creation alone takes 10-15 minutes.

### 5. Configure kubectl

```bash
aws eks update-kubeconfig --name production --region us-east-1
kubectl get nodes
```

## Deploying Workloads on Specific Architectures

Karpenter automatically provisions the right nodes based on your pod requirements. Use `nodeSelector` to target specific architectures.

### Deploy on x86 (AMD64) Instances

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-x86
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-x86
  template:
    metadata:
      labels:
        app: app-x86
    spec:
      containers:
      - name: app
        image: nginx:latest
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
      nodeSelector:
        kubernetes.io/arch: amd64
```

### Deploy on ARM64 (Graviton) Instances

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-graviton
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-graviton
  template:
    metadata:
      labels:
        app: app-graviton
    spec:
      containers:
      - name: app
        image: nginx:latest  # nginx supports multi-arch
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
      nodeSelector:
        kubernetes.io/arch: arm64
```

### Deploy on Spot Instances (Cost Savings)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-spot
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app-spot
  template:
    metadata:
      labels:
        app: app-spot
    spec:
      containers:
      - name: app
        image: nginx:latest
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
      nodeSelector:
        karpenter.sh/capacity-type: spot
```

### Deploy on On-Demand Instances (For Critical Workloads)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-critical
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-critical
  template:
    metadata:
      labels:
        app: app-critical
    spec:
      containers:
      - name: app
        image: nginx:latest
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
      nodeSelector:
        karpenter.sh/capacity-type: on-demand
```

## Testing Karpenter

### Quick Test with nginx

```bash
# Deploy x86 test
kubectl apply -f examples/deployment-x86.yaml

# Deploy ARM64 test  
kubectl apply -f examples/deployment-arm64.yaml

# Watch Karpenter provision nodes
kubectl get nodes -w

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f
```

### Verify Node Architecture

```bash
# List nodes with architecture labels
kubectl get nodes -L kubernetes.io/arch,karpenter.sh/capacity-type,node.kubernetes.io/instance-type
```

## Module Structure

```
.
├── README.md
├── terraform-modules/
│   └── eks-karpenter/
│       ├── vpc/                  # VPC with public/private subnets
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── providers.tf
│       ├── eks/                  # EKS cluster with Fargate profiles
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── providers.tf
│       └── karpenter/            # Karpenter controller and NodePool
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           ├── providers.tf
│           └── data.tf
├── terragrunt-environments/
│   ├── terragrunt.hcl            # Root configuration (backend, provider)
│   └── production/
│       ├── account.hcl           # AWS account ID, profile
│       └── us-east-1/
│           ├── region.hcl        # AWS region
│           └── infra/
│               ├── env.hcl       # Environment name and tags
│               ├── vpc/
│               │   └── terragrunt.hcl
│               ├── eks/
│               │   └── terragrunt.hcl
│               └── karpenter/
│                   └── terragrunt.hcl
└── examples/                      # Example deployment manifests
    ├── deployment-x86.yaml
    ├── deployment-arm64.yaml
    ├── deployment-spot.yaml
    └── deployment-ondemand.yaml
```

## Customization

### Change Instance Types

Edit `terraform-modules/eks-karpenter/karpenter/main.tf`:

```hcl
requirements:
  - key: "karpenter.k8s.aws/instance-category"
    operator: In
    values: ["c", "m", "r"]  # Add or remove instance families
  - key: "karpenter.k8s.aws/instance-cpu"
    operator: In
    values: ["4", "8", "16", "32"]  # Adjust CPU sizes
```

### Adjust Node Limits

```hcl
limits:
  cpu: 1000      # Total vCPUs across all Karpenter nodes
  memory: 1000Gi # Total memory across all Karpenter nodes
```

### Change Region

1. Rename `terragrunt-environments/production/us-east-1` to your region
2. Update `region.hcl`:
   ```hcl
   locals {
     aws_region = "eu-west-1"  # Your region
   }
   ```
3. Update AZs in `infra/vpc/terragrunt.hcl`:
   ```hcl
   inputs = {
     azs = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
     # ...
   }
   ```

## Cleanup

```bash
# Destroy all resources
cd terragrunt-environments/production/us-east-1/infra
terragrunt run-all destroy

# Confirm destruction when prompted
```

> **Note**: Ensure all Karpenter-provisioned nodes are terminated before destroying. Delete any deployments first:
> ```bash
> kubectl delete deployments --all
> kubectl get nodes -w  # Wait for nodes to terminate
> ```

## Troubleshooting

### Windows: "Filename too long" Error

When running on Windows, you may encounter:
```
fatal: cannot write keep file ... Filename too long
```

**Solution 1: Use a short path (Recommended)**
```powershell
mkdir C:\eks
Copy-Item -Recurse "C:\path\to\eks-karpenter-terraform\*" "C:\eks\"
cd C:\eks\terragrunt-environments\production\us-east-1\infra
terragrunt run-all apply
```

**Solution 2: Enable Windows long paths**
```powershell
# Run PowerShell as Administrator
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
git config --system core.longpaths true
# Restart terminal
```

### AWS Provider Version Errors

If you see errors about `elastic_gpu_specifications` or unsupported blocks:
```
Error: Unsupported block type "elastic_gpu_specifications"
```

This means AWS Provider 6.x is installed. Clear cache and re-run:
```bash
# Clear all terragrunt cache
find . -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null
find . -name ".terraform.lock.hcl" -delete 2>/dev/null

# Re-run
terragrunt run-all apply
```

### Karpenter not provisioning nodes

```bash
# Check Karpenter controller logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# Verify NodePool and EC2NodeClass
kubectl get nodepools
kubectl get ec2nodeclasses
kubectl describe nodepool default
```

### Pods stuck in Pending

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check if resources are available
kubectl get nodeclaims
```

### Node not joining cluster

```bash
# Check EC2NodeClass status
kubectl describe ec2nodeclass default

# Verify security groups and subnets have correct tags
aws ec2 describe-security-groups --filters "Name=tag:karpenter.sh/discovery,Values=production"
aws ec2 describe-subnets --filters "Name=tag:karpenter.sh/discovery,Values=production"
```

### State Lock Issues

```bash
# If Terraform state is locked from a failed run
cd terragrunt-environments/production/us-east-1/infra/vpc  # or eks, karpenter
terragrunt force-unlock <LOCK_ID>
```

### kubectl Unauthorized Errors

```bash
# Update kubeconfig
aws eks update-kubeconfig --name production --region us-east-1

# Verify identity
aws sts get-caller-identity
```

## Cost Optimization Tips

1. **Use Spot Instances**: Default configuration prioritizes Spot over On-Demand (60-90% savings)
2. **Use Graviton**: ARM64 instances offer ~20% better price/performance
3. **Right-size Resources**: Set appropriate resource requests to optimize bin-packing
4. **Consolidation**: Karpenter automatically consolidates underutilized nodes
5. **Single NAT Gateway**: Default config uses one NAT (change to multi-AZ for production HA)

## Security Considerations

- EKS endpoint is publicly accessible (can be changed to private)
- Worker nodes are in private subnets
- Security groups restrict traffic appropriately
- IAM roles follow least-privilege principle
- Karpenter uses IRSA (IAM Roles for Service Accounts)
- Nodes expire after 30 days (`expireAfter: 720h`) for automatic patching

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT License - see LICENSE file for details