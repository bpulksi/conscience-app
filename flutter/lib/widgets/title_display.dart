import 'package:flutter/material.dart';

class TitleDisplay extends StatelessWidget {
  final String customTitle;
  final String displayName;
  final TextAlign textAlign;

  const TitleDisplay({
    super.key,
    required this.customTitle,
    required this.displayName,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          customTitle,
          textAlign: textAlign,
          style: const TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            color: Colors.deepPurple,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          displayName,
          textAlign: textAlign,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
