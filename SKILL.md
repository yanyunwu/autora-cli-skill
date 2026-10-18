---
name: autora-cli-skill
description: 使用 autora 命令行工具完成文章、评论、友链、媒体及已授权的账号角色操作；需要了解安装、子命令、文件输入或结果处理时使用。
---

# Autora CLI Skill

整个 Skill 仓库可独立分发，已包含 `scripts/linux-amd64/autora`、`scripts/linux-arm64/autora` 和 `scripts/darwin-arm64/autora` 三个平台的二进制；安装脚本自动选择本机对应文件。生成的单平台分发包使用 `scripts/autora`（Windows 为 `scripts/autora.exe`）。

## 安装与开始

如果当前技能副本只保存文本、没有平台二进制，先从 [公开的 autora-cli-skill 仓库](https://github.com/yanyunwu/autora-cli-skill) 取得完整安装包并进入该目录。同一执行环境只需安装一次 CLI，各岗位继续使用自己的独立令牌。

在完整 Skill 目录运行：

```sh
sh install.sh
```

安装到当前用户的命令目录并配置 PATH。安装后新开终端，再执行：

```sh
autora --help
autora auth me
```

支持 Linux、macOS 和 Windows 的 Git Bash/MSYS2/Cygwin；WSL 使用 Linux 包。重复运行可更新命令。自定义目录用 `--bin-dir DIRECTORY`，只复制文件用 `--no-path`。

由启动器向当前岗位进程注入 `AUTORA_BASE_URL`（本站地址）和专用 `AUTORA_TOKEN`。安装脚本只安装工具。具体参数以本机 `--help` 为准；需要调整超时用全局 `--timeout SECONDS`。

## 模块说明

| 模块     | 何时读取                             | Reference                                                 |
| -------- | ------------------------------------ | --------------------------------------------------------- |
| 命令发现 | 查看可调用操作、准备输入或通用调用   | [discovery/usage.md](references/discovery/usage.md)       |
| 身份     | 核对当前账号、有效权限和令牌授权管理 | [auth/usage.md](references/auth/usage.md)                 |
| 账号角色 | 查询岗位、管理角色或显式绑定账号授权 | [accounts/usage.md](references/accounts/usage.md)         |
| 文章     | 读取、创建、编辑或发布文章           | [articles/usage.md](references/articles/usage.md)         |
| 评论     | 读取评论、上传评论图片、回复或审核   | [comments/usage.md](references/comments/usage.md)         |
| 友链     | 上传站点图标、维护友链和独立审核     | [friend-links/usage.md](references/friend-links/usage.md) |
| 媒体     | 上传文章图片或取得临时访问地址       | [media/usage.md](references/media/usage.md)               |

## 调用约定

- 使用当前岗位的独立令牌，只在进程环境中传递。
- 用文件或 stdin 传递正文，不把用户内容拼进 shell 命令。
- 写入前读取当前对象；版本冲突先核对变更。
- 回复使用普通提交，每次成功返回 201 并创建新评论，重复提交仍计入账户配额。
- 任务记录保存目标、实际动作、返回的评论 ID 与状态。
- 普通命令输出 JSON，检查 `ok`、错误和退出码。CLI 不自动重试，超时不能视作未写入。
