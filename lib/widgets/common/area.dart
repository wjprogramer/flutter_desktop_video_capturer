import 'package:flutter/cupertino.dart';
import 'package:flutter_desktop_video_capturer/widgets/common/typography.dart';

class ContentArea extends StatelessWidget {
  const ContentArea({super.key, required this.title, this.child});

  final String title;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Subtitle(title),
        Padding(
          padding: EdgeInsets.only(left: Subtitle.leftPadding),
          child: child,
        ),
      ],
    );
  }
}
