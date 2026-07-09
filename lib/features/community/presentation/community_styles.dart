import 'package:flutter/material.dart';

const kCommunityOrange = Color(0xFFF97316);
const kCommunityOrangeDark = Color(0xFFEA580C);
const kCommunityOrangeLight = Color(0xFFFFF7ED);
const kCommunityBackground = Color(0xFFF8FAFC);
const kCommunityText = Color(0xFF111827);
const kCommunitySubtext = Color(0xFF6B7280);
const kCommunityBorder = Color(0xFFE5E7EB);
const kCommunityCard = Colors.white;

BoxDecoration communityCardDecoration({double radius = 16}) => BoxDecoration(
      color: kCommunityCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: kCommunityBorder),
      boxShadow: const [
        BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
      ],
    );
