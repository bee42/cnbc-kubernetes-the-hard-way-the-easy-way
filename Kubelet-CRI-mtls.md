# Kubelet with CRI used mtls


## 🛠 Scenario Setup

- Container Runtime: containerd
- Kubelet: manually started for testing
- Network: containerd exposes TCP socket with TLS
ä Goal: kubelet talks securely over TLS to containerd

## 🧩 Step 1: Prepare TLS Certificates

We need:

- a CA cert (self-signed)
- a server cert for containerd
- a client cert for kubelet

We'll generate these manually using openssl:

```shell
mkdir -p ~/cri-tls && cd ~/cri-tls

# 1. Generate a CA
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -subj "/CN=cri-ca" -days 10000 -out ca.crt

# 2. Server cert for containerd
openssl genrsa -out server.key 2048
openssl req -new -key server.key -subj "/CN=127.0.0.1" -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 10000

# 3. Client cert for kubelet
openssl genrsa -out client.key 2048
openssl req -new -key client.key -subj "/CN=kubelet-client" -out client.csr
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 10000
```

You should now have:

```text
ca.crt
server.crt
server.key
client.crt
client.key
```

## 🧩 Step 2: Configure containerd to listen over TLS TCP

Edit containerd's config (/etc/containerd/config.toml) and set:

```yaml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[grpc]
  address = "tcp://127.0.0.1:10010"
  tls_cert_file = "/path/to/server.crt"
  tls_key_file = "/path/to/server.key"
```

### 👉 Important: Make sure containerd is restarted properly:

```shell
sudo systemctl restart containerd
```

## 🧩 Step 3: Configure kubelet to connect using TLS

When you manually start kubelet, provide these flags:

- https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/
  - tls parameter are used from kubelet server tls handling???

```shell
sudo kubelet \
  --container-runtime=remote \
  --container-runtime-endpoint=grpc://127.0.0.1:10010 \
  --image-service-endpoint=grpc://127.0.0.1:10010 \
  --tls-cert-file=/path/to/client.crt \
  --tls-private-key-file=/path/to/client.key \
  --tls-ca-file=/path/to/ca.crt \
  --v=4
```

- `--container-runtime-endpoint` = points kubelet to the TCP address of containerd
- TLS flags tell kubelet to use its cert to connect securely

## 🧩 Step 4: Test the connection

How to validate it's really working?

### ✅ Option 1: Check containerd logs

Run:

```shell
sudo journalctl -u containerd -f
```

You should see successful incoming TLS connections from the kubelet.

### ✅ Option 2: Try crictl info over TLS

You can also configure crictl to talk over the same secure endpoint:

Edit (or create) a ~/.crictl.yaml:

```yaml
runtime-endpoint: "tcp://127.0.0.1:10010"
image-endpoint: "tcp://127.0.0.1:10010"
client-cert: "/path/to/client.crt"
client-key: "/path/to/client.key"
client-ca: "/path/to/ca.crt"
````

Then run:

```shell
crictl info
```

If everything is good, it will return runtime info over TLS!

### ✅ Option 3: OpenSSL client test

You can also "prove" the TLS is active by doing:

```shell
openssl s_client -connect 127.0.0.1:10010 -CAfile ca.crt
```

You should see the server cert (containerd's cert) and no TLS errors.

## 🧠 Quick Notes

- Normally, kubelet talks to containerd over Unix sockets, not TCP.
- TLS on TCP is only needed for network-separated deployments, or advanced secured setups.
- Containerd natively supports both TCP and Unix sockets with gRPC.
- Using client certificates strengthens mutual TLS authentication.

## 🎯 Bonus: Super Quick Diagram

```text
[kubelet] ----(grpc + mTLS)----> [containerd]
    |                              |
(client.crt)                  (server.crt)
```