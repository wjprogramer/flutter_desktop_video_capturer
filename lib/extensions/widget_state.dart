import 'package:flutter/widgets.dart';

extension WidgetStateX<T extends StatefulWidget> on State<T> {
  void safeSetState([VoidCallback? fn]) {
    fn?.call();
    if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(() {});
    }
  }
}