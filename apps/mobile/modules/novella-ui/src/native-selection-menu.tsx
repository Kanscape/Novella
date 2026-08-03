export type NativeSelectionMenuIcon =
  | 'books'
  | 'equal'
  | 'sparkles'
  | 'tag'
  | 'textSize'
  | 'user';

export interface NativeSelectionMenuItem {
  enabled?: boolean;
  icon?: NativeSelectionMenuIcon;
  label: string;
}

export interface NativeSelectionMenuProps {
  enabled?: boolean;
  expanded: boolean;
  items: readonly NativeSelectionMenuItem[];
  onExpandedChange?: (expanded: boolean) => void;
  onItemSelected?: (index: number) => void;
  selectedIndex: number;
}

export function NativeSelectionMenu(_props: NativeSelectionMenuProps): null {
  return null;
}
