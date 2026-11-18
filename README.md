# Codex CLI for iStoreOS

维护仓库：[easepi/codex-istore](https://github.com/easepi/codex-istore)，基于 [PristineStream/codex-istore](https://github.com/PristineStream/codex-istore) 继续维护。

iStoreOS 的社区插件。它在 LuCI 的「服务 → Codex CLI」显示运行环境状态，并提供通过 SSH 安装、登录和使用 Codex 的步骤。Codex 由 OpenAI 提供。插件不在网页中接收登录代码或凭据，也不启动网页终端。

首版面向 iStoreOS 24.10.8（OpenWrt 24.10，x86_64 / musl，opkg）。运行程序固定为 Codex CLI 0.166.0。安装时会从 npm 官方注册表下载 `@openai/codex` 的对应 Linux 发布包，校验 SHA-512，并将运行程序放在数据盘。现有的 `codex` 命令和配置不会被替换。下载和解包会同时占用磁盘空间，建议在数据盘预留至少 2 GiB。

## 在 iStoreOS 安装

1. 在 iStore 的手动安装页面导入发布目录内的 `.run` 文件。也可以在 SSH 中用 `opkg install` 安装 IPK，按主包、简体中文包、iStore 元包的顺序安装。本机快捷构建会将中文翻译合进主包。
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

## 构建与提交

- `luci-app-codex-istore/` 包含 LuCI 页面、iStoreOS 桌面入口、只读状态接口和 SSH 安装命令。
- `app-meta-codex-istore/` 包含 iStore 列表需要的元数据和图标，主包依赖为 `luci-app-codex-istore`。
- `scripts/build-ipk.sh` 在 iStoreOS 本机生成两个测试 IPK。`scripts/build-run.sh` 将同一目录内的主包、元包和独立语言包（如有）打成 iStore 可一次导入的文件。

```sh
sh scripts/build-ipk.sh
sh scripts/build-run.sh
sh dist/codex-istore_0.1.0-3_x86_64.run --check
```

最后一条只校验包内容，不安装。

快捷构建需要 Node.js（编译中文翻译）、GNU tar 和 iStore 的 `ipkg-build`。开发机上可用 `IPKG_BUILD=/path/to/ipkg-build sh scripts/build-ipk.sh` 指定打包器。包版本从两个 Makefile 读取；打包过程统一生成 root:root 属主，去掉组/其他用户写权限，避免将开发机账号和共享目录权限带到路由器。可用 `python3 scripts/test-quick-packages.py dist` 检查实际生成的 IPK。

上游首版用于 iStore 审核的三个 IPK 使用 OpenWrt 24.10.8 x86/64 musl SDK 构建，LuCI 固定为 iStoreOS 24.10.8（2026073111）使用的 `2e459653e1a370ff3da1c8009c76e7287125f803`。主包和简体中文包提交至软件包仓库，元数据配方和图标提交至元数据仓库，由 iStore 维护者审核和发布。此版本只面向 24.10 的 opkg，未验证 25.12 的 APK。 [OpenWrt SDK](https://downloads.openwrt.org/releases/24.10.8/targets/x86/64/) · [iStore 软件包提交说明](https://github.com/istoreos/istore-repo#pr指南) · [iStore 元数据提交说明](https://github.com/istoreos/openwrt-app-meta#在线提交流程)

运行路径配置 `/etc/codex-istore-runtime` 通过 `/lib/upgrade/keep.d/codex-istore` 纳入默认系统配置备份；数据盘上的运行程序仍需保留原存储卷。`DESIGN.md`、`UX-CONTRACT.md` 和 `docs/test-evidence/` 仅供本地使用，不纳入 Git。
