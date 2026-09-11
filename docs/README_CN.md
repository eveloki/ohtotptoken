<div align="center">
<h1 align="center">
<img src="images/app_icon.png" width="40"> OTP令牌
</h1>

![GitHub License](https://img.shields.io/github/license/OHOTP/ohtotptoken) ![GitHub Release](https://img.shields.io/github/v/release/OHOTP/ohtotptoken) ![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/OHOTP/ohtotptoken/build.yaml) ![QQ Group](https://img.shields.io/badge/QQ-1060812974-red)


</div>

原生鸿蒙开源OTP二步验证应用。

## 功能

- [x] 支持TOTP令牌
- [x] 支持HOTP令牌
- [x] 支持Steam令牌, [从Steam导入令牌](https://github.com/stratumauth/app/wiki/Importing-from-Steam)
- [x] 支持Forti令牌
- [x] 设置界面
- [x] 鸿蒙 Asset Store Kit（TEE 硬件级密钥保护）
- [x] 华为云盘备份与恢复（端到端加密）
- [x] 基于 BackupExtensionAbility 的换机迁移
- [x] 防窥保护（DLP）
- [x] 桌面卡片（TOTP & HOTP）

---
<b>手机</b>
<p float="left">
  <img height="400px" alt="令牌列表" src="../screenshot/phone1.png" />
  <img height="400px" alt="Steam 令牌添加" src="../screenshot/phone2.png" />
  <img height="400px" alt="Steam 功能入口" src="../screenshot/phone3.png" />
  <img height="400px" alt="Steam 账户状态" src="../screenshot/phone4.png" />
  <img height="400px" alt="Steam 登录" src="../screenshot/phone5.png" />
  <img height="400px" alt="设置" src="../screenshot/phone6.png" />
</p>
<b>手表</b>
<p float="left">
  <img height="220px" alt="手表令牌列表" src="../screenshot/watch1.png" />
  <img height="220px" alt="手表动态码" src="../screenshot/watch2.png" />
  <img height="220px" alt="手表动态码（临近刷新）" src="../screenshot/watch3.png" />
</p>
<b>PC</b>
<p float="left">
  <img height="300px" alt="令牌列表" src="../screenshot/pc1.png" />
  <img height="300px" alt="编辑令牌" src="../screenshot/pc2.png" />
  <img height="300px" alt="Steam 令牌" src="../screenshot/pc3.png" />
  <img height="300px" alt="安全性设置" src="../screenshot/pc4.png" />
</p>

---

## 参考项目
- [paolostivanin/libcotp](https://github.com/paolostivanin/libcotp)
- [Netthaw/TOTP-MCU](https://github.com/Netthaw/TOTP-MCU)
- [ss23/fortitoken-mobile-registration](https://github.com/ss23/fortitoken-mobile-registration)
- [andOTP/andOTP](https://github.com/andOTP/andOTP): 图标包
- [iamhyc/Aigis](https://github.com/iamhyc/Aigis)
- [nanopb/nanopb](https://github.com/nanopb/nanopb): 用于 Google 身份验证器迁移的`protobuf`库

## 贡献

欢迎参与本项目！提交 Pull Request 前，请先阅读[贡献指南](../CONTRIBUTING.md)。

> ⚠️ **Pull Request 请提交到 [`dev`](https://github.com/OHOTP/ohtotptoken/tree/dev) 分支**，`main` 仅用于发布，且与自动发布 CI 绑定。