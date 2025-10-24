import 'package:flutter/material.dart';

class Subtitle extends StatelessWidget {
  const Subtitle(this.text, {super.key});

  final String text;

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
          Text(text, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
