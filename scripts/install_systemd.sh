#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "This installer must be run as root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${REPO_ROOT}/vpskit"
TARGET_DIR="/opt/vpskit"
SYSTEMD_DIR="/etc/systemd/system"
ENV_FILE="/etc/vpskit.env"

PYTHON_BIN="${PYTHON_BIN:-python3.11}"
if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  PYTHON_BIN="python3"
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required to install VPSKit." >&2
  exit 1
fi

install -d -m 0755 "${TARGET_DIR}"

if ! id -u vpskit >/dev/null 2>&1; then
  useradd \
    --system \
    --home-dir "${TARGET_DIR}" \
    --create-home \
    --shell /usr/sbin/nologin \
    vpskit
fi

rsync -a --delete \
  --exclude '.git' \
  --exclude '.venv' \
  --exclude '__pycache__' \
  --exclude '.pytest_cache' \
  --exclude '.mypy_cache' \
  --exclude '.ruff_cache' \
  "${SOURCE_DIR}/" "${TARGET_DIR}/"

chown -R vpskit:vpskit "${TARGET_DIR}"

if [[ ! -f "${ENV_FILE}" ]]; then
  install -m 0600 /dev/null "${ENV_FILE}"
  cat >"${ENV_FILE}" <<'EOF'
DATABASE_URL=
REDIS_URL=
PAYPAL_CLIENT_ID=
PAYPAL_CLIENT_SECRET=
PAYPAL_WEBHOOK_ID=
PAYPAL_WEBHOOK_SECRET=
PAYPAL_ENV=live
VPS_HOST=
VPS_USER=
VPS_SSH_PRIVATE_KEY=
VPSKIT_API_TOKEN=
EOF
fi

chown root:root "${ENV_FILE}"
chmod 0600 "${ENV_FILE}"

"${PYTHON_BIN}" -m venv "${TARGET_DIR}/venv"
"${TARGET_DIR}/venv/bin/python" -m pip install --upgrade pip setuptools wheel
"${TARGET_DIR}/venv/bin/pip" install "${TARGET_DIR}"

install -m 0644 "${REPO_ROOT}/systemd/vpskit-api.service" "${SYSTEMD_DIR}/vpskit-api.service"
install -m 0644 "${REPO_ROOT}/systemd/vpskit-worker.service" "${SYSTEMD_DIR}/vpskit-worker.service"

systemctl daemon-reload
systemctl enable vpskit-api
systemctl enable vpskit-worker
systemctl start vpskit-api
systemctl start vpskit-worker

echo "VPSKit systemd services installed."
echo "API logs: journalctl -u vpskit-api -f"
echo "Worker logs: journalctl -u vpskit-worker -f"
