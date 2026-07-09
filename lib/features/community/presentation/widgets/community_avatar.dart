import 'package:flutter/material.dart';

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({
    required this.username,
    required this.colorValue,
    this.size = 26,
    super.key,
  });

  final String username;
  final int colorValue;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Color(colorValue), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        username.isEmpty ? '?' : username.characters.first,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
