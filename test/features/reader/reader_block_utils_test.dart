import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:novella/features/reader/shared/reader_block_utils.dart';
import 'package:novella/features/reader/shared/reader_text_sanitizer.dart';

void main() {
  const blockTags = {'p', 'div', 'blockquote', 'img', 'hr'};

  bool isHidden(dom.Element element) {
    final style = (element.attributes['style'] ?? '').toLowerCase();
    return RegExp(r'display\s*:\s*none').hasMatch(style);
  }

  dom.Element firstElement(String html) {
    final fragment = html_parser.parseFragment(html);
    return fragment.nodes.whereType<dom.Element>().first;
  }

  test('detects a standalone inline subtree as readable content', () {
    final element = firstElement(
      '<i><span class="bold">《答。要连结吗？ YES／NO》</span></i>',
    );

    expect(
      shouldUseReaderInlineElementAsStandaloneBlock(
        element,
        blockTags: blockTags,
        isHidden: isHidden,
        normalizeText: normalizeReaderText,
      ),
      isTrue,
    );
  });

  test(
    'does not treat a wrapper with block descendants as an inline block',
    () {
      final element = firstElement('<section><p>正文</p></section>');

      expect(
        shouldUseReaderInlineElementAsStandaloneBlock(
          element,
          blockTags: blockTags,
          isHidden: isHidden,
          normalizeText: normalizeReaderText,
        ),
        isFalse,
      );
    },
  );

  test('wraps standalone inline content without leading whitespace', () {
    final element = firstElement(
      '<i>　　<span class="bold">《答。要连结吗？　　YES／NO》</span></i>',
    );

    final paragraph = wrapReaderInlineElementAsParagraph(element);

    expect(
      paragraph.outerHtml,
      '<p><i><span class="bold">《答。要连结吗？　　YES／NO》</span></i></p>',
    );
  });

  test('wraps mixed top-level text and inline elements together', () {
    final fragment = html_parser.parseFragment('Intro <i>emphasis</i> outro');

    final paragraph = wrapReaderInlineNodesAsParagraph(fragment.nodes);

    expect(paragraph.outerHtml, '<p>Intro <i>emphasis</i> outro</p>');
  });

  test('excludes metadata elements and their text from inline blocks', () {
    final fragment = html_parser.parseFragment(
      '<style>body{color:red}</style><script>alert(1)</script>',
    );
    final elements = fragment.nodes.whereType<dom.Element>().toList();

    for (final element in elements) {
      expect(
        shouldUseReaderNodeInInlineBlock(
          element,
          blockTags: blockTags,
          isHidden: isHidden,
        ),
        isFalse,
      );
      expect(
        readerInlineNodesHaveRenderableContent([
          element,
        ], normalizeText: normalizeReaderText),
        isFalse,
      );

      for (final text in element.nodes.whereType<dom.Text>()) {
        expect(
          shouldUseReaderNodeInInlineBlock(
            text,
            blockTags: blockTags,
            isHidden: isHidden,
          ),
          isFalse,
        );
      }
    }
  });
}
