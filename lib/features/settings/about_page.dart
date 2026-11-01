import 'package:flutter/material.dart';
import 'package:teigi/features/settings/about_card.dart';

export 'about_card.dart';

/// 关于界面（兼容入口，实际卡片已内嵌在设置页中）。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: AboutCard(),
      ),
    );
  }
}
