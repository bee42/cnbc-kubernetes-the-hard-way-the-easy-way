#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

VALID_IN_YEARS="${1:-1}"
#DAYS_IN_YEAR='365'
#HOURS_IN_DAY='24'
HOURS_IN_YEAR='8760'

# shellcheck disable=SC2219
let "VALID_IN_HOURS = ${VALID_IN_YEARS} * ${HOURS_IN_YEAR}"

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "${VALID_IN_HOURS}h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "${VALID_IN_HOURS}h"
      }
    }
  }
}
EOF

cat >client-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "${VALID_IN_HOURS}h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["client auth"],
        "expiry": "${VALID_IN_HOURS}h"
      }
    }
  }
}
EOF

cat >client-server-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "${VALID_IN_HOURS}h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["server auth", "client auth"],
        "expiry": "${VALID_IN_HOURS}h"
      }
    }
  }
}
EOF

COUNTRY="${2:-DE}"
CITY="${3:-Bochum}"
STATE="${4:-NRW}"

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${COUNTRY}",
      "L": "${CITY}",
      "O": "bee42 solutions gmbh",
      "OU": "CNBC",
      "ST": "${STATE}"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
