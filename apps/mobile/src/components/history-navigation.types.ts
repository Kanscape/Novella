export interface HistoryNavigationProps {
  onClear(): void;
  /** Hide the clear button when there is no history (Flutter behavior). */
  showClear: boolean;
}
