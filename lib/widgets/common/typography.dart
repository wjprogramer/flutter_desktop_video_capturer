import 'package:flutter/material.dart';

class Subtitle extends StatelessWidget {
  const Subtitle(this.text, {super.key, this.action});

  final String text;

  final Widget? action;

  static const double leftPadding = _borderWidth + _marginRight;

  static const double _borderWidth = 4.0;

  static const double _marginRight = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        children: [
          Container(
            width: _borderWidth,
            margin: const EdgeInsets.only(right: _marginRight, top: 2, bottom: 2),
            decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(8.0)),
          ),
          Text.rich(
            TextSpan(
              text: text,
              children: [
                if (action != null)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(padding: const EdgeInsets.only(left: 8.0), child: action!),
                  ),
              ],
            ),
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
