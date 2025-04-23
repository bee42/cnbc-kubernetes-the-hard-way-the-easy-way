#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"
CLUSTER_DOAMIN="${4:-cluster.local}"

for file in ./*/*.sh; do
  cd "$(dirname ./"${file}")" || exit
  bash "${file##*/}" $COUNTRY "$CITY" "$STATE" $CLUSTER_DOAMIN
  if [[ $? -ne 0 ]]; then
    msg_fatal "[-] Error generating certificate in ${file})"
  fi
  cd - || exit
done

for instance in $(multipass list | grep 'worker' | awk '{ print $1 }'); do
  for file in './00-Certificate-Authority/kubernetes-ca.pem' "./02-kubelet-client/${instance}-key.pem" "./02-kubelet-client/${instance}.pem"; do
    transfer_file "${file}" "${instance}"
  done
done

for instance in $(multipass list | grep 'controller' | awk '{ print $1 }'); do
  for file in './00-Certificate-Authority/kubernetes-ca.pem' './00-Certificate-Authority/kubernetes-ca-key.pem' './00-Certificate-Authority/kubernetes-front-proxy-ca.pem' './00-Certificate-Authority/kubernetes-front-proxy-ca-key.pem' './06-kubernetes-api/kubernetes-key.pem' './06-kubernetes-api/kubernetes.pem' './06-kubernetes-api/apiserver-kubelet-client.pem' './06-kubernetes-api/apiserver-kubelet-client-key.pem' './07-service-account/service-account-key.pem' './07-service-account/service-account.pem' './08-front-proxy-client/front-proxy-client-key.pem' './08-front-proxy-client/front-proxy-client.pem' ; do
    transfer_file "${file}" "${instance}"
  done
  for file in './00-Certificate-Authority/etcd-ca/etcd-ca.pem' './00-Certificate-Authority/etcd-ca/etcd-ca-key.pem' './09-etcd/etcd-server.pem' './09-etcd/etcd-server-key.pem' './09-etcd/apiserver-etcd-client.pem' './09-etcd/apiserver-etcd-client-key.pem' './09-etcd/etcd-peer.pem' './09-etcd/etcd-peer-key.pem' './09-etcd/etcd-healthcheck-client.pem' './09-etcd/etcd-healthcheck-client-key.pem'  ; do
    transfer_file "${file}" "${instance}"
  done
done
