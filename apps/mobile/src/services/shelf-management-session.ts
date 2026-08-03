import { useSyncExternalStore } from 'react';

export interface ShelfManagementCommand {
  destructive?: boolean;
  icon: 'check' | 'folderPlus' | 'pointer' | 'select' | 'trash' | 'x';
  id: string;
  label: string;
}

interface ShelfManagementSession {
  commands: ShelfManagementCommand[];
  onCommand: (id: string) => void;
  title: string;
}

let session: ShelfManagementSession | null = null;
const listeners = new Set<() => void>();

export function openShelfManagementSession(next: ShelfManagementSession) {
  session = next;
  publish();
}

export function closeShelfManagementSession() {
  session = null;
  publish();
}

export function runShelfManagementCommand(id: string) {
  session?.onCommand(id);
}

export function useShelfManagementSession() {
  return useSyncExternalStore(subscribe, () => session, () => session);
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function publish() {
  for (const listener of listeners) listener();
}
