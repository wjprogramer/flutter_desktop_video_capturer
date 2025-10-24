import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/widgets/common/typography.dart';

class ContentArea extends StatefulWidget {
  const ContentArea({
    super.key,
    required this.title,
    this.child,
    this.topMargin = 8,
    this.canExpand = true,
    this.shrinkWrap = true,
  });

  final String title;

  final Widget? child;

  final double topMargin;

  final bool canExpand;

  final bool shrinkWrap;

  @override
  State<ContentArea> createState() => _ContentAreaState();
}

class _ContentAreaState extends State<ContentArea> {
  var _expanded = true;

  bool _isHoverExpandButton = false;

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget resolvedChild = Padding(
      padding: EdgeInsets.only(left: Subtitle.leftPadding),
      child: widget.child,
    );

    if (!widget.shrinkWrap) {
      resolvedChild = Expanded(child: resolvedChild);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      children: [
        SizedBox(height: widget.topMargin),
        Subtitle(
          widget.title,
          action: !widget.canExpand
              ? null
              : MouseRegion(
                  onEnter: (_) {
                    setState(() {
                      _isHoverExpandButton = true;
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      _isHoverExpandButton = false;
                    });
                  },
                  child: AnimatedOpacity(
                    opacity: _isHoverExpandButton ? 1.0 : 0.3,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      icon: Icon(_expanded ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_up, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _toggleExpanded,
                    ),
                  ),
                ),
        ),
        SizedBox(height: 12),
        if (_expanded)
          resolvedChild,
      ],
    );
  }
}
