<div align="center">
<h1 align="center">
<img src="docs/images/app_icon.png" width="40"> OTP Token
</h1>

![GitHub License](https://img.shields.io/github/license/OHOTP/ohtotptoken) ![GitHub Release](https://img.shields.io/github/v/release/OHOTP/ohtotptoken) ![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/OHOTP/ohtotptoken/build.yaml) ![QQ Group](https://img.shields.io/badge/QQ-1060812974-red)


[简体中文](docs/README_CN.md)

</div>

Open source OTP Authenticator for HarmonyOS NEXT.

## Feature

- [x] Support TOTP Token
- [x] Support HOTP Token
- [x] Support Steam Token, [Importing from Steam](https://github.com/stratumauth/app/wiki/Importing-from-Steam)
- [x] Support Forti Token
- [x] Setting Page
- [x] Asset Store Kit (TEE Hardware-backed Secret Storage)
- [x] Huawei Cloud Drive Backup & Restore (End-to-End Encrypted)
- [x] Device Migration via BackupExtensionAbility
- [x] Anti-Peeping Protection (DLP)
- [x] Desktop Widget (TOTP & HOTP)

---
<b>Phone</b>
<p float="left">
  <img height="400px" alt="Token list" src="./screenshot/phone1.png" />
  <img height="400px" alt="Add Steam token" src="./screenshot/phone2.png" />
  <img height="400px" alt="Steam actions" src="./screenshot/phone3.png" />
  <img height="400px" alt="Steam account status" src="./screenshot/phone4.png" />
  <img height="400px" alt="Steam login" src="./screenshot/phone5.png" />
  <img height="400px" alt="Settings" src="./screenshot/phone6.png" />
</p>
<b>Watch</b>
<p float="left">
  <img height="220px" alt="Watch token list" src="./screenshot/watch1.png" />
  <img height="220px" alt="Watch codes" src="./screenshot/watch2.png" />
  <img height="220px" alt="Watch codes near refresh" src="./screenshot/watch3.png" />
</p>
<b>PC</b>
<p float="left">
  <img height="300px" alt="Token list" src="./screenshot/pc1.png" />
  <img height="300px" alt="Edit token" src="./screenshot/pc2.png" />
  <img height="300px" alt="Steam token" src="./screenshot/pc3.png" />
  <img height="300px" alt="Security settings" src="./screenshot/pc4.png" />
</p>

---

## Reference
- [paolostivanin/libcotp](https://github.com/paolostivanin/libcotp)
- [Netthaw/TOTP-MCU](https://github.com/Netthaw/TOTP-MCU)
- [ss23/fortitoken-mobile-registration](https://github.com/ss23/fortitoken-mobile-registration)
- [andOTP/andOTP](https://github.com/andOTP/andOTP): icons
- [iamhyc/Aigis](https://github.com/iamhyc/Aigis)
- [nanopb/nanopb](https://github.com/nanopb/nanopb): protobuf for google authenticator migration

## Contributing

Contributions are welcome! Please read the [Contribution Guidelines](CONTRIBUTING.md) (in Chinese) before opening a pull request.

> ⚠️ **Pull Requests must target the [`dev`](https://github.com/OHOTP/ohtotptoken/tree/dev) branch**, not `main`. The `main` branch is reserved for releases and is tied to the auto-release CI.

---

## Contributors

<a href="https://github.com/OHOTP/ohtotptoken/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=OHOTP/ohtotptoken" />
</a>

Made with [contrib.rocks](https://contrib.rocks).
