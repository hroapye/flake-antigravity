# Antigravity NixOS 打包说明

## TL;DR

构建：

```bash
nix build path:.#
```

直接运行：

```bash
nix run path:.#
```

安装到当前用户：

```bash
nix profile install path:.#
antigravity
```

这里的 profile 元素名由 flake 目录名生成，因此是 `flake-antigravity`，
不是命令名 `antigravity`。可用以下命令确认：

```bash
nix profile list
```

升级版本时：

```bash
./scripts/update-antigravity.sh "<新的 Antigravity.tar.gz 下载地址>"
```

脚本会完成下载、生成哈希、更新 `vendor/antigravity-source.json` 并构建。
安装到当前用户后，升级时再执行：

```bash
nix profile upgrade flake-antigravity
```

当前版本、Build ID、下载地址和哈希统一记录在
`vendor/antigravity-source.json`，不需要分别修改多个文件。

脚本依赖 `nix` 和 `jq`。

本项目把 Antigravity 官方 Linux x86_64 分发包封装为 Nix derivation，使其可以在 NixOS 上构建、安装和运行。

## 文件说明

- `package.nix`：应用打包定义，包括下载源、动态库、ELF 修正、桌面入口和启动 wrapper。
- `flake.nix`：Flake 入口，提供 `packages.default` 和 `apps.default`。
- `flake.lock`：锁定 nixpkgs 版本，由首次执行 Flake 命令时自动生成。
- `vendor/antigravity-source.json`：当前 Antigravity 版本、Build ID、URL 和哈希。
- `scripts/update-antigravity.sh`：一条命令完成版本升级、哈希生成和构建。

原始应用目录中的二进制和资源不会再作为构建源使用。构建源固定为官方外部下载地址。

## 当前版本

版本信息以 [`vendor/antigravity-source.json`](vendor/antigravity-source.json) 为准。
`package.nix` 直接读取该文件，因此升级后不会出现版本号、URL 和哈希互相不一致的问题。

当前解压顶层目录固定为 `Antigravity-x64`。

## 为什么需要哈希

Nix 使用固定输出（fixed-output derivation）下载外部文件。纯 Nix 构建必须提供内容哈希，用来：

- 校验下载文件没有损坏或变化；
- 生成固定的 Nix store 路径；
- 保证不同机器的构建输入一致。

哈希不要求由下载页面提供，可以在本地生成。它表示锁定到某份文件内容，不是官方数字签名。

下载页面如果直接提供了 SHA-256 或 SHA-512，可以直接使用。当前 tar.gz 地址没有在官方更新清单中提供哈希，因此使用 `nix store prefetch-file` 生成。

## 生成哈希

哈希由更新脚本自动生成，不需要手工复制。脚本内部执行的核心命令是：

```bash
nix store prefetch-file --json \
  --name Antigravity.tar.gz \
  "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.35.1-4615540875067392/linux-x64/Antigravity.tar.gz"
```

输出示例：

```json
{
  "hash": "sha256-2SEDmob7+g0GloyXPq3/qDVytDSjUadxuK2fJBpJPX4=",
  "storePath": "/nix/store/j7vaci1chfv92wvi94y91mdrnb7jb0fc-Antigravity.tar.gz"
}
```

`prefetch-file` 下载完成后，文件位于 `/nix/store`，不是执行结束后会被删除的临时目录。
`fetchurl` 使用相同文件名和哈希时，会直接复用该 store 路径，因此安装阶段不会再次下载。

该缓存可以被 `nix-collect-garbage` 清理。它被清理后，下次重新构建会再次下载；
已经构建出的应用本身不受影响。

## 升级版本

后续升级只需要复制官方下载地址并执行：

```bash
./scripts/update-antigravity.sh \
  "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.35.1-4615540875067392/linux-x64/Antigravity.tar.gz"
```

以后版本只需替换其中的版本号和 Build ID：

```text
.../antigravity-hub/<版本>-<Build ID>/linux-x64/Antigravity.tar.gz
```

脚本会：

1. 从 URL 中提取版本号和 Build ID；
2. 用 `nix store prefetch-file` 下载到 `/nix/store` 并生成 SRI 哈希；
3. 原子替换 `vendor/antigravity-source.json`；
4. 执行 `nix build path:<仓库目录>`。

只更新元数据、不立即构建：

```bash
ANTIGRAVITY_SKIP_BUILD=1 ./scripts/update-antigravity.sh "<下载地址>"
```

如果 URL 的格式不符合 `.../<版本>-<Build ID>/linux-x64/Antigravity.tar.gz`，
脚本会直接报错，不会写入不完整的版本信息。

## 构建和运行

构建：

```bash
nix build path:.#
```

运行：

```bash
nix run path:.#
```

这里使用 `path:.#`。当前目录包含一个不完整的 `.git` 目录，直接使用 `.#` 会触发 Nix 的 Git 检测并失败。

## 安装

安装到当前用户 profile：

```bash
nix profile install path:.#
antigravity
```

安装后可以用 `nix profile list` 查看元素名。对当前仓库执行上述命令时，
元素名为 `flake-antigravity`。

如果以前从 `/home/zhf/Downloads/Antigravity/Antigravity-x64` 安装过，
现有元素名通常是 `Antigravity-x64`。迁移到当前仓库需要移除旧元素并重新安装：

```bash
nix profile remove Antigravity-x64
nix profile install path:/home/zhf/repo/flake-antigravity
```

之后升级使用：

```bash
nix profile upgrade flake-antigravity
```

安装到 NixOS 系统配置：

```nix
nixpkgs.config.allowUnfree = true;

environment.systemPackages = [
  (pkgs.callPackage /home/zhf/repo/flake-antigravity/package.nix { })
];
```

修改系统配置后执行：

```bash
sudo nixos-rebuild switch
```

## 打包实现

`package.nix` 主要处理以下内容：

- 使用 `fetchurl` 下载官方 tar.gz；
- 使用 `autoPatchelfHook` 修正主程序、`language_server`、`webm_encoder` 和 crash handler 等 ELF；
- 补充 GTK、X11、NSS、AT-SPI、ALSA、PulseAudio 等动态依赖；
- 设置 Chromium 通过 `dlopen` 加载的运行时库；
- 使用 `wrapGAppsHook3` 提供 GTK/GSettings 运行环境；
- 生成 `antigravity.desktop` 和图标；
- 在 Wayland 环境中根据 `NIXOS_OZONE_WL` 和 `WAYLAND_DISPLAY` 添加 Ozone/Wayland 参数。

不提供本地目录作为备用构建源。要重新使用本地目录，需要另行修改 `package.nix`。

## 自动更新

应用内的 electron-updater 不适用于 Nix store 中的只读安装。日志中的
`APPIMAGE env is not defined` 属于预期现象。

版本升级应由 Nix 包完成。执行一次更新脚本，然后升级 profile：

```bash
./scripts/update-antigravity.sh "<下载地址>"
nix profile upgrade flake-antigravity
```

## 排查

查看主进程日志：

```bash
tail -f ~/.config/Antigravity/logs/main.log
```

查看 language server 日志：

```bash
tail -f ~/.config/Antigravity/logs/language_server.log
```

如果窗口显示深色背景、登录页或内容无法加载，先检查 Google 服务和 OAuth 请求是否超时。Antigravity 依赖 Google 网络服务，代理配置不正确时可能表现为黑屏或一直停留在加载状态。

检查动态库是否有缺失：

```bash
ldd "$(nix path-info path:.#)/share/antigravity/antigravity" | grep 'not found'
```

正常情况不应输出任何 `not found`。
