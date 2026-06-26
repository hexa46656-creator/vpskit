# VPSKit

## What VPSKit Is

VPSKit is an AI-assisted VPS automation project. The long-term goal is to provide a safe control plane and deployment workflow for VPS runtime visibility, subscription rendering, and future provisioning tasks.

## Current Status

This repository is currently at **Phase 0.5**. Phase 0.5 is only a runnable and testable backend/frontend application skeleton.

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
- Phase 1: isolated installer test harness and safe preflight design.
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

当前仓库处于 **Phase 0.5**。Phase 0.5 只是一个可运行、可测试的后端和前端应用骨架。

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
- Phase 1：隔离的安装器测试框架和安全预检设计。
- 后续阶段：受控的 VPS 服务安装、订阅格式、部署打包和生产安全加固。

## 许可证

当前尚未选择许可证。添加许可证之前，请勿重新分发。
