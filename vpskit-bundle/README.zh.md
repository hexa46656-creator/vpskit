# VPSKit 客户端打包

这个打包目录是面向客户交付的 VPSKit 成品，输出位置是 `./vpskit-bundle`。

它包含：

- 协议导出文件
- 支持客户端的导入说明
- QA 汇总
- 协议布局说明
- 安全说明

在安装完成后，需要把一个干净、脱敏的客户端包交给客户时使用。

首选协议：

- TCP 443 上的 VLESS Reality
- UDP 443 上的 Hysteria2
- TCP 8443 上的 Trojan，作为兼容回退方案
