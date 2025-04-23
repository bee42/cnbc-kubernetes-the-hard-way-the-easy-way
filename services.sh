#!/usr/bin/env bash
source ./check_default.sh

msg_info 'Setting up cilium, coredns and metrics-server'

cd 05-services/ || exit
bash configure-services.sh
cd - || exit

msg_info 'Your cluster should be ready in a couple of minutes!'
msg_info 'You can check the status running: kubectl get all --all-namespaces'
