import type { ShelfMode } from '@/hooks/use-shelf';

export interface ShelfNavigationProps {
  isSaving: boolean;
  largeTitle: boolean;
  mode: ShelfMode;
  onBack: () => void;
  onManage: () => void;
  onSave: () => void;
  showBack: boolean;
  title: string;
}
