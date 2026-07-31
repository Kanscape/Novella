import RenderHTML from 'react-native-render-html';

import { createHtmlPreviewSource } from '@/components/html-preview-source';
import { createHtmlRubyRenderers } from '@/components/html-ruby-renderer';
import { colors } from '@/theme/colors';

const selectableHtmlRenderers = createHtmlRubyRenderers({ selectable: true });
const previewHtmlRenderers = createHtmlRubyRenderers({ preview: true, selectable: false });

export interface BookHtmlContentProps {
  contentWidth: number;
  html: string;
  preview?: boolean;
  textColor?: string;
}

export function BookHtmlContent({
  contentWidth,
  html,
  preview = false,
  textColor,
}: BookHtmlContentProps) {
  const sourceHtml = preview ? createHtmlPreviewSource(html) : html;

  return (
    <RenderHTML
      baseStyle={{
        color: textColor ?? (preview ? colors.secondaryLabel : colors.label) as string,
        fontSize: preview ? 14 : 16,
        lineHeight: preview ? 22.4 : 28.8,
      }}
      contentWidth={contentWidth}
      defaultTextProps={{ selectable: !preview }}
      enableExperimentalMarginCollapsing
      ignoredDomTags={preview ? ['script', 'style', 'img'] : ['script', 'style']}
      renderers={preview ? previewHtmlRenderers : selectableHtmlRenderers}
      renderersProps={{ img: { enableExperimentalPercentWidth: true } }}
      source={{ html: sourceHtml }}
      tagsStyles={{
        body: { margin: 0, padding: 0 },
        div: { marginBottom: preview ? 0 : 6.4 },
        p: { marginBottom: preview ? 8.4 : 9.6, marginTop: 0 },
      }}
    />
  );
}
