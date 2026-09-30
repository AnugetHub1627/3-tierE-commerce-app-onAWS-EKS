#teste te
provider "aws" {
  region = "ap-south-1"
}

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
# Automatically fetches the latest official Canonical Ubuntu 22.04 LTS x86_64 AMI for ap-south-1
data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==============================================================================
# 1. NETWORK TOPOLOGY (Multi-AZ VPC for EKS/Kubeadm Integration)
# ==============================================================================
resource "aws_vpc" "mtec_vpc" {
  cidr_block           = var.mtec_vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = var.mtec_vpc_name
  }
}

resource "aws_internet_gateway" "mtec_igw" {
  vpc_id = aws_vpc.mtec_vpc.id

  tags = {
    Name = var.mtec_igw_name
  }
}

resource "aws_subnet" "mtec_pub1a" {
  vpc_id                  = aws_vpc.mtec_vpc.id
  cidr_block              = var.mtec_pub1a_cidr
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = var.mtec_pub1a_name
  }
}

resource "aws_subnet" "mtec_pub1b" {
  vpc_id                  = aws_vpc.mtec_vpc.id
  cidr_block              = var.mtec_pub1b_cidr
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = var.mtec_pub1b_name
  }
}

resource "aws_subnet" "mtec_pvt1a" {
  vpc_id            = aws_vpc.mtec_vpc.id
  cidr_block        = var.mtec_pvt1a_cidr
  availability_zone = "ap-south-1a"

  tags = {
    Name = var.mtec_pvt1a_name
  }
}

resource "aws_subnet" "mtec_pvt1b" {
  vpc_id            = aws_vpc.mtec_vpc.id
  cidr_block        = var.mtec_pvt1b_cidr
  availability_zone = "ap-south-1b"

  tags = {
    Name = var.mtec_pvt1b_name
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "mtec_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.mtec_pub1a.id

  tags = {
    Name = var.mtec_nat_name
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.mtec_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mtec_igw.id
  }
}

resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.mtec_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mtec_nat.id
  }
}

resource "aws_route_table_association" "ass_pub_1a" {
  subnet_id      = aws_subnet.mtec_pub1a.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "ass_pub_1b" {
  subnet_id      = aws_subnet.mtec_pub1b.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "pvt_1a" {
  subnet_id      = aws_subnet.mtec_pvt1a.id
  route_table_id = aws_route_table.private-rt.id
}

resource "aws_route_table_association" "pvt_1b" {
  subnet_id      = aws_subnet.mtec_pvt1b.id
  route_table_id = aws_route_table.private-rt.id
}

# ==============================================================================
# 2. INTERNAL SECURITY GROUP FOR KUBEADM
# ==============================================================================
resource "aws_security_group" "k8s_sg" {
  name        = "mtec-kubeadm-cluster-sg"
  description = "Intra-cluster communications and administrative access boundaries"
  vpc_id      = aws_vpc.mtec_vpc.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true 
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# 3. AWS IAM SECURITY ROLES (CORRECTED WORKER INTEGRATION)
# ==============================================================================
resource "aws_iam_role" "k8s_role" {
  name = "mtec-k8s-token-passing-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" } # REPAIRED CRITICAL SYNTAX ERROR HERE
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.k8s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_instance_profile" "k8s_profile" {
  name = "mtec-k8s-cluster-profile"
  role = aws_iam_role.k8s_role.name
}

# ==============================================================================
# 4. K8S CONTROL PLANE / MASTER NODE (c7i-flex.large in Public Subnet)
# ==============================================================================
resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu_22_04.id     # will fetched recent version of ubuntu
  instance_type          = "c7i-flex.large"        
  subnet_id              = aws_subnet.mtec_pub1a.id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.k8s_profile.name
  key_name               = "key_mukesh"  

  tags = {
    Name = "k8s-master"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/log) 2>&1
              echo "================ STARTING K8S MASTER SETUP ================"
              # 1. Disable swap memory
              swapoff -a
              sed -i '/swap/d' /etc/fstab
              # 2. Configure Kernel Network Modules & IP Forwarding
              modprobe overlay
              modprobe br_netfilter
              cat <<EOF | tee /etc/modules-load.d/k8s.conf
              overlay
              br_netfilter
              EOF
              cat <<EOF | tee /etc/sysctl.d/k8s.conf
              net.bridge.bridge-nf-call-iptables  = 1
              net.bridge.bridge-nf-call-ip6tables = 1
              net.ipv4.ip_forward                 = 1
              EOF
              sysctl --system
              # 3. Install and configure containerd runtime natively
              apt-get update && apt-get install -y containerd
              mkdir -p /etc/containerd
              containerd config default | tee /etc/containerd/config.toml
              sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
              systemctl restart containerd
              systemctl enable containerd
              # 4. Download Official Standalone Kubernetes v1.31 Binaries
              cd ~
              wget -O kubectl https://k8s.io
              wget -O kubeadm https://k8s.io
              wget -O kubelet https://k8s.io
              chmod +x kubectl kubeadm kubelet
              mv kubectl kubeadm kubelet /usr/local/bin/
              # 5. Create the systemd Service Profiles for kubelet
              cat <<EOF | tee /etc/systemd/system/kubelet.service
              [Unit]
              Description=kubelet: The Kubernetes Node Agent
              Documentation=https://kubernetes.io
              Wants=network-online.target
              After=network-online.target
              [Service]
              ExecStart=/usr/local/bin/kubelet
              Restart=always
              StartLimitInterval=0
              RestartSec=10
              [Install]
              WantedBy=multi-user.target
              EOF
              mkdir -p /etc/systemd/system/kubelet.service.d
              cat <<EOF | tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
              [Service]
              EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
              EnvironmentFile=-/etc/default/kubelet
              ExecStart=
              ExecStart=/usr/local/bin/kubelet \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS
              EOF
              systemctl daemon-reload
              systemctl enable --now kubelet
              # 6. Initialize Master Node Control Plane
              kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/containerd/containerd.sock
              # 7. Configure Admin access keys for kubectl
              # For root user
              mkdir -p $HOME/.kube
              cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
              chown $(id -u):$(id -g) $HOME/.kube/config
              # For default ubuntu user
              mkdir -p /home/ubuntu/.kube
              cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
              chown -R ubuntu:ubuntu /home/ubuntu/.kube
              echo "================ K8S MASTER SETUP COMPLETE ================"
              EOF
}

# ==============================================================================
# 5. K8S WORKER NODES (RESTORED MISSING CODE ENGINE HOOK)
# ==============================================================================
resource "aws_instance" "workers" {
  count                  = 3
  ami                    = data.aws_ami.ubuntu_22_04.id
  instance_type          = "t3.small"              
  subnet_id              = count.index % 2 == 0 ? aws_subnet.mtec_pvt1a.id : aws_subnet.mtec_pvt1b.id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.k8s_profile.name
  key_name               = "key_mukesh"

  tags = {
    Name = "k8s-worker-${count.index + 1}"
  }

  depends_on = [aws_instance.master]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/log) 2>&1
              echo "================ STARTING K8S WORKER SETUP ================"
              # 1. Disable swap memory
              swapoff -a
              sed -i '/swap/d' /etc/fstab
              # 2. Configure Kernel Network Modules & IP Forwarding
              modprobe overlay
              modprobe br_netfilter
              cat <<EOF | tee /etc/modules-load.d/k8s.conf
              overlay
              br_netfilter
              EOF
              cat <<EOF | tee /etc/sysctl.d/k8s.conf
              net.bridge.bridge-nf-call-iptables  = 1
              net.bridge.bridge-nf-call-ip6tables = 1
              net.ipv4.ip_forward                 = 1
              EOF
              sysctl --system
              # 3. Install and configure containerd runtime natively
              apt-get update && apt-get install -y containerd
              mkdir -p /etc/containerd
              containerd config default | tee /etc/containerd/config.toml
              sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
              systemctl restart containerd
              systemctl enable containerd
              # 4. Download Official Standalone Kubernetes v1.31 Binaries
              cd ~
              wget -O kubectl https://k8s.io
              wget -O kubeadm https://k8s.io
              wget -O kubelet https://k8s.io
              chmod +x kubectl kubeadm kubelet
              mv kubectl kubeadm kubelet /usr/local/bin/
              # 5. Create the systemd Service Profiles for kubelet
              cat <<EOF | tee /etc/systemd/system/kubelet.service
              [Unit]
              Description=kubelet: The Kubernetes Node Agent
              Documentation=https://kubernetes.io
              Wants=network-online.target
              After=network-online.target
              [Service]
              ExecStart=/usr/local/bin/kubelet
              Restart=always
              StartLimitInterval=0
              RestartSec=10
              [Install]
              WantedBy=multi-user.target
              EOF
              mkdir -p /etc/systemd/system/kubelet.service.d
              cat <<EOF | tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
              [Service]
              EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
              EnvironmentFile=-/etc/default/kubelet
              ExecStart=
              ExecStart=/usr/local/bin/kubelet \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS
              EOF
              systemctl daemon-reload
              systemctl enable --now kubelet
              echo "================ K8S WORKER SETUP READY FOR JOIN ================"
              EOF
}
