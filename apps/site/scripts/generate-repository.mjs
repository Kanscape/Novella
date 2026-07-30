import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

const siteDataPath = process.env.SITE_DATA_OUTPUT || 'public/site_data.json';
const outputPath = process.env.REPOSITORY_OUTPUT_PATH || 'public/repository.json';
const siteData = JSON.parse(await readFile(siteDataPath, 'utf8'));
const config = {
  appDescription: process.env.REPOSITORY_APP_DESCRIPTION || '基于 React Native 构建的轻小说阅读器，提供纯净的界面和阅读体验。',
  appName: process.env.REPOSITORY_APP_NAME || 'Novella',
  appSubtitle: process.env.REPOSITORY_APP_SUBTITLE || '轻书架第三方客户端',
  bundleIdentifier: process.env.REPOSITORY_BUNDLE_IDENTIFIER || 'sh.celia.novella',
  developerName: process.env.REPOSITORY_DEVELOPER_NAME || 'Kanscape',
  iconPath: process.env.REPOSITORY_ICON_PATH || 'assets/brand/repository-icon.png',
  minOsVersion: process.env.REPOSITORY_MIN_OS_VERSION || '13.0',
  screenshotPaths: (process.env.REPOSITORY_SCREENSHOT_PATHS || 'assets/screenshots/repository-detail-light.png,assets/screenshots/repository-detail-dark.png,assets/screenshots/repository-reader-light.png,assets/screenshots/repository-reader-dark.png,assets/screenshots/repository-settings-light.png,assets/screenshots/repository-settings-dark.png').split(',').map((value) => value.trim()).filter(Boolean),
  sourceIdentifier: process.env.REPOSITORY_IDENTIFIER || 'sh.celia.novella.repository',
  sourceName: process.env.REPOSITORY_NAME || 'Novella Repository',
  sourceSubtitle: process.env.REPOSITORY_SUBTITLE || 'Repository for Novella',
  tintColor: process.env.REPOSITORY_TINT_COLOR || '#f59393',
  siteBasePath: process.env.SITE_BASE_PATH || '/',
  siteUrl: process.env.SITE_URL || 'https://novella.celia.sh',
};
const ipaAsset = selectIpaAsset(siteData.latestRelease.assets);
if (!ipaAsset) throw new Error(`Latest release ${siteData.latestRelease.tagName} does not contain a usable IPA asset.`);

const version = normalizeVersion(siteData.latestRelease);
const repository = {
  name: config.sourceName,
  identifier: config.sourceIdentifier,
  subtitle: config.sourceSubtitle,
  website: config.siteUrl,
  tintColor: config.tintColor,
  featuredApps: [config.bundleIdentifier],
  apps: [{
    name: config.appName,
    bundleIdentifier: config.bundleIdentifier,
    developerName: config.developerName,
    subtitle: config.appSubtitle,
    localizedDescription: config.appDescription,
    iconURL: siteAssetUrl(config.iconPath),
    tintColor: config.tintColor,
    screenshotURLs: config.screenshotPaths.map(siteAssetUrl),
    versions: [{
      version,
      buildVersion: process.env.REPOSITORY_BUILD_VERSION?.trim() || version,
      date: new Date(siteData.latestRelease.publishedAt).toISOString(),
      localizedDescription: siteData.latestRelease.bodyMarkdown?.trim() || siteData.latestRelease.excerpt,
      minOSVersion: config.minOsVersion,
      downloadURL: ipaAsset.url,
      size: ipaAsset.size,
    }],
  }],
  news: [],
};

await mkdir(dirname(outputPath), { recursive: true });
await writeFile(outputPath, `${JSON.stringify(repository, null, 2)}\n`, 'utf8');
console.log(`Generated repository -> ${outputPath}`);

function selectIpaAsset(assets) {
  const ipaAssets = assets.filter((asset) => /\.ipa$/i.test(asset.name) || /\.ipa/i.test(asset.url) || /itunes-ipa|\/ipa/i.test(asset.contentType));
  if (ipaAssets.length === 0) return null;
  const pattern = new RegExp(process.env.REPOSITORY_ASSET_NAME_PATTERN || '\\.ipa$', 'i');
  return ipaAssets.find((asset) => pattern.test(asset.name) || pattern.test(asset.url)) || ipaAssets[0];
}

function normalizeVersion(release) {
  for (const candidate of [release.tagName, release.name]) {
    const match = candidate.match(/(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)/);
    if (match) return match[1];
  }
  return release.tagName.replace(/^v/i, '').trim();
}

function siteAssetUrl(relativePath) {
  const root = new URL(config.siteUrl);
  const segments = [root.pathname, config.siteBasePath, relativePath]
    .map((segment) => segment.trim())
    .filter((segment) => segment && segment !== '/')
    .map((segment) => segment.replace(/^\/+|\/+$/g, ''));
  root.pathname = `/${segments.join('/')}`;
  return root.toString();
}
