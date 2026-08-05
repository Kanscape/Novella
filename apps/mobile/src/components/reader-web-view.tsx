import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from 'react';
import { StyleProp, ViewStyle } from 'react-native';
import { WebView, WebViewMessageEvent } from 'react-native-webview';
import { ReaderImagePreview, type ReaderImagePreviewSource } from '@/components/reader-image-preview';
import type { ChapterReadingMode } from '@/services/reader-xhtml-builder';

/** Scroll position reported by the chapter page. */
export interface ReaderWebViewPosition {
  /** 0-1 scroll progression through the document. */
  progression: number;
  /** Text visible near the top of the viewport (anchor for restoration). */
  anchor?: string;
}

/** Theme knobs applied live via CSS custom properties (no page reload). */
export interface ReaderWebViewTheme {
  backgroundColor?: string;
  textColor?: string;
  fontSize?: number;
  lineHeight?: number;
  topPadding?: number;
  bottomPadding?: number;
  sidePadding?: number;
  firstLineIndent?: boolean;
}

export interface ReaderWebViewHandle {
  /** Run JS in the chapter page (e.g. theme updates). */
  injectJavaScript(script: string): void;
  /** Scroll the page to a 0-1 progression. */
  scrollToProgression(progression: number): void;
}

export interface ReaderWebViewProps {
  /** Full XHTML document produced by buildChapterXhtml. */
  html: string;
  /** Initial 0-1 scroll progression to restore to. */
  initialProgression?: number;
  /** Layout mode — determines which scroll axis the restore uses. */
  readingMode?: ChapterReadingMode;
  /** Theme knobs; changes are applied via CSS variables without reloading. */
  theme?: ReaderWebViewTheme;
  onPosition?: (position: ReaderWebViewPosition) => void;
  onFootnote?: (id: string) => void;
  onLoadEnd?: () => void;
  style?: StyleProp<ViewStyle>;
}

function scrollScript(progression: number): string {
  return [
    '(function(){',
    'var d=document.documentElement||document.body;',
    'var max=Math.max(1,(d.scrollHeight||0)-window.innerHeight);',
    `window.scrollTo(0,Math.max(0,Math.min(1,${progression}))*max);`,
    '})();',
  ].join('');
}

function pageScrollScript(progression: number): string {
  // The paged reader exposes __nvSetPage(0-1) which computes the page count
  // itself and moves the sheet to the matching page.
  return [
    '(function(){',
    'if (window.__nvSetPage) window.__nvSetPage(' + progression + ');',
    '})();',
  ].join('');
}

function themeScript(theme: ReaderWebViewTheme): string {
  const parts: string[] = [];
  const push = (name: string, value: string | number | undefined, unit = '') => {
    if (value === undefined) return;
    parts.push(`r.style.setProperty('${name}','${value}${unit}')`);
  };
  push('--nv-bg', theme.backgroundColor);
  push('--nv-fg', theme.textColor);
  push('--nv-font', theme.fontSize, 'px');
  push('--nv-line', theme.lineHeight, 'px');
  push('--nv-top', theme.topPadding, 'px');
  push('--nv-bottom', theme.bottomPadding, 'px');
  push('--nv-hpad', theme.sidePadding, 'px');
  push('--nv-hpad2', theme.sidePadding !== undefined ? theme.sidePadding * 2 : undefined, 'px');
  if (theme.firstLineIndent !== undefined) {
    parts.push(`r.style.setProperty('--nv-indent','${theme.firstLineIndent ? '2em' : '0'}')`);
  }
  if (parts.length === 0) return '';
  return `(function(){var r=document.documentElement;${parts.join(';')};})();`;
}

export const ReaderWebView = forwardRef<ReaderWebViewHandle, ReaderWebViewProps>(
  function ReaderWebView(
    { html, initialProgression, readingMode = 'scroll', theme, onPosition, onFootnote, onLoadEnd, style },
    ref,
  ) {
    const webViewRef = useRef<WebView>(null);
    const onPositionRef = useRef(onPosition);
    onPositionRef.current = onPosition;
    const onFootnoteRef = useRef(onFootnote);
    onFootnoteRef.current = onFootnote;
    // Latest reported progression — used to restore position after the html
    // reloads (reading-mode switch rebuilds the document).
    const lastProgressionRef = useRef<number>(0);
    const [previewSource, setPreviewSource] = useState<ReaderImagePreviewSource | null>(null);

    useImperativeHandle(
      ref,
      () => ({
        injectJavaScript(script: string) {
          webViewRef.current?.injectJavaScript(script);
        },
        scrollToProgression(progression: number) {
          const script = readingMode === 'paged'
            ? pageScrollScript(progression)
            : scrollScript(progression);
          webViewRef.current?.injectJavaScript(script);
        },
      }),
      [readingMode],
    );

    const handleMessage = (event: WebViewMessageEvent) => {
      try {
        const data = JSON.parse(event.nativeEvent.data) as {
          type?: string;
          progression?: number;
          anchor?: string;
          src?: string;
          id?: string;
          level?: string;
          message?: string;
          alt?: string;
        };
        if (data.type === 'position') {
          const position: ReaderWebViewPosition = {
            progression: data.progression ?? 0,
          };
          if (typeof data.anchor === 'string' && data.anchor.length > 0) {
            position.anchor = data.anchor;
          }
          lastProgressionRef.current = position.progression;
          onPositionRef.current?.(position);
        } else if (data.type === 'footnote') {
          if (typeof data.id === 'string' && data.id.length > 0) {
            onFootnoteRef.current?.(data.id);
          }
        } else if (data.type === 'image-preview') {
          if (typeof data.src === 'string' && data.src.length > 0) {
            const preview: ReaderImagePreviewSource = { uri: data.src };
            if (typeof data.alt === 'string' && data.alt.trim().length > 0) {
              preview.alt = data.alt.trim();
            }
            setPreviewSource(preview);
          }
        } else if (data.type === 'log') {
          const level = data.level === 'error' ? 'error' : data.level === 'warn' ? 'warn' : 'log';
          const message = typeof data.message === 'string' ? data.message : '';
          // eslint-disable-next-line no-console
          console[level](`[webview] ${message}`);
        }
      } catch {
        // Non-JSON payloads are ignored.
      }
    };

    const handleLoadEnd = () => {
      onLoadEnd?.();
      // After a reload (e.g. reading-mode switch) prefer the most recently
      // reported position over the initial one so the reader stays put.
      const restore = lastProgressionRef.current > 0
        ? lastProgressionRef.current
        : (initialProgression ?? 0);
      if (restore > 0) {
        // Wait for layout/fonts to settle before restoring the scroll position.
        setTimeout(() => {
          webViewRef.current?.injectJavaScript(
            readingMode === 'paged' ? pageScrollScript(restore) : scrollScript(restore),
          );
        }, 120);
      }
    };

    // The WebView container itself must carry the page background too: on iOS
    // the bounce/overscroll area shows the native WebView background (white by
    // default) even when the HTML body is dark — underlayColor is what paints
    // that region, and the style background covers Android + loading states.
    const pageBackground = theme?.backgroundColor ?? '#F2F2F7';
    const themeScriptSource = themeScript(theme ?? {});
    const themeKey = JSON.stringify(theme ?? {});
    useEffect(() => {
      if (themeScriptSource) {
        webViewRef.current?.injectJavaScript(themeScriptSource);
      }
      // Layout-affecting knobs (font size, line height, side padding, top and
      // bottom insets) change CSS variables live; in paged mode the pagination
      // must re-run on the new metrics, keeping the current page. Wait a tick
      // so the style change has been applied before re-measuring.
      webViewRef.current?.injectJavaScript(
        'setTimeout(function(){if (window.__nvRepaginate) window.__nvRepaginate();}, 60);',
      );
      // Re-applied whenever any theme knob changes.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [themeKey]);

    return (
      <>
        <WebView
          ref={webViewRef}
          originWhitelist={['*']}
          javaScriptEnabled
          domStorageEnabled
          onLoadEnd={handleLoadEnd}
          onMessage={handleMessage}
          scrollEnabled
          showsHorizontalScrollIndicator={false}
          showsVerticalScrollIndicator={false}
          setSupportMultipleWindows={false}
          source={{ html }}
          style={[style, { backgroundColor: pageBackground }]}
        />
        {previewSource !== null ? (
          <ReaderImagePreview
            onClose={() => setPreviewSource(null)}
            source={previewSource}
          />
        ) : null}
      </>
    );
  },
);
