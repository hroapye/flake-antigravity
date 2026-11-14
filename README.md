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

升级版本时：

```bash
# 1. 替换 package.nix 中的 version 和下载 URL
# 2. 为新文件生成哈希
nix store prefetch-file --json "<新的 Antigravity.tar.gz 下载地址>"

# 3. 把输出中的 hash 填入 package.nix 的 fetchurl.hash
# 4. 重新构建并安装
nix build path:.#
nix profile install path:.#
```

每次换版本都需要重新生成一次哈希；日常构建不需要重复生成。

当前版本为 `2.32.1`，使用官方 `Antigravity.tar.gz` 作为源码输入。

本项目把 Antigravity 官方 Linux x86_64 分发包封装为 Nix derivation，使其可以在 NixOS 上构建、安装和运行。

## 文件说明

- `package.nix`：应用打包定义，包括下载源、动态库、ELF 修正、桌面入口和启动 wrapper。
- `flake.nix`：Flake 入口，提供 `packages.default` 和 `apps.default`。
- `flake.lock`：锁定 nixpkgs 版本，由首次执行 Flake 命令时自动生成。

原始应用目录中的二进制和资源不会再作为构建源使用。构建源固定为官方外部下载地址。

## 当前版本

| 项目 | 值 |
| --- | --- |
| 应用版本 | `2.32.1` |
| Build ID | `6001966350991360` |
| Linux 源文件 | `Antigravity.tar.gz` |
| 下载地址 | `https://storage.googleapis.com/antigravity-public/antigravity-hub/2.32.1-6001966350991360/linux-x64/Antigravity.tar.gz` |
| SHA-256 | `sha256-TLLU/qdKdPF8/iUYQbkAJJxa0nKLlh79v3Kdr65/6EI=` |
| 解压顶层目录 | `Antigravity-x64` |

## 为什么需要哈希

Nix 使用固定输出（fixed-output derivation）下载外部文件。纯 Nix 构建必须提供内容哈希，用来：

- 校验下载文件没有损坏或变化；
- 生成固定的 Nix store 路径；
- 保证不同机器的构建输入一致。

哈希不要求由下载页面提供，可以在本地生成。它表示锁定到某份文件内容，不是官方数字签名。

下载页面如果直接提供了 SHA-256 或 SHA-512，可以直接使用。当前 tar.gz 地址没有在官方更新清单中提供哈希，因此使用 `nix store prefetch-file` 生成。

## 生成哈希

每个新版本或新下载文件需要生成一次哈希：

```bash
nix store prefetch-file --json \
  "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.32.1-6001966350991360/linux-x64/Antigravity.tar.gz"
```

输出示例：

```json
{
  "hash": "sha256-TLLU/qdKdPF8/iUYQbkAJJxa0nKLlh79v3Kdr65/6EI=",
  "storePath": "/nix/store/ynbvbdinsbzsk56qj3ayb5id4qrld677-Antigravity.tar.gz"
}
```

将 `hash` 字段填入 `package.nix` 的 `fetchurl.hash`。

该步骤不需要在每次构建时执行。相同文件只生成一次，后续 Nix 会复用 Nix store 中的缓存。

## 升级版本

升级时需要同时更新以下三个值：

1. `package.nix` 中的 `version`；
2. `package.nix` 中 `fetchurl.url` 的版本号和 Build ID；
3. `package.nix` 中 `fetchurl.hash`。

当前代码结构：

```nix
stdenv.mkDerivation {
  pname = "antigravity";
  version = "2.32.1";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.32.1-6001966350991360/linux-x64/Antigravity.tar.gz";
    hash = "sha256-TLLU/qdKdPF8/iUYQbkAJJxa0nKLlh79v3Kdr65/6EI=";
  };

  sourceRoot = "Antigravity-x64";
}
```

如果新机或本地尚未缓存该文件，先执行 `nix store prefetch-file` 获得新哈希。不要继续沿用旧版本的哈希。

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

安装到 NixOS 系统配置：

```nix
nixpkgs.config.allowUnfree = true;

environment.systemPackages = [
  (pkgs.callPackage /home/zhf/Downloads/Antigravity/Antigravity-x64/package.nix { })
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

版本升级应由 Nix 包完成：更新 URL、生成新哈希、重新构建并重新安装。

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
