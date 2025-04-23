#!/bin/bash
for i in $(multipass list --format json | jq -r '(.list[] | select(.name | contains("cnbc-k8s"))) | .name '); do
  multipass delete "${i}"
done
