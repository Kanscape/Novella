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

  return readerInlineNodesHaveRenderableContent(
    [element],
    isHidden: isHidden,
    normalizeText: normalizeText,
  );
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

bool shouldSkipReaderNodeBetweenInlineBlocks(
  dom.Node node, {
  required bool Function(dom.Element element) isHidden,
}) {
  if (node is dom.Text) {
    return _hasReaderMetadataAncestor(node);
  }

  if (node is! dom.Element) {
    return true;
  }

  final tag = node.localName;
  return tag == null || _readerMetadataTags.contains(tag) || isHidden(node);
}

bool readerInlineNodesHaveRenderableContent(
  Iterable<dom.Node> nodes, {
  required bool Function(dom.Element element) isHidden,
  required String Function(String text) normalizeText,
}) {
  final summary = _summarizeReaderInlineContent(nodes, isHidden);

  return normalizeText(summary.text.toString()).isNotEmpty ||
      summary.hasImage ||
      summary.hasBreak;
}

dom.Element wrapReaderInlineElementAsParagraph(
  dom.Element element, {
  required bool Function(dom.Element element) isHidden,
}) {
  return wrapReaderInlineNodesAsParagraph([element], isHidden: isHidden);
}

dom.Element wrapReaderInlineNodesAsParagraph(
  Iterable<dom.Node> nodes, {
  required bool Function(dom.Element element) isHidden,
}) {
  final paragraph = dom.Element.tag('p');
  for (final node in nodes) {
    final clone = _cloneReaderInlineNode(node, isHidden);
    if (clone != null) {
      paragraph.nodes.add(clone);
    }
  }
  _stripLeadingInlineWhitespace(paragraph);
  return paragraph;
}

_ReaderInlineContentSummary _summarizeReaderInlineContent(
  Iterable<dom.Node> nodes,
  bool Function(dom.Element element) isHidden,
) {
  final summary = _ReaderInlineContentSummary();
  for (final node in nodes) {
    _collectReaderInlineContent(node, summary, isHidden);
  }
  return summary;
}

void _collectReaderInlineContent(
  dom.Node node,
  _ReaderInlineContentSummary summary,
  bool Function(dom.Element element) isHidden,
) {
  if (node is dom.Text) {
    if (!_hasReaderMetadataAncestor(node)) {
      summary.text.write(node.text);
    }
    return;
  }

  if (node is! dom.Element) {
    return;
  }

  final tag = node.localName;
  if ((tag != null && _readerMetadataTags.contains(tag)) || isHidden(node)) {
    return;
  }

  if (tag == 'img') {
    summary.hasImage = true;
  }
  if (tag == 'br') {
    summary.hasBreak = true;
  }

  for (final child in node.nodes) {
    _collectReaderInlineContent(child, summary, isHidden);
  }
}

dom.Node? _cloneReaderInlineNode(
  dom.Node node,
  bool Function(dom.Element element) isHidden,
) {
  if (node is dom.Text && _hasReaderMetadataAncestor(node)) {
    return null;
  }

  if (node is dom.Element) {
    final tag = node.localName;
    if ((tag != null && _readerMetadataTags.contains(tag)) || isHidden(node)) {
      return null;
    }
  }

  final clone = node.clone(true);
  if (clone is dom.Element) {
    _removeReaderNonRenderableDescendants(clone, isHidden);
  }
  return clone;
}

void _removeReaderNonRenderableDescendants(
  dom.Element element,
  bool Function(dom.Element element) isHidden,
) {
  final skippedChildren = <dom.Element>[];

  for (final child in element.nodes) {
    if (child is! dom.Element) {
      continue;
    }

    final tag = child.localName;
    if ((tag != null && _readerMetadataTags.contains(tag)) || isHidden(child)) {
      skippedChildren.add(child);
      continue;
    }

    _removeReaderNonRenderableDescendants(child, isHidden);
  }

  for (final child in skippedChildren) {
    child.remove();
  }
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

class _ReaderInlineContentSummary {
  final StringBuffer text = StringBuffer();
  bool hasImage = false;
  bool hasBreak = false;
}
