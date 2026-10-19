# 文章命令

## 读取

```sh
autora articles list --page 1 --page-size 20
autora articles get ARTICLE_SLUG
autora articles admin-list --page 1 --page-size 20
autora articles admin-get ARTICLE_ID
```

`list/get` 读取公开文章；`admin-list/admin-get` 读取当前账号有权访问的管理内容。公开详情用 slug，管理详情用 ID。列表默认第 1 页、每页 20 条，可用 `--page`、`--page-size` 显式翻页，每页上限 100。

`articles:view-own` 只允许读取本人文章的管理内容，`articles:view` 可读取全站管理文章。管理响应可能包含当前对象的 `canEdit`、`canPublish`、`canDelete`、`canGlobalPin` 和 `canPersonalPin`；公开响应不返回这些能力字段。先核对当前身份与这些能力，服务端仍会在实际操作时重验授权。

## 首页栏目

首页栏目使用单独的读取接口，普通文章列表仍按发布时间排列：

```sh
autora schema get_blog_home_articles
autora call get_blog_home_articles --query tab=hot --query page=1 --query pageSize=8
```

`tab` 支持 `hot`（默认）、`latest` 和 `activity`。最热统计全部已发布文章在最近 72 小时内的浏览次数，同热度时较新发布的在前；旧文章也可上榜，零浏览文章仍可展示。历史无时间戳的浏览仅保留在累计浏览量中，不推算为近期热度。最新按发布时间排列；活动按已有标签名“活动”精确筛选，较新发布的在前，没有该标签时返回空的普通列表。

响应中的 `pinned` 是当前已发布的全局置顶文章，三个栏目都返回，最近置顶的靠前，不要求有活动标签。`items` 和 `total` 仅统计未全局置顶的普通文章；每页默认 8 篇，置顶不占分页名额。`publishedTotal` 是全站当前已发布数量。个人置顶不影响首页排序。

继续加载时保留首次响应的 `asOf` 和栏目、页大小，只增加页码。将 `AS_OF` 替换为刚返回的时间字符串：

```sh
autora call get_blog_home_articles --query tab=hot --query page=2 --query pageSize=8 --query asOf=AS_OF
```

快照固定热度窗口和新发布文章的截止时间；当前撤回、删除、置顶和标签变动仍即时生效。CLI 每次读取一页，不自动遍历全部文章。

## 全局置顶与个人置顶

`globalPinnedAt` 和 `personalPinnedAt` 是独立状态，未置顶时为 null。全局置顶只用于首页，个人置顶只用于作者个人主页；文章内容更新不会清除任何一种置顶。草稿、归档文章可以保留置顶状态，只有发布后公开展示。置顶不通过普通文章保存接口设置。

全局置顶需要独立的 `articles:pin` 权限，账户当前授权和令牌原始范围都必须允许；本人文章的编辑或发布权限不能代替它。个人置顶不新增权限点，只允许当前账号操作存储作者为自己的文章，即使拥有 `*` 也不能替他人设置个人置顶。

先读取管理文章的当前版本与逐篇能力，再发现相应操作。将示例中的 ID 与版本号替换为实际值；取消置顶时提交 `pinned: false`：

```sh
autora articles admin-get ARTICLE_ID
autora schema put_admin_articles_id_global-pin
autora call put_admin_articles_id_global-pin --path id=ARTICLE_ID --body-file - <<'JSON'
{"pinned":true,"expectedRevision":7}
JSON
```

个人置顶使用同样的输入格式，操作 ID 为 `put_admin_articles_id_personal-pin`。`put_user_articles_id_personal-pin` 是网页会话专用接口，可发现但不能由 CLI 调用；CLI 使用支持 Bearer 的管理接口，不需要管理员浏览器访问权限。

成功响应仅返回 `id`、本次确认的 `revision` 和两个置顶时间，不返回文章正文。接下来的写入使用刚确认的版本；同状态操作不改变版本、时间或审计记录，旧版本即使同状态也返回 409。遇到冲突先重新读取核对；请求结果未知时先确认实际状态，不盲目重发。

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

## 正文、代码与参考链接

`body` 是受限 MDX 字符串，支持 Markdown、行内代码、代码围栏和已注册组件。行内代码用反引号包裹；多行代码用三反引号围栏，并在开头标注语言，例如 `typescript`、`javascript`、`python`、`go`、`rust`、`json`、`bash` 或 `sql`。纯文本可用 `text`，未知语言按纯文本显示。文章页面与编辑器预览统一提供语言标签、明暗主题高亮和复制按钮。

代码示例中的花括号、尖括号、`import` 等放在行内代码或代码围栏中，按文本展示。代码块之外不能插入脚本、`import`、`export`、任意 JavaScript 表达式或未注册的 JSX 组件。正文上限为 50000 个 UTF-8 字节。

将下面内容保存为 `draft.json`，再用 `autora articles create --body-file draft.json` 提交。JSON 中用 `\n` 表示正文换行；通过文件或 stdin 传输，避免 shell 解释反引号、引号或代码内容。

````json
{
  "title": "代码与文字一起说明问题",
  "summary": "展示行内代码、TypeScript 代码块和正文参考链接。",
  "body": "行内代码：`answer`。\n\n```typescript\nconst answer: number = 42;\nconsole.log(answer);\n```\n\n[参考资料](https://example.com/docs)",
  "categoryId": null,
  "mediaIds": [],
  "coverMediaId": null
}
````

参考资料直接写成正文中的 Markdown 链接，也可以在正文末尾列出。独立的 `sources` 字段已移除，创建或更新时不再提交来源数组。代码块仍属于 `body`，更新时沿用 `articles update ARTICLE_ID`，提交刚读取的 `expectedRevision`。

文章配图的 2 MiB 上传限制、`MdxImage` 写法和 `mediaIds` 声明规则沿用上文；图片全屏查看与签名续期由网页处理。CLI 每次显式命令提交一次，不自动保存；创建得到 ID 后，后续修改更新该文章，避免重复 `create`。

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
