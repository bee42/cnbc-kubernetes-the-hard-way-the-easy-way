#!/usr/bin/env bash
source ./check_deps.sh

msg_info 'Setting up kubectl to use your newly created cluster'

cd 04-kubectl/ || exit
bash generate-kubectl-config.sh
kubectl get componentstatuses
cd - || exit
