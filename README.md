# Autora CLI Skill

Autora CLI 的技能说明、安装脚本与预编译二进制。CLI 源码位于 [Autora](https://github.com/yanyunwu/autora/tree/main/crates/autora-cli)，本仓库由 Autora 根目录的 `autora-cli-skill` Git 子模块固定引用。

## 安装

```sh
git clone https://github.com/yanyunwu/autora-cli-skill.git
cd autora-cli-skill
sh install.sh
```

仓库公开，克隆无需密钥。二进制直接存放在 Git 中，不需要在安装机器上安装 Rust 或构建 CLI：

| 平台                  | 文件                          |
| --------------------- | ----------------------------- |
| Linux amd64 / x86_64  | `scripts/linux-amd64/autora`  |
| Linux arm64 / aarch64 | `scripts/linux-arm64/autora`  |
| macOS Apple Silicon   | `scripts/darwin-arm64/autora` |

Linux 产物为静态 musl 可执行文件。`SHA256SUMS` 记录三份二进制的校验值，可用 `sha256sum -c SHA256SUMS` 验证；macOS 使用 `shasum -a 256 -c SHA256SUMS`。安装器默认安装到当前用户目录并配置 PATH，按提示新开终端，再执行 `autora --help`。可选参数为 `--bin-dir DIRECTORY` 与 `--no-path`。

本仓库不包含账号凭据。运行工具时，由可信启动器向当前岗位进程分别注入 `AUTORA_BASE_URL` 和该账号自己的 `AUTORA_TOKEN`。安装不授予任何站点权限；操作仍由后端核验账号、令牌范围、归属与版本。

## 维护

在 Autora 主仓库初始化子模块后，`make cli-build` 编译当前平台的原生 CLI；在 macOS 上更新对应子模块二进制与校验值，GNU Linux 原生产物保留在 `target/release`，不会覆盖受维护的静态版本。`make cli-build-linux` 构建两个 Linux 静态版本；更新 macOS arm64 版本需在 Apple Silicon Mac 上运行 `make cli-build`。其他平台的本地构建不属于上述三份受维护产物。

CLI 或 OpenAPI 更新后应重新构建对应产物，并在主仓库运行 `make cli-check`。维护文件和二进制一起提交：先提交、推送本仓库的 `main`，再提交主仓库的子模块指针。父仓库以精确提交引用本仓库，普通 `git submodule update --init` 不会自动升级到最新版本。

完整工具说明见 [SKILL.md](SKILL.md)，各模块用法位于 `references/`。独立分发整个仓库时保留三份平台文件；单平台包可使用 `scripts/autora` 布局，并复用同一安装脚本。
