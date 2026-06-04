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

    final paragraph = wrapReaderInlineElementAsParagraph(
      element,
      isHidden: isHidden,
    );

    expect(
      paragraph.outerHtml,
      '<p><i><span class="bold">《答。要连结吗？　　YES／NO》</span></i></p>',
    );
  });

  test('wraps mixed top-level text and inline elements together', () {
    final fragment = html_parser.parseFragment('Intro <i>emphasis</i> outro');

    final paragraph = wrapReaderInlineNodesAsParagraph(
      fragment.nodes,
      isHidden: isHidden,
    );

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
        readerInlineNodesHaveRenderableContent(
          [element],
          isHidden: isHidden,
          normalizeText: normalizeReaderText,
        ),
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

  test('filters metadata descendants inside inline wrappers', () {
    final metadataOnly = firstElement('<span><style>.x{}</style></span>');

    expect(
      shouldUseReaderInlineElementAsStandaloneBlock(
        metadataOnly,
        blockTags: blockTags,
        isHidden: isHidden,
        normalizeText: normalizeReaderText,
      ),
      isFalse,
    );
    expect(
      readerInlineNodesHaveRenderableContent(
        [metadataOnly],
        isHidden: isHidden,
        normalizeText: normalizeReaderText,
      ),
      isFalse,
    );

    final mixed = firstElement(
      '<span><style>.x{}</style>正文<script>alert(1)</script></span>',
    );

    expect(
      readerInlineNodesHaveRenderableContent(
        [mixed],
        isHidden: isHidden,
        normalizeText: normalizeReaderText,
      ),
      isTrue,
    );
    expect(
      wrapReaderInlineElementAsParagraph(mixed, isHidden: isHidden).outerHtml,
      '<p><span>正文</span></p>',
    );
  });

  test('ignores hidden descendants inside inline wrappers', () {
    final hiddenOnly = firstElement(
      '<span><span style="display:none">hidden</span></span>',
    );

    expect(
      shouldUseReaderInlineElementAsStandaloneBlock(
        hiddenOnly,
        blockTags: blockTags,
        isHidden: isHidden,
        normalizeText: normalizeReaderText,
      ),
      isFalse,
    );
    expect(
      readerInlineNodesHaveRenderableContent(
        [hiddenOnly],
        isHidden: isHidden,
        normalizeText: normalizeReaderText,
      ),
      isFalse,
    );

    final mixed = firstElement(
      '<span><span style="display:none">hidden</span>正文'
      '<span style="display:none"><img src="hidden.png"></span></span>',
    );

    expect(
      readerInlineNodesHaveRenderableContent(
        [mixed],
        isHidden: isHidden,
        normalizeText: normalizeReaderText,
      ),
      isTrue,
    );
    expect(
      wrapReaderInlineElementAsParagraph(mixed, isHidden: isHidden).outerHtml,
      '<p><span>正文</span></p>',
    );
  });

  test('skips non-renderable separators without splitting inline text', () {
    final fragment = html_parser.parseFragment(
      'Intro <!--note--><span style="display:none">hidden</span>'
      '<style>.x{}</style> outro',
    );
    final inlineNodes = <dom.Node>[];

    for (final node in fragment.nodes) {
      if (shouldUseReaderNodeInInlineBlock(
        node,
        blockTags: blockTags,
        isHidden: isHidden,
      )) {
        inlineNodes.add(node);
        continue;
      }
      if (shouldSkipReaderNodeBetweenInlineBlocks(node, isHidden: isHidden)) {
        continue;
      }
      fail('unexpected rendered block separator: $node');
    }

    expect(
      wrapReaderInlineNodesAsParagraph(
        inlineNodes,
        isHidden: isHidden,
      ).outerHtml,
      '<p>Intro  outro</p>',
    );
  });
}
