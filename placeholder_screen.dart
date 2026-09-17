import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/background.dart';
import '../theme/typography.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: TytoText.display(size: 18)),
      ),
      body: Center(
        child: Text("$title arrive bientôt.", style: TytoText.body(size: 15, color: TytoColors.brume)),
      ),
    );
  }
}
