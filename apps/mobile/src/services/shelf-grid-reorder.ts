export const SHELF_GRID_COLUMN_COUNT = 3;
export const SHELF_GRID_COLUMN_GAP = 10;
export const SHELF_GRID_ROW_GAP = 12;
export const SHELF_GRID_TITLE_HEIGHT = 36;

export function moveShelfGridItem<T>(
  items: readonly T[],
  from: number,
  to: number,
): T[] {
  const next = [...items];
  const [item] = next.splice(from, 1);
  if (item === undefined) return next;
  next.splice(to, 0, item);
  return next;
}

export function resolveShelfGridTargetIndex(input: {
  itemCount: number;
  localX: number;
  localY: number;
  tileWidth: number;
}): number {
  if (input.itemCount <= 0) return -1;
  const columnWidth = input.tileWidth + SHELF_GRID_COLUMN_GAP;
  const rowHeight = input.tileWidth * 1.5 + SHELF_GRID_TITLE_HEIGHT + SHELF_GRID_ROW_GAP;
  const column = Math.max(
    0,
    Math.min(SHELF_GRID_COLUMN_COUNT - 1, Math.floor(input.localX / columnWidth)),
  );
  const row = Math.max(0, Math.floor(input.localY / rowHeight));
  return Math.max(
    0,
    Math.min(input.itemCount - 1, row * SHELF_GRID_COLUMN_COUNT + column),
  );
}
