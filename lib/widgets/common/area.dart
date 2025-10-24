import 'package:flutter/cupertino.dart';
import 'package:flutter_desktop_video_capturer/widgets/common/typography.dart';

class ContentArea extends StatelessWidget {
  const ContentArea({super.key, required this.title, this.child, this.topMargin = 12});

  final String title;

  final Widget? child;

  final double topMargin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: topMargin),
        Subtitle(title),
        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.only(left: Subtitle.leftPadding),
          child: child,
        ),
      ],
    );
  }
}
