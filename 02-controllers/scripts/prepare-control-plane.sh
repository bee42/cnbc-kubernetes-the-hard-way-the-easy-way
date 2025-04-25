#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ ! -x $(command -v kube-apiserver) || ! -x $(command -v kube-controller-manager) || ! -x $(command -v kube-scheduler) || ! -x $(command -v kubectl) || ! -x $(command -v proxy-server)]]; then
  echo 'kubernetes binaries are not available in PATH, I will download them and place them in /usr/local/bin'
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl proxy-server
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl proxy-server /usr/local/bin/
fi

if [[ ! -d /etc/kubernetes || ! -f /etc/kubernetes/kubernetes-ca.pem || ! -f /etc/kubernetes/kubernetes-ca-key.pem || ! -f /etc/kubernetes/kubernetes-key.pem || ! -f /etc/kubernetes/kubernetes.pem || ! -f /etc/kubernetes/service-account-key.pem || ! -f /etc/kubernetes/service-account.pem || ! -f /etc/kubernetes/encryption-config.yaml ]]; then
  echo 'kubernetes certificates and/or encryption config are not where they should, I will now move them where they should be'
  sudo mkdir -p /etc/kubernetes/ /var/lib/kubernetes/konnectivity-server/

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
    /etc/kubernetes/
fi
