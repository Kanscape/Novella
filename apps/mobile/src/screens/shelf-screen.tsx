import { usePreventRemove } from 'expo-router/react-navigation';
import {
  IconAlertTriangle,
  IconBook2,
  IconCheck,
  IconFolderOpen,
  IconGripVertical,
  IconX,
} from '@tabler/icons-react-native';
import { router, useNavigation } from 'expo-router';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  BackHandler,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import type { BookListItem, ShelfItem } from '@novella/api-client';
import {
  getShelfFolderPaths,
  getShelfItemsAtPath,
  getShelfSelectionBookCount,
  shelfItemKey,
  type ShelfDraft,
  type ShelfItemKey,
  type ShelfSnapshot,
} from '@novella/client-core';

import type { NativeTopAppBarAction } from '../../modules/novella-ui';

import {
  BOOK_COVER_ASPECT_RATIO,
  BookCoverGridItem,
} from '@/components/book-cover-grid-item';
import { ShelfFolderGridItem } from '@/components/shelf-grid-item';
import {
  BookCoverSkeletonTile,
  bookGridSkeletonCount,
  skeletonKeys,
} from '@/components/book-grid-skeleton';
import { ShelfNavigation } from '@/components/shelf-navigation';
import {
  ReorderableShelfGrid,
  type ReorderableShelfGridItemState,
} from '@/components/reorderable-shelf-grid';
import { NativeScreenScaffold } from '@/components/native-screen-scaffold';
import { SectionCard } from '@/components/section-card';
import { useBookGridLayout, BOOK_GRID_COLUMN_GAP } from '@/hooks/use-book-grid-layout';
import { useShelf, type ShelfMode } from '@/hooks/use-shelf';
import { closeShelfManagementSession, openShelfManagementSession } from '@/services/shelf-management-session';
import { colors } from '@/theme/colors';

export function ShelfScreen({ parents = [] }: { parents?: string[] }) {
  const navigation = useNavigation();
  const {
    beginEdit,
    cancelEdit,
    clearEditorError,
    createFolder,
    deleteFolder,
    editorError,
    ensureDraft,
    error,
    isDirty,
    isLoading,
    isRefreshing,
    isSaving,
    mode,
    moveBooks,
    reload,
    removeItems,
    renameFolder,
    reorderSiblings,
    saveEdit,
    snapshot,
  } = useShelf();
  const [selectedKeys, setSelectedKeys] = useState<Set<ShelfItemKey>>(new Set());
  const [interactionMode, setInteractionMode] = useState<'browse' | 'drag' | 'select'>('browse');
  const scrollViewRef = useRef<ScrollView>(null);
  const scrollOffsetRef = useRef(0);
  const viewportHeightRef = useRef(0);

  const visibleItems = useMemo(
    () => snapshot ? getShelfItemsAtPath(toDraft(snapshot), parents) : [],
    [parents, snapshot],
  );
  const selectedItems = useMemo(
    () => visibleItems.filter((item) => selectedKeys.has(shelfItemKey(item))),
    [selectedKeys, visibleItems],
  );
  const selectedBooks = selectedItems.filter(
    (item): item is Extract<ShelfItem, { type: 'BOOK' }> => item.type === 'BOOK',
  );
  const selectedFolders = selectedItems.filter(
    (item): item is Extract<ShelfItem, { type: 'FOLDER' }> => item.type === 'FOLDER',
  );
  const moveDestinations = useMemo(
    () => snapshot ? getMoveDestinations(snapshot, parents) : [],
    [parents, snapshot],
  );
  const selectedBookImpact = snapshot
    ? getShelfSelectionBookCount(toDraft(snapshot), selectedKeys)
    : 0;
  const title = getNavigationTitle(
    snapshot,
    parents,
    mode,
    selectedBookImpact,
    selectedItems.length > 0,
  );

  useEffect(() => {
    const visibleKeys = new Set(visibleItems.map(shelfItemKey));
    setSelectedKeys((current) => {
      const next = new Set([...current].filter((key) => visibleKeys.has(key)));
      return setsEqual(current, next) ? current : next;
    });
  }, [visibleItems]);

  useEffect(() => {
    if (mode !== 'browse') return;
    setSelectedKeys(new Set());
  }, [mode]);

  const discardEdit = useCallback(() => {
    setSelectedKeys(new Set());
    cancelEdit();
  }, [cancelEdit]);

  const requestCancelEdit = useCallback(() => {
    if (!isDirty) {
      discardEdit();
      return;
    }
    Alert.alert(
      'Discard shelf changes?',
      'Your unsaved folder, move, delete, and ordering changes will be lost.',
      [
        { text: 'Keep editing', style: 'cancel' },
        { text: 'Discard', style: 'destructive', onPress: discardEdit },
      ],
    );
  }, [discardEdit, isDirty]);

  usePreventRemove(isDirty, ({ data }) => {
    Alert.alert(
      'Discard shelf changes?',
      'Save or discard your shelf draft before leaving.',
      [
        { text: 'Keep editing', style: 'cancel' },
        {
          text: 'Discard',
          style: 'destructive',
          onPress: () => {
            discardEdit();
            requestAnimationFrame(() => navigation.dispatch(data.action));
          },
        },
      ],
    );
  });

  const handleBack = useCallback(() => {
    if (router.canGoBack()) router.back();
    else router.replace('/(tabs)/(shelf)/shelf');
  }, [mode, requestCancelEdit]);

  useEffect(() => {
    const subscription = BackHandler.addEventListener('hardwareBackPress', () => {
      if (parents.length > 0) {
        handleBack();
        return true;
      }
      return false;
    });
    return () => subscription.remove();
  }, [handleBack, mode, parents.length]);

  const openFolder = useCallback((folderId: string) => {
    router.push({
      pathname: '/shelf/folder',
      params: { path: JSON.stringify([...parents, folderId]) },
    });
  }, [parents]);

  const beginDrag = useCallback(() => interactionMode === 'drag' && ensureDraft(), [ensureDraft, interactionMode]);

  const handleSave = useCallback(async () => {
    if (await saveEdit()) setSelectedKeys(new Set());
  }, [saveEdit]);

  const handleDelete = useCallback(() => {
    const keys = new Set(selectedKeys);
    const containsFolders = selectedFolders.length > 0;
    Alert.alert(
      'Delete selected items?',
      containsFolders
        ? 'Selected books will be removed. Books inside deleted folders will be moved to the shelf root.'
        : 'The selected books will be removed from your shelf.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => {
            if (!ensureDraft()) return;
            const bookKeys = new Set(
              [...keys].filter((key) => !selectedFolders.some((folder) => shelfItemKey(folder) === key)),
            );
            if (bookKeys.size > 0) removeItems(bookKeys);
            for (const folder of selectedFolders) deleteFolder(folder.id);
            setSelectedKeys(new Set());
          },
        },
      ],
    );
  }, [deleteFolder, ensureDraft, removeItems, selectedFolders, selectedKeys]);

  const openManage = useCallback(() => {
    const commands = [
      { icon: 'pointer' as const, id: 'browse', label: interactionMode === 'browse' ? 'Browsing' : 'Browse normally' },
      { icon: 'pointer' as const, id: 'drag', label: interactionMode === 'drag' ? 'Long-press drag enabled' : 'Long-press to drag' },
      { icon: 'select' as const, id: 'select', label: interactionMode === 'select' ? 'Selecting items' : 'Select items' },
      { icon: 'folderPlus' as const, id: 'create', label: 'New folder' },
      ...(selectedFolders.length === 1 && selectedBooks.length === 0
        ? [{ icon: 'select' as const, id: 'rename', label: 'Rename selected folder' }]
        : []),
      ...(selectedBooks.length > 0 && selectedFolders.length === 0
        ? moveDestinations.map((destination, index) => ({
            icon: 'folderPlus' as const,
            id: `move:${index}`,
            label: `Move to ${destination.label}`,
          }))
        : []),
      ...(selectedKeys.size > 0
        ? [{ destructive: true, icon: 'trash' as const, id: 'delete', label: 'Delete selected items' }]
        : []),
      ...(isDirty
        ? [
            { icon: 'check' as const, id: 'save', label: 'Save changes' },
            { destructive: true, icon: 'x' as const, id: 'discard', label: 'Discard changes' },
          ]
        : []),
    ];

    openShelfManagementSession({
      commands,
      title: 'Manage shelf',
      onCommand: (id) => {
        if (id === 'browse' || id === 'drag' || id === 'select') {
          setInteractionMode(id);
          if (id !== 'select') setSelectedKeys(new Set());
        } else if (id === 'create') {
          Alert.prompt('New folder', 'Enter a folder name.', (title) => {
            if (title.trim() && ensureDraft()) createFolder(title);
          });
        } else if (id === 'rename') {
          const folder = selectedFolders[0];
          if (folder) Alert.prompt('Rename folder', undefined, (title) => {
            if (title.trim() && ensureDraft()) renameFolder(folder.id, title);
          }, 'plain-text', folder.title);
        } else if (id.startsWith('move:')) {
          const destination = moveDestinations[Number(id.slice(5))];
          if (destination && ensureDraft()) {
            moveBooks(selectedBooks.map((book) => book.id), destination.path);
            setSelectedKeys(new Set());
          }
        } else if (id === 'delete') {
          handleDelete();
        } else if (id === 'save') {
          void handleSave();
        } else if (id === 'discard') {
          requestCancelEdit();
        }
      },
    });
    router.push('/shelf/manage');
  }, [createFolder, ensureDraft, handleDelete, handleSave, interactionMode, isDirty, moveBooks, moveDestinations, renameFolder, requestCancelEdit, selectedBooks, selectedFolders, selectedKeys.size]);

  const androidActions = useMemo<NativeTopAppBarAction[]>(() => [
    { accessibilityLabel: 'Manage shelf', icon: 'dots', id: 'manage' },
  ], []);

  const handleAndroidAction = useCallback((id: string) => {
    if (id === 'manage') openManage();
  }, [openManage]);

  return (
    <>
      <NativeScreenScaffold
        actions={androidActions}
        largeTitle={mode === 'browse' && parents.length === 0}
        onActionPress={handleAndroidAction}
        onBackPress={handleBack}
        showBackButton={parents.length > 0}
        title={title}
      >
        <ShelfScrollRoot nested={parents.length > 0}>
          <ScrollView
          contentInsetAdjustmentBehavior="automatic"
          contentContainerStyle={styles.content}
          nestedScrollEnabled
          onLayout={(event) => {
            viewportHeightRef.current = event.nativeEvent.layout.height;
          }}
          onScroll={(event) => {
            scrollOffsetRef.current = event.nativeEvent.contentOffset.y;
          }}
          ref={scrollViewRef}
          refreshControl={(
            <RefreshControl
              enabled={mode === 'browse'}
              onRefresh={reload}
              refreshing={isRefreshing}
              tintColor={colors.accent as string}
            />
          )}
          scrollEventThrottle={16}
          showsVerticalScrollIndicator={false}
          style={styles.scrollView}
        >
          {parents.length > 1 ? (
            <Text numberOfLines={2} style={styles.breadcrumb}>
              {getFolderBreadcrumb(snapshot, parents)}
            </Text>
          ) : null}

          {editorError ? (
            <InlineError error={editorError} onDismiss={clearEditorError} />
          ) : null}
          {error ? <ErrorState compact={Boolean(snapshot)} error={error} onRetry={reload} /> : null}
          {isLoading ? <LoadingState /> : null}
          {snapshot ? (
            <ShelfContent
              beginDrag={beginDrag}
              interactionMode={interactionMode}
              mode={mode}
              onOpenFolder={openFolder}
              onReorder={reorderSiblings}
              parents={parents}
              scrollOffsetRef={scrollOffsetRef}
              scrollViewRef={scrollViewRef}
              selectedKeys={selectedKeys}
              setSelectedKeys={setSelectedKeys}
              snapshot={snapshot}
              viewportHeightRef={viewportHeightRef}
              visibleItems={visibleItems}
            />
          ) : null}
          </ScrollView>
        </ShelfScrollRoot>
      </NativeScreenScaffold>
      <ShelfNavigation
        isSaving={isSaving}
        largeTitle={parents.length === 0}
        mode={mode}
        onBack={handleBack}
        onManage={openManage}
        onSave={() => void handleSave()}
        showBack={parents.length > 0}
        title={title}
      />

    </>
  );
}

function ShelfScrollRoot({
  children,
  nested,
}: {
  children: React.ReactElement;
  nested: boolean;
}) {
  return nested ? <View style={styles.root}>{children}</View> : children;
}

function ShelfContent({
  beginDrag,
  interactionMode,
  mode,
  onOpenFolder,
  onReorder,
  parents,
  scrollOffsetRef,
  scrollViewRef,
  selectedKeys,
  setSelectedKeys,
  snapshot,
  viewportHeightRef,
  visibleItems,
}: {
  beginDrag: () => boolean;
  interactionMode: 'browse' | 'drag' | 'select';
  mode: ShelfMode;
  onOpenFolder: (folderId: string) => void;
  onReorder: (parents: readonly string[], keys: readonly ShelfItemKey[]) => void;
  parents: string[];
  scrollOffsetRef: React.MutableRefObject<number>;
  scrollViewRef: React.RefObject<ScrollView | null>;
  selectedKeys: Set<ShelfItemKey>;
  setSelectedKeys: React.Dispatch<React.SetStateAction<Set<ShelfItemKey>>>;
  snapshot: ShelfSnapshot;
  viewportHeightRef: React.MutableRefObject<number>;
  visibleItems: ShelfItem[];
}) {
  const { columns, contentWidth, tileWidth } = useBookGridLayout(20);
  const booksById = new Map(snapshot.books.map((book) => [book.id, book]));

  if (visibleItems.length === 0) {
    return <EmptyShelfState nested={parents.length > 0} />;
  }

  const toggleSelection = (key: ShelfItemKey) => {
    setSelectedKeys((current) => {
      const next = new Set(current);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  const renderShelfItem = (
    item: ShelfItem,
    reorderState?: ReorderableShelfGridItemState,
  ) => {
    const key = shelfItemKey(item);
    const interactionState = interactionMode === 'select' && selectedKeys.has(key) ? 'selected' as const : 'default' as const;
    const reorderProps = {};
    if (item.type === 'FOLDER') {
      const folderParents = [...parents, item.id];
      const previewBooks = snapshot.items
        .filter(
          (child): child is Extract<ShelfItem, { type: 'BOOK' }> =>
            child.type === 'BOOK' && sameParents(child.parents, folderParents),
        )
        .map((child) => booksById.get(child.id))
        .filter((book): book is BookListItem => book !== undefined);
      const itemCount = snapshot.items.filter((child) =>
        sameParents(child.parents, folderParents),
      ).length;
      return (
        <ShelfFolderGridItem
          {...reorderProps}
          interactionState={interactionState}
          itemCount={itemCount}
          key={key}
          onPress={() => {
            if (interactionMode === 'select') toggleSelection(key);
            else onOpenFolder(item.id);
          }}
          previewBooks={previewBooks}
          tileWidth={tileWidth}
          title={item.title.trim() || 'Unnamed folder'}
        />
      );
    }

    const book = booksById.get(item.id);
    const handlePress = () => {
      if (!book) return;
      router.push({
        pathname: '/book/[id]',
        params: {
          cover: book.coverUrl,
          id: String(item.id),
          placeholder: book.coverPlaceholder ?? '',
          title: book.title,
          type: book.type,
        },
      });
    };
    return book ? (
      <BookCoverGridItem
        {...reorderProps}
        animateCachedImage
        book={book}
        interactionState={interactionState}
        key={key}
        onPress={interactionMode === 'select' ? () => toggleSelection(key) : handlePress}
        tileWidth={tileWidth}
      />
    ) : (
      <UnavailableBookGridItem
        {...reorderProps}
        interactionState={interactionState}
        key={key}
        onPress={interactionMode === 'select' ? () => toggleSelection(key) : handlePress}
        tileWidth={tileWidth}
      />
    );
  };

  if (interactionMode === 'drag') {
    return (
      <ReorderableShelfGrid
        columns={columns}
        contentWidth={contentWidth}
        dragEnabled
        items={visibleItems}
        onBeginDrag={beginDrag}
        onReorder={(keys) => onReorder(parents, keys)}
        renderItem={renderShelfItem}
        tileWidth={tileWidth}
      />
    );
  }

  const rows: ShelfItem[][] = [];
  for (let index = 0; index < visibleItems.length; index += columns) {
    rows.push(visibleItems.slice(index, index + columns));
  }

  return (
    <View style={[styles.grid, { width: contentWidth }]}>
      {rows.map((row, rowIndex) => (
        <View key={`shelf-row-${rowIndex}`} style={styles.gridRow}>
          {row.map((item) => renderShelfItem(item))}
          {row.length < columns ? (
            <View
              style={{ width: (columns - row.length) * (tileWidth + BOOK_GRID_COLUMN_GAP) }}
            />
          ) : null}
        </View>
      ))}
    </View>
  );
}

function ModeBanner({ isDirty, isSaving, mode }: { isDirty: boolean; isSaving: boolean; mode: ShelfMode }) {
  return (
    <View style={styles.modeBanner}>
      {isSaving ? (
        <ActivityIndicator color={colors.accent as string} size="small" />
      ) : isDirty ? (
        <IconCheck color={colors.accent as string} size={20} strokeWidth={2.2} />
      ) : null}
      <Text style={styles.modeLabel}>
        {isSaving
          ? 'Saving your shelf…'
          : isDirty
              ? 'Unsaved shelf changes'
              : 'Select books or folders to manage them.'}
      </Text>
    </View>
  );
}

function LoadingState() {
  const { columns, contentWidth, height, tileWidth } = useBookGridLayout(20);
  const count = bookGridSkeletonCount({
    columns,
    headerOffset: 120,
    height,
    tileWidth,
  });
  const keys = skeletonKeys(count);
  const rows = [];
  for (let index = 0; index < keys.length; index += columns) {
    rows.push(keys.slice(index, index + columns));
  }

  return (
    <View
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={[styles.grid, { width: contentWidth }]}
    >
      {rows.map((row, rowIndex) => (
        <View key={`shelf-skeleton-row-${rowIndex}`} style={styles.gridRow}>
          {row.map((key) => (
            <BookCoverSkeletonTile key={`shelf-skeleton-${key}`} tileWidth={tileWidth} />
          ))}
        </View>
      ))}
    </View>
  );
}

function ErrorState({
  compact,
  error,
  onRetry,
}: {
  compact: boolean;
  error: string;
  onRetry: () => void;
}) {
  return (
    <View style={styles.errorBlock}>
      <Text selectable style={styles.errorTitle}>
        {compact ? 'Shelf refresh failed' : 'Unable to load your shelf'}
      </Text>
      <Text selectable style={styles.errorText}>{error}</Text>
      <Pressable
        accessibilityLabel="Try again"
        accessibilityRole="button"
        onPress={onRetry}
        style={({ pressed }) => [styles.retryButton, pressed && styles.pressed]}
      >
        <Text style={styles.retryLabel}>Try again</Text>
      </Pressable>
    </View>
  );
}

function InlineError({ error, onDismiss }: { error: string; onDismiss: () => void }) {
  return (
    <View style={styles.inlineError}>
      <IconAlertTriangle color={colors.error as string} size={20} strokeWidth={2} />
      <Text style={styles.inlineErrorLabel}>{error}</Text>
      <Pressable accessibilityLabel="Dismiss shelf error" onPress={onDismiss}>
        <IconX color={colors.secondaryLabel as string} size={20} strokeWidth={2} />
      </Pressable>
    </View>
  );
}

function EmptyShelfState({ nested }: { nested: boolean }) {
  return (
    <SectionCard>
      <View style={styles.emptyState}>
        <IconFolderOpen color={colors.accent as string} size={38} strokeWidth={1.8} />
        <Text style={styles.cardTitle}>{nested ? 'This folder is empty' : 'Your shelf is empty'}</Text>
        <Text style={styles.cardDescription}>
          {nested
            ? 'Move books here while editing your shelf.'
            : 'Add a novel from Discover to start building your shelf.'}
        </Text>
      </View>
    </SectionCard>
  );
}

function UnavailableBookGridItem({
  interactionState,
  onPress,
  tileWidth,
}: {
  interactionState: 'default' | 'selected';
  onPress: () => void;
  tileWidth: number;
}) {
  return (
    <Pressable
      accessibilityLabel="Unavailable book"
      accessibilityRole="button"
      accessibilityState={{ selected: interactionState === 'selected' }}
      delayLongPress={180}
      onPress={onPress}
      style={[styles.unavailableItem, { width: tileWidth }]}
    >
      <View
        style={[
          styles.unavailableCover,
          { aspectRatio: BOOK_COVER_ASPECT_RATIO, width: tileWidth },
        ]}
      >
        <IconBook2 color={colors.secondaryLabel as string} size={32} strokeWidth={1.8} />
        {interactionState !== 'default' ? (
          <View
            style={[
              styles.unavailableOverlay,
              styles.selectedOverlay,
            ]}
          >
            <IconCheck color="#FFFFFF" size={34} strokeWidth={2.5} />
          </View>
        ) : null}
      </View>
      <Text numberOfLines={2} style={styles.unavailableTitle}>Unavailable book</Text>
    </Pressable>
  );
}

function getNavigationTitle(
  snapshot: ShelfSnapshot | null,
  parents: string[],
  mode: ShelfMode,
  selectedBookCount: number,
  hasSelection: boolean,
): string {
  if (parents.length === 0 || !snapshot) return 'Shelf';
  const folder = snapshot.items.find(
    (item): item is Extract<ShelfItem, { type: 'FOLDER' }> =>
      item.type === 'FOLDER' && item.id === parents[parents.length - 1],
  );
  return folder?.title.trim() || 'Unnamed folder';
}

function getFolderBreadcrumb(snapshot: ShelfSnapshot | null, parents: string[]): string {
  if (!snapshot) return '';
  const folderTitles = new Map(snapshot.items.flatMap((item) =>
    item.type === 'FOLDER' ? [[item.id, item.title.trim() || 'Unnamed folder'] as const] : [],
  ));
  return parents.map((id) => folderTitles.get(id) ?? 'Unavailable folder').join(' / ');
}

interface ShelfMoveDestination { label: string; path: string[] }

function getMoveDestinations(snapshot: ShelfSnapshot, parents: string[]): ShelfMoveDestination[] {
  const destinations: ShelfMoveDestination[] = parents.length > 0
    ? [{ label: 'Shelf root', path: [] }]
    : [];
  for (const folder of getShelfFolderPaths(toDraft(snapshot))) {
    if (sameParents(folder.path, parents)) continue;
    destinations.push({ label: folder.label, path: folder.path });
  }
  return destinations;
}

function toDraft(snapshot: ShelfSnapshot): ShelfDraft {
  return { items: snapshot.items, version: snapshot.version };
}

function sameParents(left: readonly string[], right: readonly string[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function setsEqual<T>(left: ReadonlySet<T>, right: ReadonlySet<T>): boolean {
  return left.size === right.size && [...left].every((value) => right.has(value));
}

const styles = StyleSheet.create({
  breadcrumb: { color: colors.secondaryLabel as string, fontSize: 14, lineHeight: 19 },
  cardDescription: { color: colors.secondaryLabel as string, fontSize: 15, lineHeight: 21 },
  cardTitle: { color: colors.label as string, flex: 1, fontSize: 17, fontWeight: '700', lineHeight: 22 },
  content: { gap: 16, paddingBottom: 120, paddingHorizontal: 20, paddingTop: 20 },
  emptyState: { alignItems: 'center', gap: 10, paddingVertical: 18 },
  errorBlock: { alignItems: 'center', gap: 12, paddingHorizontal: 28, paddingVertical: 56 },
  errorText: { color: colors.secondaryLabel as string, fontSize: 14, lineHeight: 20, textAlign: 'center' },
  errorTitle: { color: colors.label as string, fontSize: 17, fontWeight: '700' },
  grid: { gap: 12 },
  gridRow: { alignItems: 'flex-start', flexDirection: 'row', gap: 10, justifyContent: 'space-between' },
  inlineError: { alignItems: 'center', backgroundColor: colors.card as string, borderColor: colors.error as string, borderRadius: 14, borderWidth: StyleSheet.hairlineWidth, flexDirection: 'row', gap: 10, padding: 12 },
  inlineErrorLabel: { color: colors.label as string, flex: 1, fontSize: 14, lineHeight: 19 },
  modeBanner: { alignItems: 'center', backgroundColor: colors.card as string, borderRadius: 14, flexDirection: 'row', gap: 9, paddingHorizontal: 12, paddingVertical: 10 },
  modeLabel: { color: colors.secondaryLabel as string, flex: 1, fontSize: 14, lineHeight: 19 },
  pressed: { opacity: 0.7 },
  retryButton: {
    alignItems: 'center',
    borderColor: colors.separator as string,
    borderCurve: 'continuous',
    borderRadius: 10,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  retryLabel: { color: colors.accent as string, fontSize: 15, fontWeight: '600' },
  root: { backgroundColor: colors.background as string, flex: 1 },
  scrollView: { backgroundColor: colors.background as string, flex: 1 },
  selectedOverlay: { backgroundColor: 'rgba(217, 71, 93, 0.72)' },
  sortingOverlay: { backgroundColor: 'rgba(0, 0, 0, 0.48)' },
  unavailableCover: { alignItems: 'center', backgroundColor: colors.card as string, borderColor: colors.separator as string, borderRadius: 12, borderWidth: 0.5, justifyContent: 'center', overflow: 'hidden' },
  unavailableItem: { alignItems: 'center' },
  unavailableOverlay: { alignItems: 'center', bottom: 0, justifyContent: 'center', left: 0, position: 'absolute', right: 0, top: 0 },
  unavailableTitle: { color: colors.secondaryLabel as string, fontSize: 13, lineHeight: 16, paddingHorizontal: 2, paddingTop: 8, textAlign: 'center' },
});
