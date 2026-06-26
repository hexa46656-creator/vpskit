# VPSKit v1 PRO Design Specification / 设计规格

**Status / 状态:** Proposed for implementation review / 待实施评审  
**Date / 日期:** 2026-06-19  
**Product / 产品:** VPSKit v1 PRO

## 1. Purpose / 目标

VPSKit v1 PRO is a commercial, non-interactive provisioning system for supported Ubuntu and Debian VPS hosts. It hardens the host, deploys three isolated VPN services, publishes connection metadata to a central FastAPI control plane, and returns client-ready subscription artifacts.

VPSKit v1 PRO 是一套商用、全自动、非交互式 VPS 部署系统。它在受支持的 Ubuntu/Debian 主机上执行安全加固，部署三个相互隔离的 VPN 服务，将连接元数据安全上传到中央 FastAPI 控制面，并返回可直接导入客户端的订阅配置。

The implementation must favor safe failure over partial success. It must never report completion until every required service, security control, and subscription endpoint has passed validation.

系统必须“安全失败优先”，禁止在部分安装成功时输出完成状态。只有所有必要服务、安全控制和订阅端点都通过验证后，才允许报告安装完成。

## 2. Scope / 范围

### Data plane / 客户 VPS 数据面

- Xray VLESS Reality on TCP 443.
- Hysteria2 with TLS on UDP 443.
- Trojan with TLS and SNI on TCP 8443.
- SSH, UFW, Fail2ban, sysctl hardening, BBR, MTU detection, and DNS configuration.
- Local generation of connection URIs and upload of connection metadata.
- Xray VLESS Reality 使用 TCP 443。
- Hysteria2 TLS 使用 UDP 443。
- Trojan TLS/SNI 使用 TCP 8443，作为独立备用隧道。
- 包含 SSH、UFW、Fail2ban、sysctl、BBR、MTU 和 DNS 优化。
- 在本地生成连接 URI，并上传连接元数据。

### Control plane / 中央控制面

- FastAPI application served behind HTTPS at `vpskit.alexhexa.com`.
- Authenticated registration and metadata upload.
- On-demand Base64, Clash YAML, v2rayNG, Shadowrocket, and sing-box output.
- Subscription status lookup and rate limiting.
- FastAPI 应用通过 `vpskit.alexhexa.com` 提供 HTTPS 服务。
- 提供带身份认证的注册与元数据上传。
- 按需生成 Base64、Clash YAML、v2rayNG、Shadowrocket 和 sing-box 配置。
- 提供订阅状态查询与限流。

### Explicitly out of scope for v1 / v1 明确不包含

- Billing, customer dashboards, multi-user administration, automatic domain purchase, DNS-provider automation, traffic accounting, and mobile applications.
- 计费、客户后台、多用户管理、自动购买域名、DNS 服务商自动化、流量计费和移动 App。

## 3. Architecture / 系统架构

The repository contains two independently deployable units:

仓库包含两个可独立部署的单元：

1. `vpskit/`: the client VPS installer and local modules.
2. `control-plane/`: the central FastAPI subscription service and its deployment files.

### Data-plane ports / 数据面端口

| Transport | Port | Service | Purpose |
|---|---:|---|---|
| TCP | 443 | Xray | VLESS Reality primary tunnel / 主隧道 |
| UDP | 443 | Hysteria2 | UDP-accelerated tunnel / UDP 加速隧道 |
| TCP | 8443 | Trojan | TLS fallback tunnel / TLS 备用隧道 |
| TCP | Existing SSH port | OpenSSH | Administration / 管理 |

TCP and UDP port 443 can coexist because they are distinct transports. Every required socket is checked before mutation. An occupied required socket causes a preflight failure unless it is already owned by the matching VPSKit service from a prior installation.

TCP 与 UDP 的 443 端口可以同时使用。安装前必须检测所有目标端口；若端口被非 VPSKit 服务占用，预检立即失败。若端口属于已有的对应 VPSKit 服务，则进入安全升级路径。

Each VPN service has its own Unix user, configuration directory, systemd unit, log identity, and restrictive filesystem permissions. Services do not share writable directories.

每个 VPN 服务使用独立的 Unix 用户、配置目录、systemd 单元、日志标识和严格文件权限，不共享可写目录。

## 4. Installer Contract / 安装器约定

The installer runs as root and accepts configuration only through environment variables. It never prompts for input.

安装器必须以 root 身份运行，只通过环境变量接收配置，禁止交互式提问。

Before preflight, the installer acquires an exclusive, non-blocking lock represented by `/var/lib/vpskit.lock`. The path is a persistent lock file, while the kernel lock is held on its file descriptor with `flock` for the full transaction. A concurrent run exits before mutation; a stale file does not block installation because ownership is determined by the kernel lock rather than file existence alone.

预检前，安装器必须通过 `/var/lib/vpskit.lock` 获取非阻塞独占锁，并在整个事务期间持有文件描述符上的 `flock`。并发安装必须在修改系统前退出；单纯遗留的锁文件不会造成永久锁死，因为锁归属由内核文件锁判断。

Required variables / 必填变量：

- `VPSKIT_TROJAN_DOMAIN`: customer-owned hostname whose A/AAAA record resolves to the target VPS.
- `VPSKIT_API_TOKEN`: bearer credential accepted by the control plane.
- `VPSKIT_HMAC_SECRET`: independent secret used to sign API requests.

Optional variables / 可选变量：

- `VPSKIT_API_BASE_URL`, default `https://vpskit.alexhexa.com`.
- `VPSKIT_LOG_DIR`, default `/var/log/vpskit`.
- Version pins for Xray, Hysteria2, and Trojan, with tested defaults committed in the installer.

The installer uses a strict execution mode, a global error trap, an operation journal, and a transaction-specific backup directory. Secrets are never printed or written to general logs.

安装器启用严格执行模式、全局错误捕获、操作日志和事务级备份目录。密钥禁止输出到终端或普通日志。

## 5. Preflight / 系统预检

Before any host mutation, preflight validates:

所有系统修改前必须完成：

- Root privileges and systemd availability.
- Supported Ubuntu/Debian release and architecture (`amd64` or `arm64`).
- Minimum 1 CPU, 512 MiB available RAM, and 1 GiB free disk space.
- Working IPv4 public address and outbound HTTPS connectivity.
- TCP 443, UDP 443, and TCP 8443 availability.
- Current SSH daemon configuration, active SSH port, and at least one valid public key in an effective authorized-keys file.
- `VPSKIT_TROJAN_DOMAIN` DNS resolution to a local public address.
- API variables are present without logging their values.
- Control-plane health and authenticated registration readiness.

No security setting or package installation starts when preflight fails.

预检失败时，不允许修改 SSH、防火墙、软件包或系统参数。

## 6. Security Hardening / VPSGuard 安全加固

### SSH lockout prevention / SSH 防锁死

The installer creates a timestamped backup of effective SSH configuration before changes. It writes a dedicated drop-in instead of rewriting the main file, then validates the complete configuration with `sshd -t`. It reloads rather than restarts SSH and verifies that the existing SSH port remains listening. On any validation or reload failure, it removes the drop-in, restores backups, and reloads the prior configuration.

安装器先备份当前 SSH 配置，通过独立 drop-in 应用设置，不直接覆盖主文件。修改后使用 `sshd -t` 校验，只 reload 不 restart，并确认原 SSH 端口仍在监听。任一步失败都必须删除新配置、恢复备份并重新加载旧配置。

Required effective settings:

```text
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
```

### Firewall and banning / 防火墙与封禁

UFW rules are staged before UFW is enabled. They preserve the detected SSH TCP port and allow TCP 443, UDP 443, and TCP 8443. Fail2ban enables an OpenSSH jail using the detected SSH port. Existing unrelated UFW rules are preserved.

UFW 启用前先写入规则：保留检测到的 SSH TCP 端口，并允许 TCP 443、UDP 443、TCP 8443。Fail2ban 使用实际 SSH 端口启用 OpenSSH jail。现有无关 UFW 规则必须保留。

### Kernel hardening / 内核加固

VPSKit uses named files under `/etc/sysctl.d/` and validates them before application. Settings cover source routing, ICMP redirects, SYN cookies, martian logging, reverse-path filtering in a VPS-compatible mode, and protected kernel pointers. Settings known to break common container or routed-VPS networking are excluded.

VPSKit 只在 `/etc/sysctl.d/` 写入具名配置，并在应用前校验。配置涵盖源路由、ICMP 重定向、SYN cookies、异常包日志、兼容 VPS 的反向路径过滤和内核指针保护；会破坏常见容器或路由 VPS 的激进参数不纳入 v1。

## 7. VPN Services / VPN 服务

### Xray Reality

- A UUID is generated locally with a cryptographically secure system utility.
- Reality X25519 private/public keys and a short ID are generated locally.
- The private key remains only in the Xray server configuration with mode `0600`.
- TCP 443 is explicit; UDP is not bound by Xray.
- The stealth destination and SNI use a tested configurable public TLS target, not the Trojan customer domain.
- 服务端私钥仅保存在权限为 `0600` 的本地 Xray 配置中，绝不上传。

### Hysteria2

- UDP 443 with TLS and password authentication.
- A locally generated self-signed certificate is used in domainless mode.
- Clients receive the certificate SHA-256 pin and must verify it; generated configurations do not use unrestricted `insecure: true` when the client format supports pinning.
- Congestion and bandwidth values default to conservative auto behavior and are environment-configurable.
- 使用自签名证书的 SHA-256 指纹进行客户端固定校验，避免无条件跳过 TLS 验证。

### Trojan

- TCP 8443 with a randomly generated password.
- A publicly trusted TLS certificate is issued for `VPSKIT_TROJAN_DOMAIN` only after DNS validation.
- SNI is the customer domain. Certificate renewal is automated and reloads Trojan without exposing credentials.
- Trojan is an independent fallback connection path, not an Xray protocol-level fallback chain.
- Trojan 是独立的备用连接通道，不与 Xray 形成协议内部转发链。

Every downloaded release asset is version-pinned and verified against an upstream checksum or a checksum pinned in a reviewed release manifest. Unsupported architecture or failed verification stops installation.

所有下载文件必须锁定版本并校验上游 checksum 或已审核的版本清单。架构不支持或校验失败时立即停止安装。

## 8. Network Optimization / 网络优化

- Enable BBR only when supported by the running kernel; otherwise retain the current congestion controller and log a warning.
- Detect the path MTU conservatively. Never set an interface MTU above its current value. Persist only a validated reduction.
- Configure Cloudflare and Google DNS through a systemd-resolved drop-in when systemd-resolved manages DNS. Do not overwrite `/etc/resolv.conf` when another resolver owns it.
- Apply bounded socket-buffer and queue settings suitable for low-memory VPS hosts.
- BBR 仅在内核支持时启用；MTU 只允许经过验证的保守下调；DNS 优化不得破坏非 systemd-resolved 环境；网络缓冲参数必须适合低内存 VPS。

No module promises optimization for a specific third-party website such as fast.com. The measurable goal is lower loss and stable throughput without unsafe tuning.

系统不承诺针对 fast.com 等特定第三方网站加速；可验收目标是降低丢包并保持稳定吞吐。

## 9. Control-Plane API / 中央 API

### Endpoints / 接口

- `POST /register`: validates a signed installer request and issues an internal node ID.
- `POST /upload-config`: validates the node and stores sanitized connection metadata; returns the random subscription ID and URL.
- `GET /sub/{id}`: returns Base64 by default and supports explicit negotiated formats for Clash, v2rayNG, Shadowrocket, and sing-box.
- `GET /status/{id}`: returns active/revoked state and non-sensitive timestamps.

Unknown subscription IDs return the same generic response shape as revoked IDs where practical, reducing enumeration signals.

### Authentication and signing / 身份认证与签名

Write requests require both:

写请求同时要求：

1. `Authorization: Bearer <VPSKIT_API_TOKEN>`.
2. HMAC-SHA256 over `timestamp + newline + nonce + newline + method + newline + path + newline + SHA256(body)` using `VPSKIT_HMAC_SECRET`.

The server rejects timestamps outside a five-minute window and atomically rejects reused nonces. Signature comparison is constant-time. HTTPS remains mandatory; HMAC does not replace TLS.

服务端拒绝超过五分钟的时间戳和重复 nonce，并使用常量时间比较签名。HMAC 不能替代 HTTPS。

### Rate limiting / 限流

Write endpoints are limited per token and source IP. Read endpoints are limited per source IP and subscription ID. The production deployment uses Redis-backed counters so limits remain consistent across API workers. Proxy headers are trusted only from the configured reverse proxy.

生产环境使用 Redis 限流，确保多 worker 一致性；只有受信任的反向代理才允许提供真实客户端 IP 头。

### Storage model / 存储模型

PostgreSQL stores node IDs, opaque subscription IDs, protocol connection metadata, creation/update timestamps, and status. It must not store Reality private keys, TLS private keys, HMAC secrets, API tokens, SSH keys, or server configuration files.

PostgreSQL 只存储节点 ID、不可预测的订阅 ID、协议连接元数据、时间戳和状态。禁止存储 Reality 私钥、TLS 私钥、HMAC secret、API token、SSH 密钥或完整服务端配置。

Connection credentials required by clients—UUIDs and protocol passwords—are metadata, not server private keys. They are encrypted at rest with an application encryption key supplied through the control-plane environment. Subscription IDs contain at least 192 bits of randomness and are stored as hashes so database disclosure does not directly reveal live URLs.

客户端所需 UUID 和协议密码属于连接元数据，但仍必须使用控制面环境变量提供的应用密钥进行静态加密。订阅 ID 至少包含 192 位随机性，并以哈希形式入库。

## 10. Subscription Rendering / 订阅生成

A canonical validated metadata schema is the single input to all renderers. Renderers are pure functions and never read private server configuration directly.

所有客户端格式由统一、已校验的元数据模型生成；renderer 为纯函数，不直接读取服务端私有配置。

Outputs include:

- Individual `vless://`, `hysteria2://`, and `trojan://` URIs.
- Base64 subscription containing compatible URI lines.
- Clash YAML with supported proxy entries and a usable selector group.
- v2rayNG-compatible URI subscription.
- Shadowrocket-compatible URI subscription.
- sing-box JSON with outbound definitions and certificate pin data where supported.

The response supports an explicit `format` query parameter and conservative content negotiation. Invalid metadata can never produce a partially rendered subscription.

## 11. Transaction and Rollback / 事务与回滚

The installer has four ordered phases:

1. Preflight and snapshot / 预检与快照
2. Package and service staging / 软件与服务暂存
3. Security and network activation / 安全与网络配置激活
4. API upload and final verification / API 上传与最终验证

Every mutation records a compensating action. On failure, rollback runs in reverse order. It restores SSH and sysctl files, disables only UFW rules added by the current transaction, restores replaced VPSKit service files, stops newly installed services, and keeps diagnostic logs. It does not uninstall shared system packages or delete pre-existing user configuration.

每项修改都记录对应回滚动作，失败时逆序执行。回滚恢复 SSH/sysctl 文件，只撤销本次事务添加的 UFW 规则，恢复被替换的 VPSKit 服务文件，停止本次新装服务并保留诊断日志；不卸载共享软件包，不删除用户已有配置。

Certificate issuance and central API writes are external side effects. Rollback revokes or deactivates a newly created subscription when possible and records any cleanup failure for operator action.

## 11.1 Implementation Phases / 实施阶段

Implementation is gated into independently runnable and testable releases:

1. **Phase 1 — Core installer:** preflight, installation lock, transaction journal, VPSGuard, Xray Reality, and a local VLESS subscription artifact.
2. **Phase 2 — Multi-protocol:** Hysteria2, Trojan, BBR, MTU, and DNS optimization.
3. **Phase 3 — Control plane:** signed FastAPI ingestion, PostgreSQL, Redis, and subscription lifecycle endpoints.
4. **Phase 4 — Subscription formats:** validated metadata schema and pure renderers for all required clients.
5. **Phase 5 — Hardening and reliability:** full health orchestration, reboot verification, schema evolution, operational recovery, and end-to-end production qualification.

每个阶段必须在进入下一阶段前独立通过测试和评审。Phase 1 只能输出 `VPSKit PHASE 1 COMPLETE`，不得输出全局 `VPSKit INSTALL COMPLETE`。全局完成信息只允许在 Phase 5 端到端验证确认 TCP 443、UDP 443、TCP 8443、控制面上传和公网订阅全部正常后输出。

## 12. Verification / 验证

Installation succeeds only when all checks pass:

- `sshd -t` succeeds and the detected SSH port is listening.
- UFW contains the required rules and retains SSH access.
- Fail2ban reports an active SSH jail.
- Xray configuration test passes and TCP 443 is listening.
- Hysteria2 configuration test passes and UDP 443 is bound.
- Trojan configuration test passes, TCP 8443 is listening, and the certificate matches the configured SNI.
- The API accepts the signed upload.
- Every generated format parses successfully in its schema/YAML parser.
- The subscription URL returns an active, non-empty subscription over HTTPS.

只有全部检查通过才输出规定的中英双语完成信息和三条 URI。任何失败均输出失败阶段、日志路径和回滚状态，不输出误导性的成功链接。

## 13. Testing Strategy / 测试策略

- Shell modules are tested with Bats using command shims and temporary roots.
- Python API and renderers are tested with pytest, FastAPI TestClient, isolated PostgreSQL/Redis integration services, and golden-file fixtures.
- Security tests cover missing auth, invalid signatures, stale timestamps, nonce replay, timing-safe comparison paths, rate limits, encrypted fields, and subscription enumeration resistance.
- Installer tests cover unsupported OS, occupied ports, missing SSH keys, DNS mismatch, download checksum failure, service validation failure, API failure, idempotent reinstall, and reverse-order rollback.
- CI runs ShellCheck, shfmt check mode, Ruff, mypy, pytest, Bats, dependency vulnerability scans, and container health checks.
- A disposable Ubuntu and Debian VM matrix performs end-to-end installation tests; macOS is a development host only, not an installer target.

## 14. Deployment / 部署

The control plane is deployed with Docker Compose using FastAPI, PostgreSQL, Redis, and a TLS reverse proxy. It includes explicit health checks, persistent volumes, restart policies, log rotation, database migrations, and secrets supplied through an uncommitted `.env` file or deployment secret store.

中央控制面使用 Docker Compose 部署 FastAPI、PostgreSQL、Redis 和 TLS 反向代理，包含 health checks、持久卷、restart policy、日志轮转和数据库迁移。密钥只能由未提交的 `.env` 或部署密钥系统提供。

The client installer uses native systemd services for lower memory overhead and direct host-network control. It supports clean first installation and idempotent VPSKit-managed upgrades.

## 15. Final Output / 最终输出

After fresh end-to-end verification, the installer prints:

```text
========================
VPSKit INSTALL COMPLETE
VPSKit 安装完成
========================

VLESS Reality:
vless://...

Hysteria2:
hysteria2://...

Trojan:
trojan://...

Subscription / 订阅:
https://vpskit.alexhexa.com/sub/...

Status / 状态:
✔ SSH secured / SSH 已加固
✔ Xray installed / Xray 已安装
✔ Hysteria installed / Hysteria2 已安装
✔ Trojan installed / Trojan 已安装
✔ Subscription active / 订阅已激活
```

## 16. Acceptance Criteria / 验收标准

1. A single environment-configured command completes without prompts on every supported clean VPS image.
2. Deliberate failure at each installation phase restores SSH access and reverses VPSKit-owned changes.
3. Re-running the installer is safe and does not duplicate firewall rules, users, services, or subscriptions.
4. Private keys never cross the client VPS boundary and never appear in logs or control-plane storage.
5. HMAC replay, invalid signature, invalid token, and rate-limit tests are enforced by the API.
6. All five subscription representations pass automated parsing tests and expose all three protocols where the client supports them.
7. Ubuntu and Debian end-to-end test VMs retain SSH connectivity and pass service health checks after installation and reboot.
8. The specified bilingual completion output appears only after the public subscription URL is verified active.
