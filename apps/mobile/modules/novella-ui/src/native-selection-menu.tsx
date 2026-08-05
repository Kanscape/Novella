export type NativeSelectionMenuIcon =
  | 'books'
  | 'dots'
  | 'equal'
  | 'sparkles'
  | 'tag'
  | 'textSize'
  | 'trophy'
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
  /** Renders the trigger as an icon button instead of the selected-label row. */
  triggerIcon?: NativeSelectionMenuIcon;
}

export function NativeSelectionMenu(_props: NativeSelectionMenuProps): null {
  return null;
}
