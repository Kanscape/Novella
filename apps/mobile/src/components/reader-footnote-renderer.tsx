import { StyleSheet } from 'react-native';
import type { CustomTextualRenderer } from 'react-native-render-html';

import { colors } from '@/theme/colors';

export function createReaderFootnoteRenderer(
  notesById: Readonly<Record<string, string>>,
  fontSize: number,
  onOpenFootnote?: (id: string) => void,
): CustomTextualRenderer {
  return function ReaderFootnoteRenderer({ TDefaultRenderer, tnode, ...props }) {
    const id = tnode.attributes['data-reader-footnote-id'];
    const note = id ? notesById[id] : undefined;
    if (!id || note === undefined) {
      return <TDefaultRenderer {...props} tnode={tnode} />;
    }

    const markerSize = Math.min(20, Math.max(13, fontSize * 1.05));
    return (
      <TDefaultRenderer
        {...props}
        {...(onOpenFootnote ? { onPress: () => onOpenFootnote(id) } : {})}
        textProps={{
          ...props.textProps,
          accessibilityHint: 'Opens the footnote in a sheet',
          accessibilityLabel: 'Open footnote',
          accessibilityRole: 'button',
          selectable: false,
          style: [
            props.textProps?.style,
            styles.marker,
            { fontSize: markerSize, lineHeight: markerSize },
          ],
        }}
        tnode={tnode}
      />
    );
  };
}

const styles = StyleSheet.create({
  marker: {
    color: colors.accent as string,
    fontWeight: '800',
    textDecorationLine: 'none',
  },
});
