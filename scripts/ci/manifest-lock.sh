#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-verify}"
shift || true

MANIFEST_FILE=""
LOCK_FILE=""

fail() {
  echo "MANIFEST_LOCK=fail reason=$1"
  exit 1
}

hash_manifest() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${MANIFEST_FILE}" | awk '{print $1}'
  else
    shasum -a 256 "${MANIFEST_FILE}" | awk '{print $1}'
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --manifest)
      MANIFEST_FILE="${2:-}"
      shift 2
      ;;
    --lock)
      LOCK_FILE="${2:-}"
      shift 2
      ;;
    *)
      fail "unknown_arg_${1}"
      ;;
  esac
done

[ -n "${MANIFEST_FILE}" ] || fail "missing_manifest"
[ -f "${MANIFEST_FILE}" ] || fail "manifest_not_found"

case "${MODE}" in
  generate)
    hash="$(hash_manifest)"
    printf 'manifest=%s\nsha256=%s\nalgorithm=sha256\n' "$(basename "${MANIFEST_FILE}")" "${hash}"
    ;;
  verify)
    [ -n "${LOCK_FILE}" ] || fail "missing_lock"
    [ -f "${LOCK_FILE}" ] || fail "lock_not_found"
    expected="$(grep '^sha256=' "${LOCK_FILE}" | head -n1 | cut -d= -f2-)"
    actual="$(hash_manifest)"
    [ -n "${expected}" ] || fail "lock_missing_sha256"
    [ "${expected}" = "${actual}" ] || fail "hash_mismatch"
    echo "MANIFEST_LOCK=pass manifest=$(basename "${MANIFEST_FILE}") sha256=${actual}"
    ;;
  *)
    fail "unknown_mode_${MODE}"
    ;;
esac
