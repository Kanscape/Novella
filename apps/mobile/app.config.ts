import type { ConfigContext, ExpoConfig } from 'expo/config';

const buildNumber = process.env.APP_BUILD_NUMBER;

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: 'Novella',
  slug: 'novella',
  // CI 通过 v* tag 注入 APP_VERSION；本地开发回退到 package.json 版本。
  version: process.env.APP_VERSION || config.version || '2.0.0',
  orientation: 'portrait',
  platforms: ['android', 'ios'],
  scheme: 'novella',
  userInterfaceStyle: 'automatic',
  icon: './assets/icon.png',
  plugins: [
    'expo-router',
    'expo-dev-client',
    './plugins/with-android-signing',
    ['expo-media-library', {
      // Saving does not need read access. iOS uses the add-only permission;
      // Android requests no READ_MEDIA_* granular permission.
      granularPermissions: [],
      photosPermission: false,
      savePhotosPermission: 'Allow Novella to save images to your photo library.',
    }],
    'expo-sharing',
  ],
  extra: {
    // 运行时经 Constants.expoConfig.extra 读取，设置页展示构建渠道与标签。
    buildChannel: process.env.APP_BUILD_CHANNEL ?? 'local',
    buildLabel: process.env.APP_BUILD_LABEL ?? 'Local Build',
  },
  ios: {
    bundleIdentifier: 'sh.celia.novella',
    // CI 注入 BUILD_NUMBER（git rev-list --count，单调递增）。
    buildNumber: buildNumber ?? '1',
    supportsTablet: true,
    // Icon Composer (iOS 26 Liquid Glass) 图标,覆盖顶层 icon。
    icon: './assets/Novella.icon',
  },
  android: {
    adaptiveIcon: {
      backgroundColor: '#FFFFFF',
      backgroundImage: './assets/android-icon-background.png',
      foregroundImage: './assets/android-icon-foreground.png',
      monochromeImage: './assets/android-icon-monochrome.png',
    },
    package: 'sh.celia.novella',
    predictiveBackGestureEnabled: false,
    versionCode: buildNumber ? Number(buildNumber) : 1,
  },
});
