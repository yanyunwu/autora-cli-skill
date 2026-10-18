# 账号与岗位角色

账号、角色和权限操作通过通用 `call` 调用，是否允许执行仍由后端按当前账号授权和令牌原始范围核对。只在可信任务明确授权的范围内调整账号或岗位。

权限点由后端代码内置，权限目录只读。角色和账户直接授权只能选择目录中的权限 ID；权限定义随应用版本维护。

## 查询与发现

```sh
autora auth me
autora operations --realm bearer
autora schema get_admin_roles
autora call get_admin_roles
autora call get_admin_permissions
autora schema post_admin_roles
autora schema post_admin_accounts
autora schema put_admin_accounts_id_access
```

角色列表返回 `id`、`permissionIds` 和 `permissionKeys`；权限列表返回 `id` 与 `code`。写入使用返回的 ID，不用名称或权限 code 代替 ID。查询角色需要 `roles:view` 或 `accounts:assign`；创建角色需要 `roles:create`；创建并分配账号需要 `accounts:create` 和 `accounts:assign`。

首次初始化只预置以下普通岗位，不创建员工账号。查询当前角色后再选用；管理员可能已经修改、停用或删除它们，已有数据库不会在重启时补回岗位或恢复撤销的权限。

| 角色 ID                       | 岗位       |
| ----------------------------- | ---------- |
| `preset-station-owner`        | 站长       |
| `preset-content-creator`      | 内容创作者 |
| `preset-comment-moderator`    | 评论审核员 |
| `preset-friend-link-reviewer` | 友链审核员 |
| `preset-comment-receptionist` | 接待组长   |
| `preset-receptionist`         | 接待员     |

具体权限以角色列表的当前 `permissionKeys` 和操作 schema 为准。站长预置 `*`，覆盖全部当前及未来权限。岗位均可编辑、停用和删除；超级管理员是唯一受保护的系统角色。账号必须显式绑定 `roleIds`，姓名、头衔和 AI 展示身份都不授予权限。

所有岗位初始共享 `comments:reply`，以及 `articles:view-own`、`articles:write-own`、`articles:publish-own`、`articles:delete-own`。本人文章权限只允许处理当前账号自己的文章，包含自行发布、撤回、归档和永久删除；用法见[文章命令](../articles/usage.md)。其他岗位职责所需的当前权限从角色列表核对。

## 创建角色和账号

需要自定义角色时，从权限列表取出任务所需权限的 ID，替换示例中的 `PERMISSION_ID`：

```sh
autora call post_admin_roles --body-file - <<'JSON'
{"name":"自定义岗位","description":"经授权的岗位职责","status":"active","permissionIds":["PERMISSION_ID"]}
JSON
```

保存成功后使用响应的角色 ID。创建账号先查看 `post_admin_accounts` schema，再从受控文件或 stdin 提交姓名、邮箱、密码等必需输入，明确包含 `roleIds` 和 `directPermissionIds: []`：

```sh
autora call post_admin_accounts --body-file - < account.json
```

不要把密码或令牌放进命令参数、示例记录或任务输出。令牌签发、查询和撤销见[授权外部账号](../auth/usage.md#授权外部账号)。

## 为已有账号绑定岗位

先读取目标账号与当前岗位，确认需要保留的授权，再提交完整数组：

```sh
autora call get_admin_accounts_id --path id=ACCOUNT_ID
autora call get_admin_roles
autora call put_admin_accounts_id_access --path id=ACCOUNT_ID --body-file - <<'JSON'
{"roleIds":["preset-receptionist"],"directPermissionIds":[]}
JSON
```

将 `ACCOUNT_ID` 替换为已确认的账号 ID。此操作需要 `accounts:assign`，会替换该账号的全部角色和直接权限；示例只保留接待员岗位并清空直接授权。需要多个岗位时列出全部 `roleIds`。员工通常通过角色分权，直接权限用于显式例外。

角色或绑定变更会立即影响当前账号授权，但不会扩大已签发 Bearer 令牌的原始范围。分配站长角色后，已有窄范围令牌也不会自动取得 `*`；需要更多权限时，由具备足够有效权限的调用者签发新令牌，再由可信启动器更新岗位进程环境。
