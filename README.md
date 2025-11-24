# gRPC + NGINX Gateway Lab (Terraform + Ansible + Chaos Engineering)

Production-style lab for **gRPC over HTTP/2** with **NGINX/1.26.3**, **Terraform (Proxmox)**, and **Ansible**. It stands up three LXC containers, deploys Python gRPC backends with reflection, configures NGINX as an HTTP/2 gateway (plaintext + TLS), and includes chaos scenarios plus log analysis tools.

## 🧱 Architecture

```
          +----------------------+
          |   client / grpcurl   |
          +----------+-----------+
                     |
        HTTP/2 :8080 | HTTPS :443 (h2)
                     |
            +--------v---------+
            |  nginx-gateway   |  nginx/1.26.3
            +----+--------+----+
                 |        |
        grpc://:50051 grpc://:50051
          (Greeter)   (Greeter)
         +---v---+     +---v---+
         |app #1 |     |app #2 |
         +-------+     +-------+
```

## ✅ Compatibility & conventions

- Proxmox VE 9.x with bpg/proxmox provider `~> 0.87.0` (LXC via `proxmox_virtual_environment_container`).
- NGINX 1.26.3: uses `listen 8080; http2 on;` and `listen 443 ssl http2;`; no deprecated directives like `http2_idle_timeout` or nonexistent vars like `$grpc_status`.
- Upstream name: `grpc_backend_hello`; service: `helloworld.Greeter`; app names: `grpc-app-1` / `grpc-app-2` (inventory-driven).

## 📋 Requirements

- Terraform >= 1.3
- Access to Proxmox VE 9.x API with a token
- Ansible (community.crypto collection for TLS generation)
- `grpcurl` for testing
- Python 3 for the log analysis tool

## 🌱 Provision with Terraform

1) Copy and edit variables:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Update Proxmox API URL/token, storage, network, and SSH public key path
```

Example snippet:

```hcl
pm_api_url          = "https://pve:8006/"
pm_api_token_id     = "terraform@pve!token-name"
pm_api_token_secret = "CHANGE_ME"
pm_node             = "pve"
lxc_ostemplate      = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
lxc_storage         = "local-lvm"
lxc_bridge          = "vmbr0"
lxc_gateway         = "192.168.100.1"
lxc_network_cidr    = "/24"
nginx_ip            = "192.168.100.10"
grpc_app_1_ip       = "192.168.100.11"
grpc_app_2_ip       = "192.168.100.12"
ssh_public_key_file = "~/.ssh/id_ed25519.pub"
```

2) Deploy LXCs (unprivileged=true, 1 vCPU, 1GB RAM, injected SSH key):

```bash
cd terraform
terraform init
terraform apply
```

Outputs: IPs for `nginx-gateway`, `grpc-app-1`, `grpc-app-2`.

## ⚙️ Configure with Ansible

Inventory is under `ansible/inventory/hosts.yml` with `grpc_app_name` per host. Run from repo root (ansible.cfg included):

```bash
ansible-playbook ansible/site.yml
```

What it does:
- `grpc_app` role: installs Python3, creates `/opt/grpc_app/.venv`, installs `grpcio`, `grpcio-tools`, `grpcio-reflection`, generates `helloworld_pb2.py`/`helloworld_pb2_grpc.py`, deploys `server.py`, exposes gRPC health service, downloads `grpc_health_probe`, and manages `grpc_app.service` (`--app-name` from inventory, `--port 50051`).
- `nginx_gateway` role: installs nginx, applies tuning (`grpc_combined` log format with `request_id`), builds upstream `grpc_backend_hello` from `grpc_apps`, serves HTTP/2 on `:8080` and TLS on `:443`, sets `X-Request-ID` to backends, and generates a self-signed cert with `community.crypto.openssl_*`.

## 🔬 Test with grpcurl

Plaintext HTTP/2:

```bash
grpcurl -plaintext <nginx_ip>:8080 helloworld.Greeter/SayHello
grpcurl -plaintext -d '{"name":"SRE"}' <nginx_ip>:8080 helloworld.Greeter/SayHello
grpcurl -plaintext -d '{"service":""}' <nginx_ip>:8080 grpc.health.v1.Health/Check
```

TLS (self-signed):

```bash
# easiest: skip verification
grpcurl -insecure <nginx_ip>:443 helloworld.Greeter/SayHello

# or trust the generated cert
scp root@<nginx_ip>:/etc/nginx/ssl/nginx-gateway.crt /tmp/nginx-gateway.crt
grpcurl -cacert /tmp/nginx-gateway.crt <nginx_ip>:443 helloworld.Greeter/SayHello
```

Smoke script (runs health + SayHello over plaintext and TLS if CA is present):

```bash
NGINX_HOST=<nginx_ip> tools/smoke.sh
# Optional: NAME=YourName NGINX_CA_CERT=/tmp/nginx-gateway.crt tools/smoke.sh
```

## 🧨 Chaos experiments

Playbook: `ansible/chaos.yml` (targets `grpc_apps`). Examples:

- Stop only the first backend:  
  `ansible-playbook ansible/chaos.yml --tags chaos_kill_one`
- Stop all backends:  
  `ansible-playbook ansible/chaos.yml --tags chaos_kill_all`
- Add latency (300ms ±50ms normal) to first backend:  
  `ansible-playbook ansible/chaos.yml --tags chaos_slow_one`
- Reset netem and restore services:  
  `ansible-playbook ansible/chaos.yml --tags "chaos_reset_net,chaos_restore"`

Wrapper script for repeatable chaos runs (baseline + chaos + analysis):

```bash
# SCENARIO: chaos_kill_one | chaos_kill_all | chaos_slow_one | chaos_reset_net | chaos_restore
GATEWAY_HOST=<nginx_ip> CA_CERT=/tmp/nginx-gateway.crt SSH_KEY=~/.ssh/id_ed25519 tools/run_chaos.sh chaos_kill_one
```

The script will:
- Run smoke tests (health + SayHello plaintext/TLS) before and after the chaos tag.
- Trigger the chaos tag via `ansible/chaos.yml`.
- Copy `/var/log/nginx/grpc_access.log` to `/tmp` and run `tools/analyze_nginx_logs.py` to produce a quick report.

Notes:
- The TLS test prefers CA verification; if it fails, it will retry with `-insecure`.
- Health checks go through the gateway at `/grpc.health.v1.Health/`; ensure the `grpc_app` role has run so the health service is available.

Batch chaos runs + artifacts:

```bash
# Runs a set of scenarios and stores logs/reports under artifacts/<timestamp>
SSH_KEY=~/.ssh/id_ed25519 GATEWAY_HOST=<nginx_ip> CA_CERT=/tmp/nginx-gateway.crt tools/run_all_chaos.sh
# Or choose scenarios explicitly:
ARTIFACTS_DIR=artifacts/demo_run SSH_KEY=~/.ssh/id_ed25519 GATEWAY_HOST=<nginx_ip> CA_CERT=/tmp/nginx-gateway.crt tools/run_all_chaos.sh chaos_kill_one chaos_slow_one
```

Artifacts include concatenated NGINX access logs and `chaos_report_<scenario>.txt` outputs for easy documentation.

Example report excerpt:

```
=== chaos_kill_one ===
Total requests : 42
Errors (status>=500): 6 (14.29 %)
rt avg : 0.0185 s
rt p50 / p90 / p99 : 0.0121 / 0.0283 / 0.0417 s
```
Use `.gitignore` (already present) to keep real artifacts out of the repo; generate fresh ones when needed.
## 📈 Analyze NGINX logs

`tools/analyze_nginx_logs.py` parses the `grpc_combined` format and reports totals, error rate, avg, and p50/p90/p99 of `rt`:

```bash
scp root@<nginx_ip>:/var/log/nginx/grpc_access.log /tmp/grpc_access.log
./tools/analyze_nginx_logs.py /tmp/grpc_access.log --label baseline
```

Output example:

```
=== baseline ===
Total requests : 50
Errors (status>=500): 0 (0.00 %)
rt avg : 0.0123 s
rt p50 / p90 / p99 : 0.0110 / 0.0170 / 0.0250 s
```

---

All NGINX config is compatible with `nginx/1.26.3` and avoids obsolete directives. The upstream name is `grpc_backend_hello`; service is `helloworld.Greeter`. Use this lab to practice deploy/debug/chaos workflows end to end.
