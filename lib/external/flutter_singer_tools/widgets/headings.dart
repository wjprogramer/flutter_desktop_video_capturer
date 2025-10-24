import 'package:flutter/material.dart';

class FSTitle extends StatelessWidget {
  const FSTitle(this.text, {
    super.key,
    double? topPadding,
  }) : topPadding = topPadding ?? 24;

  final String text;

  final double topPadding;

  static const double _borderWidth = 4;

  static const double _contentLeftPadding = 8;

  static const double contentResolvedLefMargin = _borderWidth + _contentLeftPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: topPadding,
        bottom: 6,
      ),
      child: Container(
        padding: const EdgeInsets.only(left: _contentLeftPadding),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.primary,
              width: _borderWidth,
            ),
          ),
        ),
        child: Text(
          text,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}
