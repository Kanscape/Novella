import { useEffect, useSyncExternalStore } from 'react';

import { createExpoStorage } from '@/adapters/expo-runtime';
import {
  DEFAULT_THEME_SEED,
  isMaterialSchemeVariant,
  isThemeSeed,
  type MaterialSchemeVariant,
} from '@/theme/material-theme';

export type ReaderViewMode = 'paged' | 'scroll';
export type ThemeMode = 'system' | 'light' | 'dark';
export type TranslationMode = 'none' | 't2s' | 's2t';

export interface AppSettings {
  bookDetailCacheEnabled: boolean;
  coverColorExtraction: boolean;
  dynamicSchemeVariant: MaterialSchemeVariant;
  fontCacheEnabled: boolean;
  fontCacheLimit: number;
  fontSize: number;
  ignoreAI: boolean;
  ignoreJapanese: boolean;
  ignoreLevel6: boolean;
  oledBlack: boolean;
  readerFirstLineIndent: boolean;
  readerImagePreviewOpenOnLongPress: boolean;
  readerLineHeight: number;
  readerPagedNoAnimation: boolean;
  readerSidePadding: number;
  readerViewMode: ReaderViewMode;
  seedColorValue: string;
  theme: ThemeMode;
  useSystemColor: boolean;
  convertType: TranslationMode;
  autoCheckUpdate: boolean;
  telemetryDiagnosticsEnabled: boolean;
}

const DEFAULT_SETTINGS: AppSettings = {
  bookDetailCacheEnabled: true,
  coverColorExtraction: false,
  dynamicSchemeVariant: 'tonalSpot',
  fontCacheEnabled: true,
  fontCacheLimit: 30,
  fontSize: 18,
  ignoreAI: false,
  ignoreJapanese: false,
  ignoreLevel6: true,
  oledBlack: false,
  readerFirstLineIndent: false,
  readerImagePreviewOpenOnLongPress: false,
  readerLineHeight: 1.6,
  readerPagedNoAnimation: false,
  readerSidePadding: 30,
  readerViewMode: 'paged',
  seedColorValue: DEFAULT_THEME_SEED,
  theme: 'system',
  useSystemColor: process.env.EXPO_OS === 'android',
  convertType: 'none',
  autoCheckUpdate: true,
  telemetryDiagnosticsEnabled: true,
};

const SETTINGS_KEY = 'novella.settings.v1';
const storage = createExpoStorage();
const listeners = new Set<() => void>();
let snapshot: AppSettings = DEFAULT_SETTINGS;
let loadPromise: Promise<void> | null = null;
let writePromise = Promise.resolve();

export function useAppSettings(): AppSettings {
  const value = useSyncExternalStore(subscribe, getSnapshot, getSnapshot);

  useEffect(() => {
    void loadAppSettings();
  }, []);

  return value;
}

export function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function getSnapshot(): AppSettings {
  return snapshot;
}

export async function loadAppSettings(): Promise<void> {
  if (!loadPromise) {
    loadPromise = storage
      .get(SETTINGS_KEY)
      .then((encoded) => {
        if (!encoded) return;
        try {
          snapshot = decodeSettings(JSON.parse(encoded));
          publish();
        } catch {
          // Invalid local settings should not prevent the app from starting.
        }
      })
      .finally(() => {
        loadPromise = null;
      });
  }
  await loadPromise;
}

export async function updateAppSettings(
  patch: Partial<AppSettings>,
): Promise<void> {
  await loadAppSettings();
  snapshot = { ...snapshot, ...patch };
  publish();
  const nextWrite = writePromise.then(() => storage.set(SETTINGS_KEY, JSON.stringify(snapshot)));
  writePromise = nextWrite.catch(() => undefined);
  await nextWrite;
}

function publish(): void {
  for (const listener of listeners) listener();
}

function decodeSettings(value: unknown): AppSettings {
  if (!value || typeof value !== 'object') return DEFAULT_SETTINGS;
  const candidate = value as Record<string, unknown>;
  return {
    ...DEFAULT_SETTINGS,
    ...(typeof candidate.bookDetailCacheEnabled === 'boolean'
      ? { bookDetailCacheEnabled: candidate.bookDetailCacheEnabled }
      : {}),
    ...(typeof candidate.coverColorExtraction === 'boolean'
      ? { coverColorExtraction: candidate.coverColorExtraction }
      : {}),
    ...(isMaterialSchemeVariant(candidate.dynamicSchemeVariant)
      ? { dynamicSchemeVariant: candidate.dynamicSchemeVariant }
      : {}),
    ...(typeof candidate.fontCacheEnabled === 'boolean'
      ? { fontCacheEnabled: candidate.fontCacheEnabled }
      : {}),
    ...(typeof candidate.fontCacheLimit === 'number'
      ? { fontCacheLimit: clamp(candidate.fontCacheLimit, 10, 60) }
      : {}),
    ...(typeof candidate.fontSize === 'number'
      ? { fontSize: clamp(candidate.fontSize, 12, 32) }
      : {}),
    ...(typeof candidate.ignoreAI === 'boolean' ? { ignoreAI: candidate.ignoreAI } : {}),
    ...(typeof candidate.ignoreJapanese === 'boolean'
      ? { ignoreJapanese: candidate.ignoreJapanese }
      : {}),
    ...(typeof candidate.ignoreLevel6 === 'boolean'
      ? { ignoreLevel6: candidate.ignoreLevel6 }
      : {}),
    ...(typeof candidate.oledBlack === 'boolean' ? { oledBlack: candidate.oledBlack } : {}),
    ...(typeof candidate.readerFirstLineIndent === 'boolean'
      ? { readerFirstLineIndent: candidate.readerFirstLineIndent }
      : {}),
    ...(typeof candidate.readerImagePreviewOpenOnLongPress === 'boolean'
      ? { readerImagePreviewOpenOnLongPress: candidate.readerImagePreviewOpenOnLongPress }
      : {}),
    ...(typeof candidate.readerLineHeight === 'number'
      ? { readerLineHeight: clamp(candidate.readerLineHeight, 1, 2.5) }
      : {}),
    ...(typeof candidate.readerPagedNoAnimation === 'boolean'
      ? { readerPagedNoAnimation: candidate.readerPagedNoAnimation }
      : {}),
    ...(typeof candidate.readerSidePadding === 'number'
      ? { readerSidePadding: clamp(candidate.readerSidePadding, 12, 64) }
      : {}),
    ...(candidate.readerViewMode === 'paged' || candidate.readerViewMode === 'scroll'
      ? { readerViewMode: candidate.readerViewMode }
      : {}),
    ...(isThemeSeed(candidate.seedColorValue)
      ? { seedColorValue: candidate.seedColorValue.toUpperCase() }
      : {}),
    ...(candidate.theme === 'system' || candidate.theme === 'light' || candidate.theme === 'dark'
      ? { theme: candidate.theme }
      : {}),
    ...(typeof candidate.useSystemColor === 'boolean'
      ? { useSystemColor: candidate.useSystemColor }
      : {}),
    ...(candidate.convertType === 'none' || candidate.convertType === 't2s' || candidate.convertType === 's2t'
      ? { convertType: candidate.convertType }
      : {}),
    ...(typeof candidate.autoCheckUpdate === 'boolean'
      ? { autoCheckUpdate: candidate.autoCheckUpdate }
      : {}),
    ...(typeof candidate.telemetryDiagnosticsEnabled === 'boolean'
      ? { telemetryDiagnosticsEnabled: candidate.telemetryDiagnosticsEnabled }
      : {}),
  };
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
