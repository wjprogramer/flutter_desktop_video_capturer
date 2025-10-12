import 'package:flutter_desktop_video_capturer/external/flutter_singer/models/nodes.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class FSHtmlParser {
  FSHtmlParser._();

  static List<LyricsNode> parseHtml(String htmlCode) {
    final document = html_parser.parse(htmlCode);
    final bodyElement = document.body;
    if (bodyElement == null) {
      return [];
    }
    final a = _tour(bodyElement);
    return a;
  }

  ///
  /// - rt 是原文的念法
  /// - rtc 是歌詞的念法，但非原本的念法
  ///
  /// 一些 parse 限制
  ///
  /// - ruby 裡面不能有其他 ruby
  /// - rt 裡面不能有其他 ruby/rt/rtc
  /// - rtc 裡面不能有其他 ruby/rt/rtc
  static List<LyricsNode> _tour(dom.Node node) {
    if (node is dom.Text) {
      return [
        LyricsTextNode(node.text),
      ];
    }

    if (node is dom.Element) {
      tourChildren(dom.Element element) {
        final res = <LyricsNode>[];
        for (var childNode in element.nodes) {
          res.addAll(_tour(childNode));
        }
        return res;
      }

      switch (node.localName) {
        case 'rt':
          return [
            LyricsRtNode(tourChildren(node)),
          ];
        case 'ruby':
          return [
            LyricsRubyNode(tourChildren(node)),
          ];
        case 'rtc':
          return [
            LyricsTextNode('(${node.text})'),
          ];
        default:
          return tourChildren(node);
      }
    }

    return [];
  }
}