# VPSKit Phase 1 Core Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an independently runnable, non-interactive Phase 1 installer that safely preflights and hardens Ubuntu/Debian, installs Xray Reality on TCP 443, generates a local VLESS subscription, and rolls back VPSKit-owned mutations on failure.

**Architecture:** A small Bash orchestrator calls focused, sourceable modules through a shared runtime contract. Host writes are guarded by preflight, a kernel-backed installation lock, a reverse-order transaction journal, atomic file replacement, and command validation. Python is used only for deterministic subscription rendering; Bats and pytest verify behavior without mutating the development host.

**Tech Stack:** Bash 5, systemd, OpenSSH, UFW, Fail2ban, Xray-core, Python 3.11, Bats, pytest, ShellCheck, shfmt

---

## Phase Boundary / 阶段边界

Phase 1 installs only Xray Reality and produces a local VLESS URI/Base64 artifact. It must print `VPSKit PHASE 1 COMPLETE`, never the final product-wide `VPSKit INSTALL COMPLETE`. Hysteria2, Trojan, network optimization, control-plane upload, and public HTTPS subscriptions remain disabled until their later phases pass their own gates.

Phase 1 只安装 Xray Reality，并生成本地 VLESS URI/Base64 订阅。它只能输出 `VPSKit PHASE 1 COMPLETE`，禁止输出全局完成信息。

## Locked File Map / 文件职责

```text
vpskit/
├── install.sh                         # Phase 1 orchestrator only
├── config/versions.env                # Reviewed binary versions and checksums
├── core/common.sh                     # Logging, atomic writes, command helpers
├── core/install_lock.sh               # flock lifecycle
├── core/transaction.sh                # Reverse-order rollback journal
├── core/detect_os.sh                  # OS/architecture normalization
├── core/system_check.sh               # Resource, TCP 443 and SSH preflight
├── security/vpsguard.sh               # SSH, UFW and Fail2ban orchestration
├── xray/install_xray.sh               # Verified Xray install and systemd unit
├── xray/generate_config.sh            # Local Reality credentials and config
├── subscription/generate_sub.py       # Pure VLESS/Base64 renderer
├── output/.gitkeep                    # Output directory marker only
└── README.md                           # Bilingual usage and recovery guide
tests/
├── bats/helpers/test_helper.bash       # Isolated fake root and command shims
├── bats/install_lock.bats
├── bats/transaction.bats
├── bats/system_check.bats
├── bats/vpsguard.bats
├── bats/xray.bats
├── bats/install_phase1.bats
└── test_generate_sub.py
```

Generated files such as `vpskit/output/final_links.txt` are ignored by Git and created with mode `0600` at runtime.

### Task 1: Establish the Phase 1 test harness and repository contract

**Files:**
- Modify: `.gitignore`
- Create: `vpskit/output/.gitkeep`
- Create: `tests/bats/helpers/test_helper.bash`

- [ ] **Step 1: Write the isolated-host helper**

Create a Bats helper that exports a temporary `VPSKIT_ROOT`, `VPSKIT_STATE_DIR`, `VPSKIT_LOG_DIR`, and a shim directory prepended to `PATH`. Its `make_shim NAME BODY` helper must create executable commands without touching `/etc`, `/var`, systemd, UFW, or SSH on the developer machine.

```bash
setup_vpskit_test() {
  export TEST_ROOT="${BATS_TEST_TMPDIR}/root"
  export VPSKIT_ROOT="${TEST_ROOT}"
  export VPSKIT_STATE_DIR="${TEST_ROOT}/var/lib/vpskit"
  export VPSKIT_LOCK_FILE="${TEST_ROOT}/var/lib/vpskit.lock"
  export VPSKIT_LOG_DIR="${TEST_ROOT}/var/log/vpskit"
  export SHIM_DIR="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "${SHIM_DIR}" "${VPSKIT_STATE_DIR}" "${VPSKIT_LOG_DIR}"
  export PATH="${SHIM_DIR}:${PATH}"
}

make_shim() {
  local name="$1"
  local body="$2"
  printf '#!/usr/bin/env bash\n%s\n' "${body}" >"${SHIM_DIR}/${name}"
  chmod 0755 "${SHIM_DIR}/${name}"
}
```

- [ ] **Step 2: Add generated-output exclusions**

```gitignore
.worktrees/
.env
*.key
*.pem
__pycache__/
.pytest_cache/
vpskit/output/*
!vpskit/output/.gitkeep
```

- [ ] **Step 3: Verify the harness parses**

Run: `rtk bash -n tests/bats/helpers/test_helper.bash`  
Expected: exit 0.

- [ ] **Step 4: Commit the harness**

```bash
rtk git add .gitignore vpskit/output/.gitkeep tests/bats/helpers/test_helper.bash
rtk git commit -m "test: add isolated VPSKit shell harness"
```

### Task 2: Add structured logging and the installation lock

**Files:**
- Create: `tests/bats/install_lock.bats`
- Create: `vpskit/core/common.sh`
- Create: `vpskit/core/install_lock.sh`

- [ ] **Step 1: Write failing lock and log tests**

The Bats tests must prove that the first process acquires `${VPSKIT_LOCK_FILE}`, which maps to `/var/lib/vpskit.lock` in production, a concurrent process exits with code 73, a stale lock file remains reusable, and log lines contain an RFC 3339 UTC timestamp, level, phase, and bilingual message.

```bash
@test "a concurrent installer cannot acquire the lock" {
  source "${PROJECT_ROOT}/vpskit/core/common.sh"
  source "${PROJECT_ROOT}/vpskit/core/install_lock.sh"
  acquire_install_lock
  run bash -c "source '${PROJECT_ROOT}/vpskit/core/common.sh'; source '${PROJECT_ROOT}/vpskit/core/install_lock.sh'; acquire_install_lock" 
  [ "$status" -eq 73 ]
}

@test "a stale lock path is reusable when no kernel lock is held" {
  mkdir -p "$(dirname "${VPSKIT_LOCK_FILE}")"
  : >"${VPSKIT_LOCK_FILE}"
  run bash -c "source '${PROJECT_ROOT}/vpskit/core/common.sh'; source '${PROJECT_ROOT}/vpskit/core/install_lock.sh'; acquire_install_lock"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run the lock tests and verify RED**

Run: `rtk bats tests/bats/install_lock.bats`  
Expected: FAIL because the runtime modules do not exist.

- [ ] **Step 3: Implement the shared runtime contract**

`common.sh` must define immutable defaults, `root_path`, `log_event`, `die`, `require_command`, and `atomic_install`. `log_event` writes through `tee -a` to a mode-`0700` log directory and must never receive secret values.

```bash
: "${VPSKIT_ROOT:=}"
: "${VPSKIT_STATE_DIR:=${VPSKIT_ROOT}/var/lib/vpskit}"
: "${VPSKIT_LOCK_FILE:=${VPSKIT_ROOT}/var/lib/vpskit.lock}"
: "${VPSKIT_LOG_DIR:=${VPSKIT_ROOT}/var/log/vpskit}"
: "${VPSKIT_PHASE:=phase1}"

log_event() {
  local level="$1" message_en="$2" message_zh="$3"
  mkdir -p -m 0700 "${VPSKIT_LOG_DIR}"
  printf '%s level=%s phase=%s message=%q message_zh=%q\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${level}" "${VPSKIT_PHASE}" \
    "${message_en}" "${message_zh}" | tee -a "${VPSKIT_LOG_DIR}/install.log"
}
```

`install_lock.sh` must open the lock file once and hold descriptor 9 until process exit:

```bash
acquire_install_lock() {
  mkdir -p -m 0700 "${VPSKIT_STATE_DIR}"
  exec 9>"${VPSKIT_LOCK_FILE}"
  if ! flock -n 9; then
    log_event ERROR "Another VPSKit installation is running" "另一个 VPSKit 安装正在运行"
    return 73
  fi
  printf '%s\n' "$$" 1>&9
}
```

- [ ] **Step 4: Run tests and static checks**

Run: `rtk bats tests/bats/install_lock.bats && rtk shellcheck vpskit/core/common.sh vpskit/core/install_lock.sh`  
Expected: all tests pass and ShellCheck reports no findings.

- [ ] **Step 5: Commit**

```bash
rtk git add vpskit/core/common.sh vpskit/core/install_lock.sh tests/bats/install_lock.bats
rtk git commit -m "feat: add installer lock and structured logging"
```

### Task 3: Implement the reverse-order transaction journal

**Files:**
- Create: `tests/bats/transaction.bats`
- Create: `vpskit/core/transaction.sh`

- [ ] **Step 1: Write failing transaction tests**

Test that rollback actions execute in exact reverse order, arguments containing spaces are preserved without `eval`, rollback continues after one compensation fails, and a committed transaction performs no rollback.

```bash
@test "rollback executes registered commands in reverse order" {
  source "${PROJECT_ROOT}/vpskit/core/common.sh"
  source "${PROJECT_ROOT}/vpskit/core/transaction.sh"
  begin_transaction
  register_rollback record first
  register_rollback record "second value"
  rollback_transaction
  mapfile -t events <"${BATS_TEST_TMPDIR}/events"
  [ "${events[0]}" = "second value" ]
  [ "${events[1]}" = "first" ]
}
```

- [ ] **Step 2: Run and verify RED**

Run: `rtk bats tests/bats/transaction.bats`  
Expected: FAIL because `transaction.sh` does not exist.

- [ ] **Step 3: Implement array-safe rollback**

Use numbered Bash arrays rather than serialized shell text. `register_rollback` increments `ROLLBACK_COUNT`, creates `ROLLBACK_ACTION_<n>`, and fills it through a Bash nameref (`local -n action_ref="ROLLBACK_ACTION_${ROLLBACK_COUNT}"; action_ref=("$@")`). `rollback_transaction` walks the counter downward, binds the matching nameref, and invokes `"${action_ref[@]}"`. Do not use `eval`. Add `backup_file`, `restore_file`, `remove_created_file`, `begin_transaction`, `commit_transaction`, and an EXIT trap that triggers rollback only when the transaction is active.

The transaction directory is created as `"${VPSKIT_STATE_DIR}/transactions/$(date -u +%Y%m%dT%H%M%SZ)-$$"` with mode `0700`. Backups retain the original mode and ownership. Rollback writes failures to the diagnostic log and continues through the remaining actions.

- [ ] **Step 4: Verify GREEN**

Run: `rtk bats tests/bats/transaction.bats && rtk shellcheck vpskit/core/transaction.sh`  
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
rtk git add vpskit/core/transaction.sh tests/bats/transaction.bats
rtk git commit -m "feat: add reverse-order installer rollback"
```

### Task 4: Build immutable OS and system preflight

**Files:**
- Create: `tests/bats/system_check.bats`
- Create: `vpskit/core/detect_os.sh`
- Create: `vpskit/core/system_check.sh`

- [ ] **Step 1: Write failing OS normalization tests**

Cover Ubuntu/Debian acceptance, unsupported distribution rejection, `x86_64 -> amd64`, `aarch64 -> arm64`, unsupported architecture rejection, and missing systemd rejection. OS detection reads `${VPSKIT_ROOT}/etc/os-release` so tests never inspect the host.

- [ ] **Step 2: Write failing resource, port, DNS, and SSH tests**

Tests must cover:

- root and systemd required;
- at least 1 CPU, 512 MiB available memory, and 1 GiB free disk;
- TCP 443 conflict and TCP owner mismatch;
- existing TCP 443 allowed only when the listener's cgroup/service identity is `vpskit-xray.service`;
- a valid `ssh-ed25519`, RSA, or ECDSA public key must exist in an effective authorized-keys file;
- current SSH port is derived from `sshd -T`, not assumed to be 22;
- the detected SSH port is listening before changes;
- Trojan-domain and API checks are absent from Phase 1.

Port ownership logic must inspect `ss -H -ltnp 'sport = :443'` and corroborate the PID with `/proc/<pid>/cgroup`. A process name alone is insufficient.

- [ ] **Step 3: Run and verify RED**

Run: `rtk bats tests/bats/system_check.bats`  
Expected: FAIL because detection and preflight functions are missing.

- [ ] **Step 4: Implement pure detection before orchestration**

`detect_os.sh` exports only normalized `VPSKIT_OS_ID`, `VPSKIT_OS_VERSION`, `VPSKIT_ARCH`, and `VPSKIT_PACKAGE_ARCH`. `system_check.sh` exposes focused functions and a `run_preflight` aggregator:

```bash
run_preflight() {
  check_root
  detect_os
  check_systemd
  check_resources
  detect_ssh_settings
  check_authorized_keys
  check_ssh_listener
  check_tcp_443
  log_event INFO "Preflight passed" "系统预检通过"
}
```

Every check returns nonzero with a non-secret bilingual error. No function in these files may call `apt`, write under `/etc`, reload services, or enable the firewall.

- [ ] **Step 5: Verify GREEN and lint**

Run: `rtk bats tests/bats/system_check.bats && rtk shellcheck vpskit/core/detect_os.sh vpskit/core/system_check.sh`  
Expected: all tests pass and ShellCheck is clean.

- [ ] **Step 6: Commit**

```bash
rtk git add vpskit/core/detect_os.sh vpskit/core/system_check.sh tests/bats/system_check.bats
rtk git commit -m "feat: add immutable VPS preflight checks"
```

### Task 5: Implement SSH-safe VPSGuard

**Files:**
- Create: `tests/bats/vpsguard.bats`
- Create: `vpskit/security/vpsguard.sh`

- [ ] **Step 1: Write failing SSH safety tests**

Test the full safety order:

1. key validation already passed;
2. existing config is backed up;
3. `/etc/ssh/sshd_config.d/60-vpskit.conf` is atomically staged;
4. `sshd -t -f` validates the complete staged configuration;
5. the service is reloaded, never restarted;
6. the original detected SSH port remains listening;
7. any failure restores the prior file and reloads the prior valid configuration.

Assert the drop-in contains exactly:

```text
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
```

- [ ] **Step 2: Write failing firewall and Fail2ban tests**

Test that UFW adds the detected SSH TCP port and TCP 443 before `ufw --force enable`, preserves unrelated rules, never calls `ufw reset`, records only newly added rules for rollback, and configures a Fail2ban `sshd` jail using the detected SSH port.

- [ ] **Step 3: Run and verify RED**

Run: `rtk bats tests/bats/vpsguard.bats`  
Expected: FAIL because `vpsguard.sh` is missing.

- [ ] **Step 4: Implement guarded SSH activation**

Expose `install_security_packages`, `secure_ssh`, `configure_ufw`, `configure_fail2ban`, and `run_vpsguard`. All generated files use temporary files in the destination directory followed by `install`/`mv` for atomic replacement. Each write registers restoration before mutation.

Use service-name detection (`ssh.service` on Debian/Ubuntu where present, otherwise `sshd.service`) and invoke `systemctl reload`. After reload, poll the detected listening socket for up to ten seconds. A failure returns nonzero and lets the global transaction restore the prior state.

- [ ] **Step 5: Verify GREEN and lint**

Run: `rtk bats tests/bats/vpsguard.bats && rtk shellcheck vpskit/security/vpsguard.sh`  
Expected: all tests pass; the command-call trace contains no SSH restart and no UFW reset.

- [ ] **Step 6: Commit**

```bash
rtk git add vpskit/security/vpsguard.sh tests/bats/vpsguard.bats
rtk git commit -m "feat: add rollback-safe VPSGuard"
```

### Task 6: Pin and install Xray as an isolated systemd service

**Files:**
- Create: `vpskit/config/versions.env`
- Create: `tests/bats/xray.bats`
- Create: `vpskit/xray/install_xray.sh`
- Create: `vpskit/xray/generate_config.sh`

- [ ] **Step 1: Record reviewed release metadata**

`versions.env` must pin the reviewed official XTLS release published on 2026-03-27:

```bash
XRAY_VERSION="v26.3.27"
XRAY_AMD64_ASSET="Xray-linux-64.zip"
XRAY_AMD64_SHA256="23cd9af937744d97776ee35ecad4972cf4b2109d1e0fe6be9930467608f7c8ae"
XRAY_ARM64_ASSET="Xray-linux-arm64-v8a.zip"
XRAY_ARM64_SHA256="4d30283ae614e3057f730f67cd088a42be6fdf91f8639d82cb69e48cde80413c"
XRAY_RELEASE_BASE_URL="https://github.com/XTLS/Xray-core/releases/download/v26.3.27"
```

These digests come from the official GitHub release asset metadata. Do not use `latest`, unverified mirrors, or a checksum fetched from the same artifact endpoint during installation.

- [ ] **Step 2: Write failing binary-install tests**

Cover architecture-specific archive selection, TLS download failure, checksum mismatch, ZIP traversal rejection, existing managed-version no-op, existing unmanaged binary preservation, isolated `vpskit-xray` system user creation, and systemd unit hardening.

The unit must include:

```ini
[Unit]
Description=VPSKit Xray Reality
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=vpskit-xray
Group=vpskit-xray
ExecStart=/usr/local/bin/xray run -config /etc/vpskit/xray/config.json
Restart=on-failure
RestartSec=3s
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/vpskit/xray
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 3: Write failing Reality-config tests**

Shim `xray uuid` and `xray x25519` with deterministic outputs. Assert:

- TCP 443 only;
- VLESS with `decryption: none` and Reality security;
- locally generated UUID, X25519 private key, public key, and 8-byte short ID;
- configurable stealth target with a conservative reviewed default;
- no private key in returned metadata or logs;
- config mode `0600`, directory mode `0750`, owner `root:vpskit-xray`;
- `xray run -test -config` succeeds before systemd activation.

- [ ] **Step 4: Run and verify RED**

Run: `rtk bats tests/bats/xray.bats`  
Expected: FAIL because Xray modules are missing.

- [ ] **Step 5: Implement verified installation and configuration**

Use `curl --fail --silent --show-error --location --proto '=https' --tlsv1.2`, compare SHA-256 with `sha256sum -c`, inspect archive paths before extraction, and install through a transaction-local staging directory. Never execute an upstream installation script.

`generate_xray_config` writes a server-only JSON file and a separate mode-`0600` metadata JSON containing only public connection fields: host IP, port, UUID, Reality public key, short ID, SNI, fingerprint, transport, and display name. The private key exists only in server config.

- [ ] **Step 6: Validate before activation**

Run config validation, `systemctl daemon-reload`, enable/start the unit, assert `systemctl is-active --quiet vpskit-xray`, and verify TCP 443 is owned by that unit via PID/cgroup. Any failure returns to the transaction trap.

- [ ] **Step 7: Verify GREEN and lint**

Run: `rtk bats tests/bats/xray.bats && rtk shellcheck vpskit/xray/install_xray.sh vpskit/xray/generate_config.sh`  
Expected: all tests pass; checksum-failure test proves the binary is not installed.

- [ ] **Step 8: Commit**

```bash
rtk git add vpskit/config/versions.env vpskit/xray/install_xray.sh vpskit/xray/generate_config.sh tests/bats/xray.bats
rtk git commit -m "feat: install verified Xray Reality service"
```

### Task 7: Build the pure Phase 1 subscription renderer

**Files:**
- Create: `tests/test_generate_sub.py`
- Create: `vpskit/subscription/generate_sub.py`

- [ ] **Step 1: Write failing renderer tests**

Define a frozen `VlessMetadata` dataclass and test strict IPv4/IPv6 hostname handling, percent encoding, stable URI query ordering, Base64 output round-trip, unknown-field rejection, missing-field rejection, and atomic mode-`0600` output.

```python
def test_vless_uri_contains_only_public_metadata(valid_metadata: dict[str, object]) -> None:
    metadata = VlessMetadata.from_mapping(valid_metadata)
    uri = render_vless_uri(metadata)
    assert uri.startswith("vless://11111111-1111-4111-8111-111111111111@")
    assert "security=reality" in uri
    assert "pbk=public-key-value" in uri
    assert "private" not in uri.lower()


def test_base64_subscription_round_trips(valid_metadata: dict[str, object]) -> None:
    uri = render_vless_uri(VlessMetadata.from_mapping(valid_metadata))
    encoded = render_base64_subscription([uri])
    assert base64.b64decode(encoded).decode() == f"{uri}\n"
```

- [ ] **Step 2: Run and verify RED**

Run: `rtk pytest tests/test_generate_sub.py -v`  
Expected: FAIL because the module is missing.

- [ ] **Step 3: Implement validation and pure rendering**

The module exposes only `VlessMetadata.from_mapping`, `render_vless_uri`, `render_base64_subscription`, and a thin CLI that reads the public metadata JSON and atomically writes `final_links.txt` plus `subscription.txt`. URI query fields are generated with `urllib.parse.urlencode`; fragments use `quote`; Base64 is standard padded Base64 for v2rayNG/Shadowrocket compatibility.

The CLI refuses metadata containing `private_key`, `tls_private_key`, `api_token`, `hmac_secret`, or unknown keys. It never imports or reads Xray server configuration.

- [ ] **Step 4: Verify GREEN**

Run: `rtk pytest tests/test_generate_sub.py -v`  
Expected: all tests pass.

- [ ] **Step 5: Run Python quality checks**

Run: `rtk ruff check vpskit/subscription/generate_sub.py tests/test_generate_sub.py && rtk mypy vpskit/subscription/generate_sub.py`  
Expected: no lint or type errors.

- [ ] **Step 6: Commit**

```bash
rtk git add vpskit/subscription/generate_sub.py tests/test_generate_sub.py
rtk git commit -m "feat: generate validated VLESS subscriptions"
```

### Task 8: Wire the fail-fast Phase 1 orchestrator

**Files:**
- Create: `tests/bats/install_phase1.bats`
- Create: `vpskit/install.sh`

- [ ] **Step 1: Write the failing happy-path orchestration test**

Shim host commands and assert this exact order:

```text
root-check
lock
preflight
transaction-begin
dependency-install
vpsguard
xray-install
xray-config-test
xray-start
ssh-listener-check
xray-listener-check
subscription-render
transaction-commit
phase1-success
```

Assert stdout contains VLESS and `VPSKit PHASE 1 COMPLETE`, but does not contain Hysteria2, Trojan, the public subscription URL, or `VPSKit INSTALL COMPLETE`.

- [ ] **Step 2: Write failing fault-injection tests**

Inject failure at preflight, SSH validation, UFW enablement, Xray checksum verification, Xray config validation, systemd activation, port ownership validation, and subscription rendering. Assert:

- preflight failure causes zero mutations and zero rollback actions;
- later failure stops immediately and rolls back in reverse order;
- SSH backup restoration is attempted before the process exits;
- logs remain under `${VPSKIT_LOG_DIR}`;
- no success heading or URI is printed;
- the lock is released on exit.

- [ ] **Step 3: Run and verify RED**

Run: `rtk bats tests/bats/install_phase1.bats`  
Expected: FAIL because `install.sh` is missing.

- [ ] **Step 4: Implement the orchestrator**

The orchestrator contains no business logic. It sources modules by its own absolute directory, verifies root, acquires the lock, runs immutable preflight, begins the transaction, installs required APT packages non-interactively, calls VPSGuard and Xray modules, renders the local subscription, performs fresh health checks, commits, then prints the bilingual Phase 1 result.

Use:

```bash
export DEBIAN_FRONTEND=noninteractive
set -Eeuo pipefail
umask 077
```

The EXIT/ERR handling must preserve the original failure code, run rollback once, log rollback status, and never expose secrets. `apt-get` receives bounded retry and lock-timeout options. Package installation happens only after all preflight checks pass.

- [ ] **Step 5: Verify GREEN**

Run: `rtk bats tests/bats/install_phase1.bats`  
Expected: all orchestration and fault-injection tests pass.

- [ ] **Step 6: Run all Phase 1 tests and static checks**

```bash
rtk pytest tests/ -v
rtk bats tests/bats/
rtk shellcheck vpskit/install.sh vpskit/core/*.sh vpskit/security/*.sh vpskit/xray/*.sh
rtk shfmt -d -i 2 -ci vpskit tests/bats
rtk ruff check vpskit/subscription tests/test_generate_sub.py
rtk mypy vpskit/subscription/generate_sub.py
```

Expected: every command exits 0 with no failures or formatting diff.

- [ ] **Step 7: Commit**

```bash
rtk git add vpskit/install.sh tests/bats/install_phase1.bats
rtk git commit -m "feat: orchestrate VPSKit Phase 1 installation"
```

### Task 9: Document deployment, recovery, and reboot qualification

**Files:**
- Create: `vpskit/README.md`
- Create: `vpskit/tools/verify_phase1.sh`
- Modify: `tests/bats/install_phase1.bats`

- [ ] **Step 1: Write a failing post-reboot verifier test**

The verifier must check the detected SSH listener, `vpskit-xray.service`, TCP 443 ownership, Xray config validation, and non-empty mode-`0600` subscription files. It returns nonzero and logs each failed check; it never modifies the host.

- [ ] **Step 2: Run and verify RED**

Run: `rtk bats tests/bats/install_phase1.bats -f "post-reboot"`  
Expected: FAIL because `verify_phase1.sh` is missing.

- [ ] **Step 3: Implement the read-only verifier**

`verify_phase1.sh` sources common detection helpers, performs only read operations plus logging, and prints `VPSKit PHASE 1 HEALTHY` only when every check succeeds. It does not reboot automatically because an installer-triggered reboot can sever the active administrative session.

- [ ] **Step 4: Write the bilingual README**

Document:

- supported Ubuntu/Debian versions and architectures;
- exact non-interactive command;
- required root/SSH-key prerequisites;
- files and services created;
- Phase 1-only output limitation;
- log, transaction, backup, and subscription locations;
- manual reboot command and exact post-reboot verification command;
- rollback behavior and recovery procedure;
- uninstall is intentionally absent from Phase 1 to prevent destructive automation;
- secrets must be supplied through `.env` only in later phases and never committed.

- [ ] **Step 5: Verify documentation commands and tests**

Run: `rtk bash -n vpskit/tools/verify_phase1.sh && rtk bats tests/bats/install_phase1.bats && rtk git diff --check`  
Expected: exit 0 with no whitespace errors.

- [ ] **Step 6: Commit**

```bash
rtk git add vpskit/README.md vpskit/tools/verify_phase1.sh tests/bats/install_phase1.bats
rtk git commit -m "docs: add Phase 1 deployment and recovery guide"
```

### Task 10: Run Phase 1 release qualification

**Files:**
- Modify only if qualification reveals a defect; follow a new RED/GREEN cycle for every correction.

- [ ] **Step 1: Run the complete local verification suite**

```bash
rtk pytest tests/ -v
rtk bats tests/bats/
rtk shellcheck vpskit/install.sh vpskit/core/*.sh vpskit/security/*.sh vpskit/xray/*.sh vpskit/tools/*.sh
rtk shfmt -d -i 2 -ci vpskit tests/bats
rtk ruff check vpskit/subscription tests/test_generate_sub.py
rtk mypy vpskit/subscription/generate_sub.py
rtk git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 2: Run disposable-VM acceptance tests**

On one supported Ubuntu VM and one supported Debian VM with snapshot/console access and a valid SSH key:

1. snapshot the VM;
2. run Phase 1 non-interactively over the existing SSH session;
3. establish a second SSH key-only session before closing the first;
4. verify the VLESS URI from a client outside the VPS;
5. reboot manually;
6. reconnect through SSH;
7. run `/opt/vpskit/tools/verify_phase1.sh`;
8. re-run the installer and confirm idempotency;
9. inject one controlled Xray validation failure on a restored snapshot and confirm rollback plus SSH access.

Expected: both operating systems retain SSH access, Xray owns TCP 443 after reboot, the VLESS connection works, reinstallation creates no duplicates, and fault injection restores the prior state.

- [ ] **Step 3: Review the final diff and safety invariants**

Run: `rtk git status --short && rtk git diff --stat && rtk git log --oneline --decorate -10`  
Expected: only Phase 1 files are present; no `.env`, keys, certificates, runtime output, or unrelated files are tracked.

- [ ] **Step 4: Create the Phase 1 release commit if qualification required fixes**

```bash
rtk git add vpskit tests .gitignore
rtk git commit -m "fix: qualify VPSKit Phase 1 installer"
```

Skip this commit when the worktree is already clean after qualification.

## Phase 1 Exit Gate / Phase 1 退出条件

Do not start Phase 2 until all of these are evidenced:

- local pytest, Bats, ShellCheck, shfmt, Ruff, and mypy commands exit 0;
- disposable Ubuntu and Debian VM runs pass first install, reboot, rerun, and rollback scenarios;
- SSH remains reachable through a separately established key-only session;
- TCP 443 is owned by `vpskit-xray.service` after reboot;
- no secret or private key appears in Git, logs, stdout, or public metadata;
- the user reviews the Phase 1 evidence and explicitly approves Phase 2.
