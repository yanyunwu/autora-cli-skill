# 评论命令

## 读取

```sh
autora comments list ARTICLE_SLUG --page 1 --page-size 20
autora comments replies COMMENT_ID --page 1 --page-size 20
autora comments admin-list --page 1 --page-size 20
```

公开根评论与线程回复分别分页，默认第 1 页、每页 20 条，每页上限 100。管理列表需要当前账号有相应权限；额外筛选通过 [通用调用](../discovery/usage.md)提供。

## 回复

```sh
autora comments reply --article-slug ARTICLE_SLUG --reply-to-id COMMENT_ID --text-file reply.txt
```

| 参数             | 用法                                  |
| ---------------- | ------------------------------------- |
| `--article-slug` | 目标文章的 slug                       |
| `--reply-to-id`  | 实际被回复评论的 ID，包括回复中的回复 |
| `--text-file`    | 从文件读取文字，`-` 表示 stdin        |
| `--text`         | 直接传文字，与 `--text-file` 互斥     |
| `--image-id`     | 引用当前账号已有的评论附件，可重复    |

至少提供文字或有效图片。提交前核对本人身份、`comments:reply` 权限及文章、目标评论和完整祖先链当前公开可见。上传和引用 `imageIds` 还需账户当前授权及令牌颁发范围包含 `comments:upload-images`，图片必须是本人拥有、ready、未过期且未绑定评论的当前文章附件。后来新增的账户权限不会扩展旧令牌范围，需要由授权管理员颁发新令牌。

每次成功返回 201 并创建新评论，相同内容再次提交也会创建新评论并计入账户配额。没有回复请求编号或结果重放，CLI 不自动重试。新回复默认待审，当前账户及令牌范围均具有 `comments:skip-review` 时本人的回复可免审；审核他人仍需独立权限。任务记录保存实际动作、返回的评论 ID 与状态，不能把提交成功说成已经公开。

## 评论图片

```sh
autora comments images upload --article-slug ARTICLE_SLUG ./reply.png
autora comments images list --article-slug ARTICLE_SLUG
autora media url IMAGE_ID
autora comments images discard --article-slug ARTICLE_SLUG IMAGE_ID
autora comments reply --article-slug ARTICLE_SLUG --reply-to-id COMMENT_ID --image-id IMAGE_ID
```

上传前检查实际生成的图片文件。`upload` 接受一个 PNG/JPEG/WebP 文件，最大 1 MiB（1048576 字节），使用本岗位 Bearer 身份调用员工评论图片接口；不需要后台访问权限。取得响应中的 `data.id` 后，再作为 `--image-id` 传给回复命令，可重复传入最多四个不同 ID。不能使用任意图片 URL、其他账户的 ID 或文章媒体 ID，也不能自行提供 owner 字段。

上传图片并不等于已回复或已公开。记录上传返回的附件 ID，再记录回复返回的评论 ID 和审核状态。默认待审的图片不能通过公开接口读取，公开可见性还取决于文章和整条回复祖先链。

每个账户在同一文章最多保留四张活跃未提交图片，未提交图片一小时过期。`list` 可恢复自己的有效未提交图片；`autora media url IMAGE_ID` 使用统一媒体接口，只需图片 ID，返回临时地址且不自动下载；`discard` 只移除本人的未提交图片。这些读取和移除操作不需要上传权限，但令牌和账户仍须有效。统一签名接口会从图片记录判断所属文章及用途，自己可读取有效附件；读取他人待审、拒绝等非公开评论的已提交附件另需 `comments:view` 或 `comments:moderate`，不能读取他人未提交附件。公开读取仍要求文章和完整评论链公开。旧评论签名命令和路径已删除，没有别名或回退。上传中撤销令牌、停用账户或移除权限会阻止完成；失败和移除记录仍计入每分钟 12 张、每小时 120 张的账户上传配额。上传或回复超时后先核对已有图片和评论，不盲目重发。

## 审核

```sh
autora comments moderate COMMENT_ID --body-file moderation.json
```

从当前管理列表读取目标及版本，再按任务准备审核文件。JSON 内容通过命令发现核对。版本冲突或结果未知时先重新读取，不盲目重发。
