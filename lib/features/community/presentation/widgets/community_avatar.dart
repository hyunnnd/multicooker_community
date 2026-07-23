import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({
    required this.username,
    required this.colorValue,
    this.imageUrl,
    this.size = 26,
    super.key,
  });

  final String username;
  final int colorValue;
  final String? imageUrl;
  final double size;

  String? get _resolvedImageUrl {
    final raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.hasScheme) return uri.toString();
    return Uri.parse(ApiConstants.apiBaseUrl).resolve(raw).toString();
  }

  Widget _fallback() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          username.trim().isEmpty ? '?' : username.trim().characters.first,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedImageUrl;
    if (resolved == null) return _fallback();

    return ClipOval(
      child: Image.network(
        resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _fallback(),
      ),
    );
  }
}
