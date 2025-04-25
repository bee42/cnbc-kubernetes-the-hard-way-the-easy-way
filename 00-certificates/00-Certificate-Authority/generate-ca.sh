#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"
CLUSTER_DOAMIN="${4:-cluster.local}"

VALID_IN_YEARS="${5:-1}"
#DAYS_IN_YEAR='365'
#HOURS_IN_DAY='24'
HOURS_IN_YEAR='8760'

# shellcheck disable=SC2219
let "VALID_IN_HOURS = ${VALID_IN_YEARS} * ${HOURS_IN_YEAR}"
let "CA_EXPIRY_IN_HOURS = ${VALID_IN_HOURS} * 3"

echo 'Create the root CA'

cat << EOF > root-ca-config.json
{
  "signing": {
    "profiles": {
      "intermediate": {
        "usages": [
          "signature",
          "digital-signature",
          "cert sign",
          "crl sign"
        ],
        "expiry": "${CA_EXPIRY_IN_HOURS}h",
        "ca_constraint": {
          "is_ca": true,
          "max_path_len": 0,
          "max_path_len_zero": true
        }
      }
    }
  }
}
EOF

cat << EOF > root-ca-csr.json
{
  "CN": "cnbc-root-ca",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "ca": {
    "expiry": "${VALID_IN_HOURS}h"
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

cfssl genkey -initca root-ca-csr.json | cfssljson -bare ca
cfssl print-defaults config root-ca-config.json

echo 'Create the Kubernetes Intermediate CA'

cat << EOF > kubernetes-ca-config.json
{
    "signing": {
        "profiles": {
            "www": {
                "expiry": "${VALID_IN_HOURS}h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "${VALID_IN_HOURS}h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            },
            "worker": {
                "expiry": "${VALID_IN_HOURS}h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
        }
    }
}
EOF

cat << EOF > kubernetes-ca-csr.json
{
    "CN": "kubernetes-ca",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "ca": {
        "expiry": "${VALID_IN_HOURS}h"
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

cfssl genkey -initca kubernetes-ca-csr.json | cfssljson -bare kubernetes-ca
cfssl sign -ca ca.pem -ca-key ca-key.pem -config root-ca-config.json -profile intermediate kubernetes-ca.csr | cfssljson -bare kubernetes-ca
cfssl print-defaults config kubernetes-ca-config.json

echo 'Create the Kubernetes Front Proxy Intermediate CA'

cat << EOF > kubernetes-front-proxy-ca-csr.json
{
    "CN": "kubernetes-front-proxy-ca",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "ca": {
        "expiry": "${VALID_IN_HOURS}h"
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

cfssl genkey -initca kubernetes-front-proxy-ca-csr.json | cfssljson -bare kubernetes-front-proxy-ca
cfssl sign -ca ca.pem -ca-key ca-key.pem -config root-ca-config.json -profile intermediate kubernetes-front-proxy-ca.csr | cfssljson -bare kubernetes-front-proxy-ca
cfssl print-defaults config >kubernetes-front-proxy-ca-config.json

echo 'Create the etcd Intermediate CA'

mkdir -p etcd-ca
cd etcd-ca

cat << EOF > etcd-ca-config.json
{
    "signing": {
        "profiles": {
            "server": {
                "expiry": "${VALID_IN_HOURS}h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "${VALID_IN_HOURS}h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            },
            "peer": {
                "expiry": "${VALID_IN_HOURS}h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
        }
    }
}
EOF

cat << EOF > etcd-ca-csr.json
{
    "CN": "etcd-ca",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "ca": {
        "expiry": "${CA_EXPIRY_IN_HOURS}h"
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

cfssl genkey -initca etcd-ca-csr.json | cfssljson -bare etcd-ca
cfssl sign -ca ../ca.pem -ca-key ../ca-key.pem -config ../root-ca-config.json -profile intermediate etcd-ca.csr | cfssljson -bare etcd-ca
cfssl print-defaults config etcd-ca-config.json

echo 'Create the kubelet Intermediate CA'

mkdir -p kubelet-ca
cd kubelet-ca

cat << EOF > kubelet-ca-config.json
{
    "signing": {
        "profiles": {
            "server": {
                "expiry": "${VALID_IN_HOURS}h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "${VALID_IN_HOURS}h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            }
        }
    }
}
EOF

cat << EOF > kubelet-ca-csr.json
{
    "CN": "kubelet-ca",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "ca": {
        "expiry": "${CA_EXPIRY_IN_HOURS}h"
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

cfssl genkey -initca kubelet-ca-csr.json | cfssljson -bare kubelet-ca
cfssl sign -ca ../ca.pem -ca-key ../ca-key.pem -config ../root-ca-config.json -profile intermediate kubelet-ca.csr | cfssljson -bare kubelet-ca
cfssl print-defaults config kubelet-ca-config.json

cd ..

