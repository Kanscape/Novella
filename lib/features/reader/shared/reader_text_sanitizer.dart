import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const Map<String, String> _readerNamedHtmlEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00A0',
  'ensp': '\u2002',
  'emsp': '\u2003',
  'thinsp': '\u2009',
  'ndash': '\u2013',
  'mdash': '\u2014',
  'hellip': '\u2026',
  'lsquo': '\u2018',
  'rsquo': '\u2019',
  'ldquo': '\u201C',
  'rdquo': '\u201D',
};

String sanitizeReaderHtmlTextNodes(String html, Set<int> invisibleCodepoints) {
  if (html.isEmpty) {
    return html;
  }

  try {
    final fragment = html_parser.parseFragment(html);
    var changed = false;

    void visit(dom.Node node) {
      if (node is dom.Text) {
        final sanitized = sanitizeReaderTextNode(
          node.text,
          invisibleCodepoints,
        );
        if (sanitized != node.text) {
          node.text = sanitized;
          changed = true;
        }
        return;
      }

      for (final child in node.nodes) {
        visit(child);
      }
    }

    for (final node in fragment.nodes) {
      visit(node);
    }

    return changed ? _serializeFragmentNodes(fragment.nodes) : html;
  } catch (_) {
    return sanitizeReaderTextNode(html, invisibleCodepoints);
  }
}

String sanitizeReaderTextNode(String text, Set<int> invisibleCodepoints) {
  if (text.isEmpty) {
    return text;
  }

  text = _repairBrokenHtmlEntities(text);

  final buffer = StringBuffer();
  var changed = false;
  var previousWasZeroWidthSpace = false;

  for (final rune in text.runes) {
    if (invisibleCodepoints.contains(rune)) {
      changed = true;
      continue;
    }

    if (rune == 0x200B) {
      if (previousWasZeroWidthSpace) {
        changed = true;
        continue;
      }
      previousWasZeroWidthSpace = true;
    } else {
      previousWasZeroWidthSpace = false;
    }

    buffer.writeCharCode(rune);
  }

  final sanitized = changed ? buffer.toString() : text;
  final decoded = decodeReaderHtmlTextEntities(sanitized);
  if (decoded != sanitized) {
    return decoded;
  }
  return sanitized;
}

String normalizeReaderText(String text) {
  return text
      .replaceAll('\u200B', '')
      .replaceAll('\u00A0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String decodeReaderHtmlTextEntities(String text) {
  if (text.isEmpty || !text.contains('&')) {
    return text;
  }

  return text.replaceAllMapped(
    RegExp(r'&(#x?[0-9A-Fa-f]+|[A-Za-z]+);'),
    (match) {
      final token = match.group(1);
      if (token == null || token.isEmpty) {
        return match.group(0) ?? '';
      }

      if (token.startsWith('#x') || token.startsWith('#X')) {
        final codePoint = int.tryParse(token.substring(2), radix: 16);
        return _decodeReaderCodePoint(codePoint, match.group(0)!);
      }

      if (token.startsWith('#')) {
        final codePoint = int.tryParse(token.substring(1));
        return _decodeReaderCodePoint(codePoint, match.group(0)!);
      }

      return _readerNamedHtmlEntities[token.toLowerCase()] ?? match.group(0)!;
    },
  );
}

String _repairBrokenHtmlEntities(String text) {
  if (!text.contains('&') || !text.contains('\u200B')) {
    return text;
  }

  return text.replaceAllMapped(
    RegExp(r'&(?:\u200B*[#A-Za-z0-9xX]+)+\u200B*;'),
    (match) => match.group(0)!.replaceAll('\u200B', ''),
  );
}

String _decodeReaderCodePoint(int? codePoint, String fallback) {
  if (codePoint == null || codePoint <= 0 || codePoint > 0x10FFFF) {
    return fallback;
  }
  return String.fromCharCode(codePoint);
}

String _serializeFragmentNodes(List<dom.Node> nodes) {
  final buffer = StringBuffer();
  for (final node in nodes) {
    if (node is dom.Element) {
      buffer.write(node.outerHtml);
    } else if (node is dom.Text) {
      buffer.write(node.text);
    }
  }
  return buffer.toString();
}
