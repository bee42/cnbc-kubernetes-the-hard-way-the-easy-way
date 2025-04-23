#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ ! -x $(command -v kube-apiserver) || ! -x $(command -v kube-controller-manager) || ! -x $(command -v kube-scheduler) || ! -x $(command -v kubectl) ]]; then
  echo 'kubernetes binaries are not available in PATH, I will download them and place them in /usr/local/bin'
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
fi

if [[ ! -d /var/lib/kubernetes || ! -f /var/lib/kubernetes/kubernetes-ca.pem || ! -f /var/lib/kubernetes/kubernetes-ca-key.pem || ! -f /var/lib/kubernetes/kubernetes-key.pem || ! -f /var/lib/kubernetes/kubernetes.pem || ! -f /var/lib/kubernetes/service-account-key.pem || ! -f /var/lib/kubernetes/service-account.pem || ! -f /var/lib/kubernetes/encryption-config.yaml ]]; then
  echo 'kubernetes certificates and/or encryption config are not where they should, I will now move them where they should be'
  sudo mkdir -p /var/lib/kubernetes/

  sudo mv \
    kubernetes-ca.pem kubernetes-ca-key.pem \
    kubernetes.pem kubernetes-key.pem \
    kubernetes-front-proxy-ca.pem  \
    apiserver-kubelet-client.pem apiserver-kubelet-client-key.pem \
    service-account.pem service-account-key.pem \
    apiserver-etcd-client.pem apiserver-etcd-client-key.pem \
    front-proxy-client.pem front-proxy-client-key.pem \
    etcd-ca.pem etcd-ca-key.pem \
    etcd-server.pem etcd-server-key.pem \
    etcd-peer.pem etcd-peer-key.pem \
    etcd-healthcheck-client.pem etcd-healthcheck-client-key.pem \
    encryption-config.yaml \
    /var/lib/kubernetes/
fi
