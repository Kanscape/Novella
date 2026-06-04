import 'package:html/dom.dart' as dom;

final RegExp _leadingInlineWhitespace = RegExp(r'^[\s\u00A0\u200B\u3000]+');
const Set<String> _readerMetadataTags = {
  'base',
  'head',
  'link',
  'meta',
  'noscript',
  'script',
  'style',
  'template',
  'title',
};

bool shouldUseReaderInlineElementAsStandaloneBlock(
  dom.Element element, {
  required Set<String> blockTags,
  required bool Function(dom.Element element) isHidden,
  required String Function(String text) normalizeText,
}) {
  final tag = element.localName;
  if (tag == null ||
      _readerMetadataTags.contains(tag) ||
      blockTags.contains(tag) ||
      isHidden(element)) {
    return false;
  }

  if (_hasReaderBlockDescendant(element, blockTags, isHidden)) {
    return false;
  }

  return normalizeText(element.text).isNotEmpty ||
      element.getElementsByTagName('img').isNotEmpty ||
      element.getElementsByTagName('br').isNotEmpty;
}

bool shouldUseReaderNodeInInlineBlock(
  dom.Node node, {
  required Set<String> blockTags,
  required bool Function(dom.Element element) isHidden,
}) {
  if (node is dom.Text) {
    return !_hasReaderMetadataAncestor(node);
  }

  if (node is! dom.Element) {
    return false;
  }

  final tag = node.localName;
  if (tag == null ||
      _readerMetadataTags.contains(tag) ||
      blockTags.contains(tag) ||
      isHidden(node)) {
    return false;
  }

  return !_hasReaderBlockDescendant(node, blockTags, isHidden);
}

bool readerInlineNodesHaveRenderableContent(
  Iterable<dom.Node> nodes, {
  required String Function(String text) normalizeText,
}) {
  final text = StringBuffer();
  var hasImage = false;
  var hasBreak = false;

  for (final node in nodes) {
    if (node is dom.Text) {
      if (_hasReaderMetadataAncestor(node)) {
        continue;
      }
      text.write(node.text);
      continue;
    }

    if (node is dom.Element) {
      final tag = node.localName;
      if (tag != null && _readerMetadataTags.contains(tag)) {
        continue;
      }
      text.write(node.text);
      hasImage =
          hasImage ||
          tag == 'img' ||
          node.getElementsByTagName('img').isNotEmpty;
      hasBreak =
          hasBreak || tag == 'br' || node.getElementsByTagName('br').isNotEmpty;
    }
  }

  return normalizeText(text.toString()).isNotEmpty || hasImage || hasBreak;
}

dom.Element wrapReaderInlineElementAsParagraph(dom.Element element) {
  return wrapReaderInlineNodesAsParagraph([element]);
}

dom.Element wrapReaderInlineNodesAsParagraph(Iterable<dom.Node> nodes) {
  final paragraph = dom.Element.tag('p');
  for (final node in nodes) {
    paragraph.nodes.add(node.clone(true));
  }
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

bool _hasReaderMetadataAncestor(dom.Node node) {
  dom.Node? current = node.parentNode;
  while (current != null) {
    if (current is dom.Element) {
      final tag = current.localName;
      if (tag != null && _readerMetadataTags.contains(tag)) {
        return true;
      }
    }
    current = current.parentNode;
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
