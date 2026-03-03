import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class XPathUtils {
  /// 清洗 XPath，移除所有的开头标记（如 `//*/`，`//` 或 `/`）
  /// 以保证两端（Web / App）的根路径差异不影响后续 Key 匹配
  static String cleanXPath(String rawXPath) {
    if (rawXPath.isEmpty) return rawXPath;
    // 匹配开头结尾所有形式的 / 或 * 或 //*/
    return rawXPath.replaceFirst(RegExp(r'^(/+|\*|//\*/)+'), '');
  }

  /// 为 HTML 中的块级元素注入 `data-xpath` 属性
  /// 用于后续在滚动或点击时识别其在 DOM 树中的坐标
  static String injectXPathAttributes(String htmlContent) {
    if (htmlContent.isEmpty) return htmlContent;

    try {
      final document = html_parser.parseFragment(htmlContent);

      for (var node in document.nodes) {
        _traverseAndInject(node, '');
      }

      return document.outerHtml;
    } catch (e) {
      // 解析失败则返回原串
      return htmlContent;
    }
  }

  static void _traverseAndInject(dom.Node node, String currentPath) {
    if (node is dom.Element) {
      final tag = node.localName ?? '';

      // 构建当前层级的 XPath 片段
      // 为了保持与标准 XPath 兼容，使用 1-based index
      int index = 1;
      final parent = node.parentNode;
      if (parent != null) {
        for (var sibling in parent.nodes) {
          if (sibling == node) break;
          if (sibling is dom.Element && sibling.localName == tag) {
            index++;
          }
        }
      }

      String myPath = '$currentPath/$tag[$index]';
      // 如果是根节点，可能 currentPath 是空
      if (currentPath.isEmpty) {
        myPath = '//*/$tag[$index]';
      }

      // 仅对目标有意义层级进行打标，且避免重复覆盖已有 data-xpath
      // 为方便测试先排除 br 和一些无关紧要的行内元素
      final targetTags = {
        'p',
        'div',
        'img',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'li',
        'blockquote',
        'table',
        'span',
        'a',
      };

      if (targetTags.contains(tag) &&
          !node.attributes.containsKey('data-xpath')) {
        node.attributes['data-xpath'] = myPath;
      }

      // 递归子节点
      for (var child in node.nodes) {
        _traverseAndInject(child, myPath);
      }
    }
  }
}
