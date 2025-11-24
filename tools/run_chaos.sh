#!/usr/bin/env bash
set -euo pipefail

# Simple chaos runner:
# 1) Run smoke test (baseline)
# 2) Trigger chaos scenario via Ansible tags
# 3) Run smoke test again
# 4) Copy NGINX access log and analyze it

SCENARIO="${1:-}"

if [[ -z "${SCENARIO}" ]]; then
  echo "Usage: $0 <chaos_kill_one|chaos_kill_all|chaos_slow_one|chaos_reset_net|chaos_restore>"
  exit 1
fi

INVENTORY="${INVENTORY:-ansible/inventory/hosts.yml}"
CHAOS_PLAYBOOK="${CHAOS_PLAYBOOK:-ansible/chaos.yml}"
GATEWAY_HOST="${GATEWAY_HOST:-192.168.50.100}"
CA_CERT="${CA_CERT:-/tmp/nginx-gateway.crt}"
NAME="${NAME:-Chaos}"
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519}"
OUT_BASE="${ARTIFACTS_DIR:-/tmp}"

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

TS="$(timestamp)"
LOG_COPY="${OUT_BASE}/grpc_access_${SCENARIO}_${TS}.log"
REPORT="${OUT_BASE}/chaos_report_${SCENARIO}_${TS}.txt"

mkdir -p "${OUT_BASE}"

echo "[INFO] Running baseline smoke test"
NGINX_HOST="${GATEWAY_HOST}" NGINX_CA_CERT="${CA_CERT}" NAME="${NAME}-pre" SSH_KEY="${SSH_KEY}" tools/smoke.sh || true

echo "[INFO] Triggering chaos scenario: ${SCENARIO}"
ansible-playbook -i "${INVENTORY}" "${CHAOS_PLAYBOOK}" --tags "${SCENARIO}"

echo "[INFO] Running post-chaos smoke test"
NGINX_HOST="${GATEWAY_HOST}" NGINX_CA_CERT="${CA_CERT}" NAME="${NAME}-post" SSH_KEY="${SSH_KEY}" tools/smoke.sh || true

echo "[INFO] Copying NGINX access log to ${LOG_COPY}"
TMP_DIR="$(mktemp -d)"
scp -i "${SSH_KEY}" -q "root@${GATEWAY_HOST}:/var/log/nginx/grpc_hello_access.log" "${TMP_DIR}/grpc_hello_access.log" || true
scp -i "${SSH_KEY}" -q "root@${GATEWAY_HOST}:/var/log/nginx/grpc_hello_tls_access.log" "${TMP_DIR}/grpc_hello_tls_access.log" || true
cat "${TMP_DIR}"/grpc_hello_*access.log 2>/dev/null > "${LOG_COPY}" || true
rm -rf "${TMP_DIR}"

echo "[INFO] Analyzing log -> ${REPORT}"
tools/analyze_nginx_logs.py "${LOG_COPY}" --label "${SCENARIO}" | tee "${REPORT}"

echo "[DONE] Chaos scenario '${SCENARIO}' complete."
echo "Logs: ${LOG_COPY}"
echo "Report: ${REPORT}"
