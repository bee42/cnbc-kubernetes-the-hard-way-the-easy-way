#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: cnbc
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
