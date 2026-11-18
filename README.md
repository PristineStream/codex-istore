# Codex CLI for iStoreOS

维护仓库：[easepi/codex-istore](https://github.com/easepi/codex-istore)，基于 [PristineStream/codex-istore](https://github.com/PristineStream/codex-istore) 继续维护。

iStoreOS 的社区插件。它在 LuCI 的「服务 → Codex CLI」显示运行环境状态，并提供通过 SSH 安装、登录和使用 Codex 的步骤。Codex 由 OpenAI 提供。插件不在网页中接收登录代码或凭据，也不启动网页终端。

首版面向 iStoreOS 24.10.8（OpenWrt 24.10，x86_64 / musl，opkg）。运行程序固定为 Codex CLI 0.166.0。安装时会从 npm 官方注册表下载 `@openai/codex` 的对应 Linux 发布包，校验 SHA-512，并将运行程序放在数据盘。现有的 `codex` 命令和配置不会被替换。下载和解包会同时占用磁盘空间，建议在数据盘预留至少 2 GiB。

## 在 iStoreOS 安装

1. 使用下方 Actions 流程编译，在目标设备上用 `opkg install` 安装 SDK 生成的主包与简体中文包。iStore 元包由元数据仓库单独构建和发布。
2. 以管理员身份通过 SSH 安装运行程序。将下方的挂载点换成设备的实际数据盘。数据盘需直接挂载在 `/mnt` 下，并允许写入和执行。

   ```sh
   codex-istore install /mnt/sata2-4
   codex-istore run --version
   ```

3. 用已有 SSH 权限的非 root 项目账号登录。在 ChatGPT 安全设置中开启设备码登录。受管理账号可能需要工作区管理员开启。执行登录命令后，根据终端提示在浏览器完成认证。切换到该账号可读写的项目目录，用同一个账号运行 Codex。

   ```sh
   codex-istore run login --device-auth
   cd /path/to/your/project
   codex-istore run
   ```

   [OpenAI 官方设备码登录文档](https://learn.chatgpt.com/docs/auth#login-on-headless-devices)

LuCI 显示的是运行程序状态。若显示「运行程序不可用」，先检查数据盘是否仍挂载在原路径。安装路径可用 `cat /etc/codex-istore-runtime` 查看。卸载插件后，数据盘上的运行程序和用户自己的 Codex 登录数据会保留。

## SDK 构建

正式软件包统一使用 [openwrt-app-actions](https://github.com/linkease/openwrt-app-actions/actions/workflows/main.yml) 的 **Build IPKs**，由维护者手动触发：

```text
Branch:       third
applications: luci-app-codex-istore
target:       x64
```

构建完成后下载 `x64` Artifact。`ipk/codex_istore/` 包含主包和独立中文包，`apk/codex_istore/` 包含对应的 APK；翻译由 LuCI 自带的 `po2lmo` 编译。本仓库不再维护手工生成 IPK 或编译翻译的第二套流程。

现有工作流使用 21.02.3 IPK SDK 与 25.12.2 APK SDK。设备安装测试已覆盖 iStoreOS 24.10.1 x86_64 / opkg；编译通过不代表 APK 或所有系统版本均完成运行验证。IPK 与 APK 的包版本统一为 `0.1.0-r4`。

`app-meta-codex-istore/Makefile.template` 和 `logo.png` 是提交给标准 iStore 元数据仓库的配方模板。提交时将模板命名为 `Makefile`，使用该仓库的 `meta.mk` 构建；它不作为本 feed 的 SDK 包参与扫描。普通安装只需要主包与中文包。

已有完整的 SDK 主包、中文包和元包时，可用 `sh scripts/build-run.sh /path/to/ipks` 打包手动安装文件；该脚本只封装现成 IPK。

运行路径配置 `/etc/codex-istore-runtime` 通过 `/lib/upgrade/keep.d/codex-istore` 纳入默认系统配置备份；数据盘上的运行程序仍需保留原存储卷。
