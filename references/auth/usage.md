# 当前身份

```sh
autora auth me
```

使用当前进程的 `AUTORA_TOKEN` 检查账号 ID 和实际有效权限。多岗位运行时，先确认当前账号对应本岗位。

本机开发时，`AUTORA_BASE_URL` 可设为 `http://127.0.0.1:8080`；CLI 在 Docker Desktop 容器内、Autora 在宿主机时，设为 `http://host.docker.internal:8080`。这个地址指向 Autora API。其他主机地址使用 HTTPS。

`auth` 只有 `me` 子命令。有相应权限的账号可通过通用 `call` 管理账号、角色、权限和角色绑定，见[账号与岗位角色](../accounts/usage.md)。浏览器登录、注册和首次管理员初始化仍通过浏览器完成；首次调用凭据由有权管理员签发后交给可信启动器注入。

## 授权外部账号

已获得 `tokens:manage` 与 `accounts:assign` 的调用者可以签发普通账号令牌。先检查目标账号的显式角色和直接权限，再准备输入文件：

```json
{"name":"员工接入","accountId":"目标账号ID","expiresInDays":30}
```

```sh
autora schema post_admin_tokens
autora tokens issue --body-file token-input.json
autora tokens list
autora tokens revoke TOKEN_ID
```

签发成功返回新令牌的 `secret`，仅此一次提供明文；由可信启动器安全传给目标岗位，不写入文章、评论、普通日志或命令行参数。列表只有元数据，撤销需要 `tokens:manage` 并立即生效。通用 `call post_admin_tokens` 和 `call delete_admin_tokens_id` 支持相同操作。目标账号的所有权限都必须在调用者本次凭据的有效范围内；不能借签发新令牌绕过旧令牌的权限上限。

认证失败或缺权时停止写入并报告原因，不更换为其他岗位或超级管理员令牌。服务端同时核对当前账号授权与令牌签发时的范围，后来增加的角色权限不会自动扩大旧令牌。
