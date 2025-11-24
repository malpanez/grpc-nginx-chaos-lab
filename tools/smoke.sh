#!/usr/bin/env bash
set -euo pipefail

HOST="${NGINX_HOST:-192.168.50.100}"
CERT="${NGINX_CA_CERT:-/tmp/nginx-gateway.crt}"
NAME="${NAME:-SRE}"
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTO_PATH="${PROTO_PATH:-${SCRIPT_DIR}/../proto}"
PROTO_FILE="${PROTO_FILE:-helloworld.proto}"

command -v grpcurl >/dev/null 2>&1 || { echo "grpcurl is required in PATH"; exit 1; }

echo "[INFO] Using gateway host: ${HOST}"

echo "[INFO] Syncing CA cert from gateway to ${CERT}"
if scp -i "${SSH_KEY}" -q "root@${HOST}:/etc/nginx/ssl/nginx-gateway.crt" "${CERT}"; then
  echo "[INFO] CA cert synced."
else
  echo "[WARN] Could not fetch CA cert automatically. To avoid -insecure, copy it manually:"
  echo "       scp -i ${SSH_KEY} root@${HOST}:/etc/nginx/ssl/nginx-gateway.crt ${CERT}"
fi

echo "[TEST] Health check over plaintext"
grpcurl -plaintext -import-path "${PROTO_PATH}" -proto "${PROTO_FILE}" -d '{"service":""}' "${HOST}:8080" grpc.health.v1.Health/Check || echo "[WARN] Health check failed"

echo "[TEST] SayHello over plaintext"
grpcurl -plaintext -import-path "${PROTO_PATH}" -proto "${PROTO_FILE}" -d "{\"name\":\"${NAME}\"}" "${HOST}:8080" helloworld.Greeter/SayHello

if [[ -f "${CERT}" ]]; then
  echo "[TEST] SayHello over TLS with CA trust"
  if ! grpcurl -cacert "${CERT}" -import-path "${PROTO_PATH}" -proto "${PROTO_FILE}" -d "{\"name\":\"${NAME}\"}" "${HOST}:443" helloworld.Greeter/SayHello; then
    echo "[WARN] TLS with CA failed; retrying with -insecure"
    grpcurl -insecure -import-path "${PROTO_PATH}" -proto "${PROTO_FILE}" -d "{\"name\":\"${NAME}\"}" "${HOST}:443" helloworld.Greeter/SayHello || true
  fi
else
  echo "[SKIP] TLS test skipped (CA cert not present)"
fi

echo "[DONE] Smoke tests completed."
