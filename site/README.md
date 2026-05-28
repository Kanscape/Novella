# Novella Site

Novella 官网静态站，基于 Jaspr `static` 模式构建，通过 GitHub Actions 部署到 Cloudflare Pages。

## 本地开发

1. 安装 Jaspr CLI

```bash
fvm dart pub global activate jaspr_cli
```

2. 安装依赖

```bash
npm install
fvm dart pub get
```

3. 拉取 GitHub 数据（必须，无 mock 数据回退）

```bash
export GITHUB_TOKEN=your_token
fvm dart run tool/fetch_site_data.dart
```

4. 构建 CSS

```bash
npx @tailwindcss/cli -i src/input.css -o web/styles.css --minify
```

5. 启动开发服务器

```bash
fvm dart pub global run jaspr_cli:jaspr serve
```

6. 生成 Repository 清单

```bash
fvm dart run tool/generate_repository.dart
```

## 应用公告

应用公告放在 `web/assets/announcements/*.md`。部署 workflow 会在构建前执行：

```bash
dart run tool/generate_announcements.dart
```

该命令会读取公告 Markdown 的 front matter，并生成 `web/assets/announcements/index.json`。新增或修改公告 `.md` 后不需要手动编辑 `index.json`。

`index.json` 是部署时生成的文件，不提交到仓库。本地需要检查生成结果时执行上面的命令即可。

公告示例：

```markdown
---
id: 2026-05-28-required-migration
title: 重要公告
publishedAt: 2026-05-28T00:00:00Z
summary: 这是一条需要阅读的应用公告。
required: true
requiredReadSeconds: 8
completionAction: openAbout
---

# 重要公告

正文内容。
```

字段说明：

- `id` 可省略，省略时使用文件名。
- `title` 可省略，省略时使用正文第一个一级标题。
- `publishedAt` 可省略，但文件名必须包含 `YYYY-MM-DD`。
- `required` 只有为 `true` 时才会触发应用内强制阅读。
- `completionAction: openAbout` 会让“我已阅读”跳转到关于页面。

## 构建

```bash
fvm dart pub global run jaspr_cli:jaspr build --sitemap-domain https://novella.celia.sh
```

如果你刚切完 FVM 版本，先在仓库根目录执行一次 `fvm use`，再进入 `site/` 目录。

常用环境变量：

- `GITHUB_REPOSITORY`，默认 `Kanscape/Novella`
- `GITHUB_TOKEN`，必需，构建期读取 GitHub API
- `SITE_URL`，默认 `https://novella.celia.sh`
- `SITE_BASE_PATH`，默认 `/`
- `SITE_DATA_PATH`，默认 `.generated/site_data.json`
- `REPOSITORY_OUTPUT_PATH`，默认 `build/jaspr/repository.json`
- `REPOSITORY_NAME`，默认 `Novella Repository`
- `REPOSITORY_SUBTITLE`，默认 `Repository for Novella`
- `REPOSITORY_ASSET_NAME_PATTERN`，默认 `\.ipa$`
- `REPOSITORY_BUILD_VERSION`，默认跟 release 版本号一致
- `REPOSITORY_ICON_PATH`，默认 `assets/brand/repository-icon.png`
- `REPOSITORY_SCREENSHOT_PATHS`，逗号分隔，默认使用站点内置的 6 张 Repository 截图
