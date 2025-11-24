#!/usr/bin/env bash
set -euo pipefail

# Run multiple chaos scenarios sequentially and collect logs/reports under ARTIFACTS_DIR.

SCENARIOS=("$@")
if [[ ${#SCENARIOS[@]} -eq 0 ]]; then
  SCENARIOS=(chaos_kill_one chaos_slow_one chaos_kill_all chaos_reset_net chaos_restore)
fi

TS="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${ARTIFACTS_DIR:-artifacts/${TS}}"
mkdir -p "${OUT_DIR}"

echo "[INFO] Running scenarios: ${SCENARIOS[*]}"
echo "[INFO] Artifacts will be stored in: ${OUT_DIR}"

for scenario in "${SCENARIOS[@]}"; do
  echo "[INFO] >>> Scenario: ${scenario}"
  ARTIFACTS_DIR="${OUT_DIR}" tools/run_chaos.sh "${scenario}" || true
done

echo "[DONE] All scenarios completed. Artifacts at: ${OUT_DIR}"
