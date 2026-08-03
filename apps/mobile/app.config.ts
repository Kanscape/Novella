import type { ConfigContext, ExpoConfig } from 'expo/config';

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: 'Novella',
  slug: 'novella',
  version: '2.0.0',
  orientation: 'portrait',
  platforms: ['android', 'ios'],
  scheme: 'novella',
  userInterfaceStyle: 'automatic',
  icon: './assets/icon.png',
  plugins: ['expo-router', 'expo-dev-client'],
  ios: {
    bundleIdentifier: 'sh.celia.novella',
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
  },
});
