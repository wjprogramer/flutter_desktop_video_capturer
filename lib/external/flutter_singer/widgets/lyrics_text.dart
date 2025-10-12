import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer/models/nodes.dart';

List<InlineSpan> buildInlineSpans(BuildContext context, {
  required LyricsNode data,
  TextStyle? style,
}) {
  final node = data;
  final textDirection = Directionality.maybeOf(context);
  final defaultTextStyle = DefaultTextStyle.of(context).style;
  final boldTextOverride = MediaQuery.boldTextOf(context);

  // text style
  var effectiveTextStyle = style ?? node.style;
  if (effectiveTextStyle == null || effectiveTextStyle.inherit) {
    effectiveTextStyle = defaultTextStyle.merge(effectiveTextStyle);
  }
  if (boldTextOverride) {
    effectiveTextStyle = effectiveTextStyle
        .merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  assert(effectiveTextStyle.fontSize != null, 'must be has a font size.');
  final defaultRubyTextStyle = effectiveTextStyle.merge(
    TextStyle(fontSize: effectiveTextStyle.fontSize! / 1.5),
  );

  // rt text style
  var effectiveRubyTextStyle = node.style;
  if (effectiveRubyTextStyle == null || effectiveRubyTextStyle.inherit) {
    effectiveRubyTextStyle =
        defaultRubyTextStyle.merge(effectiveRubyTextStyle);
  }
  if (boldTextOverride) {
    effectiveRubyTextStyle = effectiveRubyTextStyle
        .merge(const TextStyle(fontWeight: FontWeight.bold));
  }

  final rubyList = <String>[];
  final rtList = <String?>[];

  switch (node) {
    case LyricsTextNode():
      rubyList.add(node.text);
      rtList.add(null);
      break;
    case LyricsParentNode():
      for (final child in node.children) {
        if (child is LyricsTextNode) {
          rubyList.add(child.text);
        } else if (child is LyricsRtNode) {
          rtList.add(child.text);
        }
      }
      break;
  }

  final spans = <InlineSpan>[];
  for (var rubyIndex = 0; rubyIndex < rubyList.length; rubyIndex++) {
    final ruby = rubyList[rubyIndex];
    final rt = rubyIndex < rtList.length ? rtList[rubyIndex] : null;

    // spacing
    final text = node.text;
    if (rt != null &&
        effectiveTextStyle!.letterSpacing == null &&
        effectiveRubyTextStyle!.letterSpacing == null &&
        rt.length >= 2 &&
        text.length >= 2) {
      final rubyWidth = _measurementWidth(
        rt,
        effectiveRubyTextStyle,
        textDirection:
        textDirection ?? TextDirection.ltr,
      );
      final textWidth = _measurementWidth(
        text,
        effectiveTextStyle,
        textDirection:
        textDirection ?? TextDirection.ltr,
      );

      if (textWidth > rubyWidth) {
        final newLetterSpacing = (textWidth - rubyWidth) / rt.length;
        effectiveRubyTextStyle = effectiveRubyTextStyle
            .merge(TextStyle(letterSpacing: newLetterSpacing));
      } else {
        final newLetterSpacing = (rubyWidth - textWidth) / text.length;
        effectiveTextStyle = effectiveTextStyle
            .merge(TextStyle(letterSpacing: newLetterSpacing));
      }
    }

    if (rt == null) {
      spans.add(
        TextSpan(
          text: ruby,
          style: effectiveTextStyle,
        ),
      );
    } else {
      spans.add(
        WidgetSpan(
          child: Column(
            children: [
              Text(
                rt,
                textAlign: TextAlign.center,
                style: effectiveRubyTextStyle,
              ),
              Text(
                ruby,
                textAlign: TextAlign.center,
                style: effectiveTextStyle,
                ),
            ],
          )
        ),
      );
    }
  }

  return spans;
}

class LyricsText extends StatelessWidget {
  const LyricsText(this.data, {
    super.key,
    this.spacing = 0.0,
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.maxLines,
  });

  final List<LyricsNode> data;
  final double spacing;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final spans = data.map((LyricsNode n) => buildInlineSpans(
      context,
      data: n,
      style: style,
    )).expand((e) => e).toList();

    return Text.rich(
      TextSpan(
        children: spans,
      ),
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}

double _measurementWidth(String text, TextStyle style, {
  TextDirection textDirection = TextDirection.ltr,
}) {
  final textPainter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textAlign: TextAlign.center,
  )..layout();
  return textPainter.width;
}