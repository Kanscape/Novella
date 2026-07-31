export interface NativeM3ExpressiveDropdownItem {
  enabled?: boolean;
  label: string;
}

export interface NativeM3ExpressiveDropdownProps {
  enabled?: boolean;
  expanded: boolean;
  items: readonly NativeM3ExpressiveDropdownItem[];
  onExpandedChange?: (expanded: boolean) => void;
  onItemSelected?: (index: number) => void;
  selectedIndex: number;
}

export function NativeM3ExpressiveDropdown(
  _props: NativeM3ExpressiveDropdownProps
): null {
  return null;
}
