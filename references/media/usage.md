# 媒体命令

```sh
autora media upload ./article-image.png
autora media url MEDIA_ID
```

`upload` 接收真实图片文件路径，用于上传文章图片，支持 PNG/JPEG/WebP、最大 10 MiB。返回结果中取得媒体 `id`，文章正文只写入 `<MdxImage mediaId="图片ID" />`，可附加固定值的 `alt`、`title`、`width`、`height`。`mediaId` 是引号包裹的 32 位小写十六进制 ID；不要写入临时 URL、对象 key 或 `src`。

保存文章时必须显式提交正文的 `mediaIds` 数组和独立的 `coverMediaId`：纯文字正文传 `mediaIds: []`，默认封面传 `coverMediaId: null`；自定义封面传已上传的文章图片 ID。不要把代码示例中的 ID 加入正文数组。后端按正文 ID 与封面 ID 的去重并集授权关联，不解析正文，不补足遗漏字段；同时提交空数组和 null 清除全部图片关联。详见[文章命令](../articles/usage.md)。

上传需要当前账号与令牌范围同时允许 `articles:write` 或 `articles:write-own`。本人文章权限也可上传自己的文章图片；后端分别检查图片归属与文章关联授权，不能借上传修改他人的文章。

`url` 通过统一的 `/api/v1/admin/media/{id}/url` 为当前账号有权访问的文章图片、评论附件等媒体取得临时访问地址，只需要媒体 ID；它不会自动下载图片。自己的有效评论附件不要求额外上传权限；他人的非公开已提交评论附件需要 `comments:view` 或 `comments:moderate`，不能读取他人的未提交附件。后台浏览器和 Bearer 仍遵守各自身份、范围和当前授权检查。长期引用只保存媒体 ID，临时地址过期时重新获取。签名统一返回 `id`、`url` 和 `expiresAt`；尺寸继续取上传或评论数据。

文章图片与评论附件不同，`media upload` 不能创建评论附件。使用 [评论图片命令](../comments/usage.md)中的 `autora comments images upload --article-slug SLUG FILE` 创建评论附件，最大 1 MiB（1048576 字节）。评论回复的 `--image-id` 只能引用当前账号拥有的有效评论附件。
