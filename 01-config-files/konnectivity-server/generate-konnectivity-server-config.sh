#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=../../00-certificates/00-Certificate-Authority/kubernetes-ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=konnectivity-server.kubeconfig

kubectl config set-credentials system:konnectivity-server \
  --client-certificate=../../00-certificates/06-kubernetes-api/konnectivity-server.pem \
  --client-key=../../00-certificates/06-kubernetes-api/konnectivity-server-key.pem \
  --embed-certs=true \
  --kubeconfig=konnectivity-server.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:konnectivity-server \
  --kubeconfig=konnectivity-server.kubeconfig

kubectl config use-context default --kubeconfig=konnectivity-server.kubeconfig
