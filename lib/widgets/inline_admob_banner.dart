import 'package:flutter/material.dart';

import 'admob_banner.dart';

class InlineAdMobBanner extends StatelessWidget {
  const InlineAdMobBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      alignment: Alignment.center,
      child: const AdMobBanner(),
    );
  }
}
