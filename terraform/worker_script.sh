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
cat <<EOT | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOT

cat <<EOT | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOT
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
cat <<EOT | tee /etc/systemd/system/kubelet.service
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
EOT

mkdir -p /etc/systemd/system/kubelet.service.d
cat <<EOT | tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
[Service]
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/local/bin/kubelet $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
EOT

systemctl daemon-reload
systemctl enable --now kubelet
echo "================ K8S WORKER SETUP READY FOR JOIN ================"
