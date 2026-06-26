# VPSKit

## What VPSKit Is

VPSKit is an AI-assisted VPS automation project. The long-term goal is to provide a safe control plane and deployment workflow for VPS runtime visibility, subscription rendering, and future provisioning tasks.

## Current Status

This repository has completed **Phase 0.5**, **Phase 1A**, and **Phase 1B**, and is starting **Phase 1C**. Phase 0.5 is only a runnable and testable backend/frontend application skeleton.

## Phase 1A Installer Test Harness

Phase 1A adds an installer test harness only. It introduces simulated shell helpers and Bats tests for logging, dry-run detection, read-only system checks, lock behavior, and transaction rollback behavior.

Phase 1A does not modify VPS system configuration. Real installer mutation logic will come only after safety tests are established.

## Phase 1B Read-Only System Inspection

Phase 1B adds read-only system inspection helpers for operating system metadata, command availability, TCP/UDP port status, systemd service status, UFW status, SSH configuration reads, and deterministic inspection summaries.

Phase 1B does not modify VPS system configuration, does not run `sudo`, and does not install services. Real mutation logic remains blocked until later guarded phases.

## Phase 1C Install Lock and Transaction Safety

Phase 1C hardens install lock handling, transaction lifecycle behavior, rollback cleanup, and dry-run safety.

Phase 1C remains test-only and simulation-only. It does not modify VPS system configuration, does not run `sudo`, and does not install services. Real mutation logic remains blocked until later guarded phases.

## Repository Structure

```text
.
├── vpskit/       # FastAPI backend package and backend tests
├── vpskit-ui/    # Vite, React, and TypeScript frontend skeleton
└── docs/         # Planning and design notes
```

## Backend Quick Start

```bash
cd vpskit
python3.11 -m venv .venv
source .venv/bin/activate
python3.11 -m pip install -e ".[dev]"
uvicorn vpskit.main:app --reload --host 0.0.0.0 --port 8080
```

## Frontend Quick Start

```bash
cd vpskit-ui
npm install
npm run dev
```

The frontend dev server proxies read-only `/health` and `/runtime/*` requests to the backend at `http://localhost:8080`.

## Available API Endpoints

- `GET /health`: returns backend health and environment.
- `GET /runtime/services`: returns the current in-memory runtime service list.

## Development Commands

Backend:

```bash
cd vpskit
python3.11 -m pytest tests/ -v
```

Frontend:

```bash
cd vpskit-ui
npm run build
```

Repository checks:

```bash
git diff --check
git status --short
```

## Safety Boundary

This Phase 0.5 version does not modify SSH, UFW, Fail2ban, systemd, firewall, Xray, Hysteria2, Trojan, certificates, or any VPS system configuration. It is only a runnable and testable application skeleton.

No installer logic or VPS mutation logic is included in Phase 0.5.

## Roadmap

- Phase 0.5: runnable FastAPI backend, runnable Vite frontend, and baseline tests.
- Phase 1A: isolated installer test harness and simulated safety checks.
- Phase 1B: read-only system inspection and deterministic preflight summaries.
- Phase 1C: install lock and transaction safety hardening.
- Later Phase 1 work: guarded preflight decisions and mutation planning after safety layers are tested.
- Later phases: controlled VPS service installation, subscription formats, deployment packaging, and production hardening.

## License

No license has been selected yet. Do not redistribute until a license is added.

---

# VPSKit

## 项目名称

VPSKit

## VPSKit 是什么

VPSKit 是一个 AI 辅助的 VPS 自动化项目。长期目标是为 VPS 运行状态、订阅渲染和未来部署流程提供安全的控制面与自动化工作流。

## 当前状态

当前仓库已经完成 **Phase 0.5**、**Phase 1A** 和 **Phase 1B**，并开始 **Phase 1C**。Phase 0.5 只是一个可运行、可测试的后端和前端应用骨架。

## Phase 1A 安装器测试框架

Phase 1A 只添加安装器测试框架。它包含模拟的 shell helper 和 Bats 测试，用于验证日志、dry-run 检测、只读系统检查、锁行为和事务回滚行为。

Phase 1A 不会修改 VPS 系统配置。真实的安装器修改逻辑只会在安全测试建立之后再加入。

## Phase 1B 只读系统检查

Phase 1B 添加只读系统检查 helper，用于读取操作系统信息、命令可用性、TCP/UDP 端口状态、systemd 服务状态、UFW 状态、SSH 配置和确定性的检查摘要。

Phase 1B 不会修改 VPS 系统配置，不会运行 `sudo`，也不会安装服务。真实的修改逻辑仍然会被阻止，直到后续受保护阶段再加入。

## Phase 1C 安装锁和事务安全

Phase 1C 会强化安装锁处理、事务生命周期、回滚清理和 dry-run 安全。

Phase 1C 仍然只是测试和模拟，不会修改 VPS 系统配置，不会运行 `sudo`，也不会安装服务。真实的修改逻辑仍然会被阻止，直到后续受保护阶段再加入。

## 仓库结构

```text
.
├── vpskit/       # FastAPI 后端包和后端测试
├── vpskit-ui/    # Vite、React、TypeScript 前端骨架
└── docs/         # 规划和设计文档
```

## 后端快速启动

```bash
cd vpskit
python3.11 -m venv .venv
source .venv/bin/activate
python3.11 -m pip install -e ".[dev]"
uvicorn vpskit.main:app --reload --host 0.0.0.0 --port 8080
```

## 前端快速启动

```bash
cd vpskit-ui
npm install
npm run dev
```

前端开发服务器会把只读的 `/health` 和 `/runtime/*` 请求代理到 `http://localhost:8080` 后端。

## 当前 API

- `GET /health`：返回后端健康状态和运行环境。
- `GET /runtime/services`：返回当前内存中的运行服务列表。

## 开发命令

后端：

```bash
cd vpskit
python3.11 -m pytest tests/ -v
```

前端：

```bash
cd vpskit-ui
npm run build
```

仓库检查：

```bash
git diff --check
git status --short
```

## 安全边界

当前 Phase 0.5 版本不会修改 SSH、UFW、Fail2ban、systemd、防火墙、Xray、Hysteria2、Trojan、证书或任何 VPS 系统配置。它只是一个可运行、可测试的应用骨架。

Phase 0.5 不包含安装器逻辑，也不包含任何 VPS 系统修改逻辑。

## 路线图

- Phase 0.5：可运行的 FastAPI 后端、可运行的 Vite 前端和基础测试。
- Phase 1A：隔离的安装器测试框架和模拟安全检查。
- Phase 1B：只读系统检查和确定性的预检摘要。
- Phase 1C：安装锁和事务安全加固。
- 后续 Phase 1 工作：在安全层完成测试之后，再设计受保护的预检决策和修改计划。
- 后续阶段：受控的 VPS 服务安装、订阅格式、部署打包和生产安全加固。

## 许可证

当前尚未选择许可证。添加许可证之前，请勿重新分发。
