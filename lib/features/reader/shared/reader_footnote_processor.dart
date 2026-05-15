import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class ReaderFootnoteProcessingResult {
  final String html;
  final Map<String, String> notesById;

  const ReaderFootnoteProcessingResult({
    required this.html,
    required this.notesById,
  });
}

ReaderFootnoteProcessingResult processReaderFootnotesLikeWeb(String html) {
  if (html.isEmpty) {
    return const ReaderFootnoteProcessingResult(html: '', notesById: {});
  }

  try {
    final doc = html_parser.parse(html);
    final notesById = <String, String>{};

    for (final element in doc.querySelectorAll('.duokan-footnote')) {
      final id = readerFootnoteIdFromElement(element);
      if (id == null || id.isEmpty) {
        continue;
      }

      final noteElement = _firstElementWithId(doc, id);
      if (noteElement != null) {
        notesById.putIfAbsent(id, () => noteElement.innerHtml);
        final currentStyle = noteElement.attributes['style'] ?? '';
        noteElement.attributes['style'] = '$currentStyle; display: none;';
      }

      element.attributes['data-footnote-id'] = id;
      element.attributes.remove('href');
      element.attributes['global-cancel'] = 'true';
      element.attributes['id'] = 'v-$id';

      // Flutter uses a native marker widget for the already-recognized footnote.
      element.innerHtml = '';
    }

    return ReaderFootnoteProcessingResult(
      html: doc.body?.innerHtml ?? html,
      notesById: notesById,
    );
  } catch (_) {
    return ReaderFootnoteProcessingResult(html: html, notesById: const {});
  }
}

String? readerFootnoteIdFromElement(dom.Element element) {
  final dataId = _attrValue(element, 'data-footnote-id');
  if (dataId != null && dataId.isNotEmpty) {
    return dataId;
  }

  final href = _attrValue(element, 'href');
  if (href == null || href.isEmpty) {
    return null;
  }
  return href.replaceFirst('#', '');
}

dom.Element? _firstElementWithId(dom.Document doc, String id) {
  final root = doc.documentElement ?? doc;
  for (final element in _walkElements(root)) {
    if (_attrValue(element, 'id') == id) {
      return element;
    }
  }
  return null;
}

String? _attrValue(dom.Element element, String nameLower) {
  for (final entry in element.attributes.entries) {
    if (entry.key.toString().toLowerCase() == nameLower) {
      return entry.value;
    }
  }
  return null;
}

Iterable<dom.Element> _walkElements(dom.Node node) sync* {
  if (node is dom.Element) {
    yield node;
  }
  for (final child in node.nodes) {
    yield* _walkElements(child);
  }
}
