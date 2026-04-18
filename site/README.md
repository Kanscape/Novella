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
