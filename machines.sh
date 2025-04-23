#!/usr/bin/env bash
source ./check_default.sh

# To Be Determined
# - Service IP range: 10.32.0.0/24
# - Node Port range: 30000-32767

msg_info 'Creating multipass instances'

if [ "$REGISTRY_MODE" == "on" ] ; then

  msg_info 'Creating multipass instances registry'

  multipass launch --name "registry-cnbc-k8s" --cpus 1 --memory 512M --disk 20G "${UBUNTU_VERSION}"

  _IP=$(multipass exec registry-cnbc-k8s -- /bin/sh -c "ip -o -4 addr list enp0s1 | awk '{print \$4}' | cut -d/ -f1")
  if [ -n "$_IP" ] ; then
    export REGISTRY_IP=$_IP
  fi

  msg_info "Push registry setup scripts"

  cd registry/ || exit
  bash transfer-shell-scripts.sh
  cd - || exit

  msg_info "Provisioning registry-cnbc-k8s"

  multipass exec "registry-cnbc-k8s" -- bash bootstrap-workers.sh "${CONTAINERD_VERSION}" "${CNI_PLUGINS_VERSION}" "${NERDCTL_VERSION}"

fi

msg_info 'Creating multipass instances controller and worker'

for i in 'controller-cnbc-k8s' 'worker-1-cnbc-k8s' 'worker-2-cnbc-k8s' ; do
  multipass launch --name "${i}" --cpus 2 --memory 2048M --disk 20G "${UBUNTU_VERSION}"
done


