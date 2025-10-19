import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/extensions/collection.dart';

sealed class LyricsNode extends Equatable {
  const LyricsNode({this.style});

  final TextStyle? style;

  String get text;

  @override
  List<Object?> get props => [style];
}

sealed class LyricsParentNode extends LyricsNode {
  const LyricsParentNode(this.children, {super.style});

  final List<LyricsNode> children;

  @override
  String get text {
    return children.whereType<LyricsTextNode>().map((e) => e.text).join();
  }

  @override
  List<Object?> get props => [...super.props, children];
}

class LyricsTextNode extends LyricsNode {
  const LyricsTextNode(this.text, {super.style});

  @override
  final String text;
}

class LyricsRtNode extends LyricsParentNode {
  const LyricsRtNode(super.children, {super.style});

  factory LyricsRtNode.from(String text) {
    return LyricsRtNode([LyricsTextNode(text)]);
  }

  @override
  String get text {
    return children.whereType<LyricsTextNode>().map((e) => e.text).join();
  }
}

class LyricsRubyNode extends LyricsParentNode {
  const LyricsRubyNode(super.children, {super.style});

  factory LyricsRubyNode.from(String ruby, String rt) {
    return LyricsRubyNode([LyricsTextNode(ruby), LyricsRtNode.from(rt)]);
  }

  LyricsRtNode? get rt => children.firstWhereTypeOrNull<LyricsRtNode>();

  @override
  String get text {
    return children.whereType<LyricsTextNode>().map((e) => e.text).join();
  }
}
