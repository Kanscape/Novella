import { NativeModule, requireNativeModule } from 'expo-modules-core';

interface NovellaRsModule extends NativeModule {
  convertWoff2ToTtf(data: Uint8Array): Promise<Uint8Array>;
  extractInvisibleCodepoints(data: Uint8Array): Promise<number[]>;
}

let rsModule: NovellaRsModule | undefined;

function getRsModule(): NovellaRsModule {
  return (rsModule ??= requireNativeModule<NovellaRsModule>('NovellaRs'));
}

export function isNovellaRsAvailable(): boolean {
  try {
    getRsModule();
    return true;
  } catch {
    return false;
  }
}

export function convertWoff2ToTtf(data: Uint8Array): Promise<Uint8Array> {
  return getRsModule().convertWoff2ToTtf(data);
}

export function extractInvisibleCodepoints(data: Uint8Array): Promise<number[]> {
  return getRsModule().extractInvisibleCodepoints(data);
}

