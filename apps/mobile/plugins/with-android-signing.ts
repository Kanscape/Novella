import { withAppBuildGradle } from '@expo/config-plugins';
import type { ConfigPlugin } from '@expo/config-plugins';

/**
 * Android release 签名控制（行处理 android/app/build.gradle）。
 *
 * - 签名构建（CI 签名 job，KEYSTORE_FILE 等环境变量存在）：
 *   在 signingConfigs 块内补 release 块，并把 release buildType 的签名指向 release。
 * - 免签构建（本地开发、PR，无相关环境变量）：
 *   删除 release buildType 的 signingConfig 行，产物为真正未签名的
 *   app-release-unsigned.apk（RN 模板默认用 debug 密钥签 release，必须移除）。
 */
const withAndroidSigning: ConfigPlugin = (config) => {
  return withAppBuildGradle(config, (cfg) => {
    const keystoreFile = process.env.KEYSTORE_FILE;
    const storePassword = process.env.KEYSTORE_PASSWORD;
    const keyAlias = process.env.KEY_ALIAS;
    const keyPassword = process.env.KEY_PASSWORD;
    const hasSigning = !!(keystoreFile && storePassword && keyAlias && keyPassword);

    const escapeGradle = (value: string) => value.replace(/\\/g, '\\\\').replace(/'/g, "\\'");

    const lines = cfg.modResults.contents.split('\n');

    // 1) signingConfigs 块：签名构建时补 release 块。
    const signingIndex = lines.findIndex((line) => line.trim() === 'signingConfigs {');
    if (hasSigning && signingIndex >= 0 && !lines.some((line) => line.includes('signingConfigs.release'))) {
      const indent = (lines[signingIndex] ?? '').match(/^\s*/)?.[0] ?? '';
      lines.splice(
        signingIndex + 1,
        0,
        `${indent}    release {`,
        `${indent}        storeFile file('${escapeGradle(keystoreFile!)}')`,
        `${indent}        storePassword '${escapeGradle(storePassword!)}'`,
        `${indent}        keyAlias '${escapeGradle(keyAlias!)}'`,
        `${indent}        keyPassword '${escapeGradle(keyPassword!)}'`,
        `${indent}    }`,
      );
    }

    // 2) buildTypes 内的 release 块：签名构建指向 release，免签构建移除签名。
    const buildTypesIndex = lines.findIndex((line) => line.trim() === 'buildTypes {');
    const releaseIndex =
      buildTypesIndex >= 0
        ? lines.findIndex((line, i) => i > buildTypesIndex && /^\s*release\s*\{$/.test(line))
        : -1;
    if (releaseIndex >= 0) {
      if (hasSigning) {
        let found = false;
        for (let i = releaseIndex + 1; i < lines.length; i++) {
          if ((lines[i] ?? '').includes('signingConfig signingConfigs.')) {
            lines[i] = (lines[i] ?? '').replace('signingConfig signingConfigs.debug', 'signingConfig signingConfigs.release');
            found = true;
            break;
          }
        }
        if (!found) {
          const indent = (lines[releaseIndex] ?? '').match(/^\s*/)?.[0] ?? '';
          lines.splice(releaseIndex + 1, 0, `${indent}    signingConfig signingConfigs.release`);
        }
      } else {
        for (let i = releaseIndex + 1; i < lines.length; i++) {
          if ((lines[i] ?? '').includes('signingConfig signingConfigs.')) {
            lines.splice(i, 1);
            break;
          }
        }
      }
    }

    cfg.modResults.contents = lines.join('\n');
    return cfg;
  });
};

export default withAndroidSigning;
