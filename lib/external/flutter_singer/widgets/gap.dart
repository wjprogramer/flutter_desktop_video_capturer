import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FSGap extends StatelessWidget {
  const FSGap(this.mainAxisExtent, {super.key});

  final double mainAxisExtent;

  @override
  Widget build(BuildContext context) {
    return Gap(mainAxisExtent);
  }
}
