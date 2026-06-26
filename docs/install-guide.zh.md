# VPSKit v2.0.0-beta 安装指南

## 安装

```bash
git clone https://github.com/hexa46656-creator/vpskit.git
cd vpskit
bash vpskit/cli/vpskit.sh version
```

## 首次使用

```bash
bash vpskit/cli/vpskit.sh status
bash vpskit/cli/vpskit.sh doctor
```

## 生成订阅

当配置了订阅文件时，可以使用现有订阅渲染器或 beta CLI 的 `sub` 命令：

```bash
bash vpskit/cli/vpskit.sh sub
```

## 导入 Shadowrocket

打开修复后的订阅文本或导出的订阅文件，使用 Shadowrocket 的原生导入流程导入。

## 说明

- VPSKit v2.0.0-beta 默认只读，除非你显式提供本地修复输出路径。
- 不要把它用于修改 SSH、防火墙或 systemd 设置。
