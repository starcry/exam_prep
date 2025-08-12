#!/bin/bash
set -euo pipefail

### Variables
KUBE_VERSION=1.33.0

### Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

### Load kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

### Set sysctl params
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

### Install containerd
apt-get update
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

### Install Kubernetes components
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-1-33-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-1-33-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" \
  | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y \
  kubelet=${KUBE_VERSION}-1.1 \
  kubeadm=${KUBE_VERSION}-1.1 \
  kubectl=${KUBE_VERSION}-1.1 \
  kubernetes-cni

apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet
