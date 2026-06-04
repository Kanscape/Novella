import 'package:html/dom.dart' as dom;

final RegExp _leadingInlineWhitespace = RegExp(r'^[\s\u00A0\u200B\u3000]+');

bool shouldUseReaderInlineElementAsStandaloneBlock(
  dom.Element element, {
  required Set<String> blockTags,
  required bool Function(dom.Element element) isHidden,
  required String Function(String text) normalizeText,
}) {
  final tag = element.localName;
  if (tag == null || blockTags.contains(tag) || isHidden(element)) {
    return false;
  }

  if (_hasReaderBlockDescendant(element, blockTags, isHidden)) {
    return false;
  }

  return normalizeText(element.text).isNotEmpty ||
      element.getElementsByTagName('img').isNotEmpty ||
      element.getElementsByTagName('br').isNotEmpty;
}

dom.Element wrapReaderInlineElementAsParagraph(dom.Element element) {
  final paragraph = dom.Element.tag('p')..innerHtml = element.outerHtml;
  _stripLeadingInlineWhitespace(paragraph);
  return paragraph;
}

bool _hasReaderBlockDescendant(
  dom.Element element,
  Set<String> blockTags,
  bool Function(dom.Element element) isHidden,
) {
  for (final child in element.nodes) {
    if (child is! dom.Element || isHidden(child)) {
      continue;
    }
    final tag = child.localName;
    if (tag != null && blockTags.contains(tag)) {
      return true;
    }
    if (_hasReaderBlockDescendant(child, blockTags, isHidden)) {
      return true;
    }
  }
  return false;
}

bool _stripLeadingInlineWhitespace(dom.Node node) {
  for (final child in node.nodes) {
    if (child is dom.Text) {
      child.text = child.text.replaceFirst(_leadingInlineWhitespace, '');
      if (child.text.isNotEmpty) {
        return true;
      }
      continue;
    }

    if (child is dom.Element) {
      if (child.localName == 'br' || child.localName == 'img') {
        return true;
      }
      if (_stripLeadingInlineWhitespace(child)) {
        return true;
      }
    }
  }
  return false;
}
