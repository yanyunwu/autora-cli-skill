# 文章命令

## 读取

```sh
autora articles list --page 1 --page-size 20
autora articles get ARTICLE_SLUG
autora articles admin-list --page 1 --page-size 20
autora articles admin-get ARTICLE_ID
```

`list/get` 读取公开文章；`admin-list/admin-get` 读取当前账号有权访问的管理内容。公开详情用 slug，管理详情用 ID。列表默认第 1 页、每页 20 条，可用 `--page`、`--page-size` 显式翻页，每页上限 100。

`articles:view-own` 只允许读取本人文章的管理内容，`articles:view` 可读取全站管理文章。管理响应可能包含当前对象的 `canEdit`、`canPublish` 和 `canDelete`；公开响应不返回这些字段。先核对当前身份与这些能力，服务端仍会在实际操作时重验授权。

## 写入

```sh
autora articles create --body-file draft.json
autora articles update ARTICLE_ID --body-file update.json
autora articles publication ARTICLE_ID --body-file publication.json
```

输入文件内容通过 [命令发现](../discovery/usage.md)准备；`--body-file -` 可改为 stdin。创建默认是草稿；需要直接发布时，按 schema 显式提供 `publicationStatus: "published"` 并核对发布权限。已有文章的单独状态变更使用 `publication`。

草稿的标题、地址、摘要、正文和分类可留空。新建未填地址时生成稳定唯一地址；编辑留空时保留原地址。草稿、已发布和归档文章都可无分类；保存时分类传 null、空值或省略均表示不设置分类，不会自动选择或创建分类。最小草稿请求为 `{"mediaIds":[],"coverMediaId":null}`；更新仍需 `expectedRevision`。发布前必须补齐非空标题、摘要和正文。

文章配图先通过 `autora media upload FILE` 上传，再在 `body` 中插入 `<MdxImage mediaId="上传返回的图片ID" alt="图片说明" />`。正文保存图片 ID，展示时统一获取临时 URL；不要把签名链接、对象 key 或旧图片路径写进正文。

每次 `create/update` 都必须提交 `mediaIds` 数组，声明最终正文要关联的图片 ID；没有正文配图时也必须传 `[]`。字段遗漏、null、重复或格式错误都会被拒绝，后端不会解析正文或自动保留旧关联。正文示例和代码块中的 ID 不应加入数组。图片仍逐个检查归属、ready 状态和引用权限，声明 ID 不会授予访问权。

每次保存还必须明确提交 `coverMediaId`：使用已上传的文章图片 ID 设置独立封面，或 `null` 使用默认插画；编辑时遗漏该字段会报错，空字符串无效。封面不会从正文第一张图推断，也不要求出现在正文中。实际图片关联为 `mediaIds` 与封面 ID 的去重并集；管理读取返回该并集和独立封面 ID，编辑时按最终正文重新声明 `mediaIds`。`mediaIds: []` 仍保留本次指定的封面；同时提交 `coverMediaId: null` 才会清除全部图片关联。

例如正文为 `<MdxImage mediaId="0123456789abcdef0123456789abcdef" alt="配图" />` 且使用默认封面时，完整文章输入中的 `mediaIds` 应为 `["0123456789abcdef0123456789abcdef"]`，`coverMediaId` 应为 `null`。先用 `autora schema post_admin_articles` 或 `autora schema put_admin_articles_id` 查看其他必填字段。

所有岗位初始具备本人文章的查看、创建编辑、发布撤回和删除权限。`articles:write-own` 与 `articles:publish-own` 只作用于当前账号自己的文章；对应全站权限保留全站范围。创建时作者由后端绑定当前账号，不在请求中传入作者或所有者身份。

编辑或改变发布状态前用 `admin-get` 读取当前记录与版本。编辑已发布文章时，按可信任务在更新输入中显式指定 `publicationStatus: "draft"`（退回草稿）或 `publicationStatus: "published"`（直接发布）；文章修改和状态变更一次保存。冲突时读取并核对新内容，不盲目覆盖。

`create` 不自动生成幂等键；响应丢失时先查询确认是否已经创建，再决定是否重发。执行后读取目标核实实际结果。

## 归档和永久删除

归档保留文章，状态可再改回 `draft` 或 `published`。先读取当前版本，再通过发布状态操作提交；将示例中的 `7` 替换为刚读取的 `revision`：

```sh
autora articles admin-get ARTICLE_ID
autora articles publication ARTICLE_ID --body-file - <<'JSON'
{"status":"archived","expectedRevision":7}
JSON
```

永久删除使用通用调用，删除后无法通过文章状态操作恢复：

```sh
autora schema delete_admin_articles_id
autora articles admin-get ARTICLE_ID
autora call delete_admin_articles_id --path id=ARTICLE_ID --query expectedRevision=7
```

永久删除需要 `articles:delete`，或对本人文章有效的 `articles:delete-own`；归档和恢复使用发布权限。版本不符返回 409，重新读取并核对变化后再决定是否继续。CLI 不自动重试，超时后先核实结果。
