#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo 'Adding cilium, metrics-server and coredns helm repos'

helm repo add coredns https://coredns.github.io/helm
helm repo add cilium https://helm.cilium.io/
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

echo 'Updating helm repos'

helm repo update

echo 'Installing coredns'

if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
  declare -a MINIONS=( $(multipass list | grep 'worker' | awk '{ print $1 }' ) )
  declare -a GRUS=( $(multipass list | grep 'controller' | awk '{ print $1 }' ) )
else
  declare -a MINIONS=( 'node-03' 'node-04' )
  declare -a GRUS=( 'node-02' )
fi

for instance in "${GRUS[@]}" "${MINIONS[@]}"; do
  if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
    IP="$(multipass info "${instance}" | grep 'IPv4' | awk '{ print $2 }')"
  else
    IP=$(ssh "${instance}" "hostname -I | awk '{print \$1}'")
  fi
  echo "${IP} ${instance}"  >> NodeHosts
done

kubectl create secret generic node-hosts \
  --from-file=NodeHosts \
  --namespace kube-system
rm NodeHosts

helm upgrade --install coredns coredns/coredns --version "${COREDNS_CHART_VERSION}" \
    --namespace kube-system \
    --set "service.clusterIP=${DNS_CLUSTER_IP}"
    --values coredns-values.yaml

echo '\nInstalling cilium'

if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
  _IP_ADDRESS="$(multipass list | grep 'controller' | awk '{ print $1 }' | xargs multipass info | grep 'IPv4' | awk '{ print $2 }')"
  if [ "$_IP_ADDRESS" == "--" ]; then
    export KUBERNETES_VIRTUAL_IP_ADDRESS="192.168.64.3"
  else
    export KUBERNETES_VIRTUAL_IP_ADDRESS="$_IP_ADDRESS"
  fi
else
  export KUBERNETES_VIRTUAL_IP_ADDRESS==$(ssh "node-02" "hostname -I | awk '{print \$1}'")
fi

# 
helm upgrade --install cilium cilium/cilium --version "${CILIUM_CHART_VERSION}" \
    --namespace kube-system \
    --set k8sServiceHost="${KUBERNETES_VIRTUAL_IP_ADDRESS}" \
    --set k8sServicePort=6443 \
    --set ipv4NativeRoutingCIDR="${CLUSTER_CIDR}" \
    --values cilium-values.yaml

sleep 5

echo 'Installing cilium loadbalancer ipam'

cat >cilium-ipam.yaml <<EOF
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "pool-blue"
spec:
  blocks:
  - cidr: "$(echo "${KUBERNETES_VIRTUAL_IP_ADDRESS}" | awk -F "." '{ printf "%s.%s.%s.128/28", $1,$2,$3 }')"
EOF

kubectl apply -f cilium-ipam.yaml

cat >cilium-l2-policy.yaml <<EOF
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: policy
spec:
#  serviceSelector:
#    matchLabels:
#      pool: blue
#  nodeSelector:
#    matchExpressions:
#      - key: node-role.kubernetes.io/control-plane
#        operator: DoesNotExist
  interfaces:
  - ^ens[0-9]+
  - ^enp[0-9]+s0
  externalIPs: true
  loadBalancerIPs: true
EOF

kubectl apply -f cilium-l2-policy.yaml

echo 'Installing konnectivity agent'

kubectl apply -f konnectivity/konnectivity-agent-sa.yaml
kubectl apply -f konnectivity/konnectivity-server-rolebinding.yaml
# relace KUBERNETES_VIRTUAL_IP_ADDRESS with the IP address of the controller node
envsubst konnectivity/konnectivity-agent-ds.yaml | kubectl apply -f -

echo 'Installing metrics-server'

# check!
kubectl -n kube-system create secret generic metrics-proxy \
  --from-file=ca.crt=../00-certificates/00-Certificate-Authority/kubernetes-front-proxy-ca.pem \
  --from-file=tls.crt=../00-certificates/08-front-proxy-client/front-proxy-client.pem \
  --from-file=tls.key=../00-certificates/08-front-proxy-client/front-proxy-client-key.pem
kubectl -n kube-system create secret generic kubelet-client \
  --from-file=ca.crt=../00-certificates/00-Certificate-Authority/kubelet-ca/kubelet-ca.pem \
  --from-file=tls.crt=../00-certificates/06-kubernetes-api/apiserver-kubelet-client.pem \
  --from-file=tls.key=../00-certificates/06-kubernetes-api/apiserver-kubelet-client-key.pem

helm upgrade --install metrics-server metrics-server/metrics-server \
    --version "${METRICS_SERVER_CHART_VERSION}" \
    --namespace kube-system \
    --values metrics-server-values.yaml

