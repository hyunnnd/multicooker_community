import 'package:flutter/material.dart';

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final String? source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final imageSource = source?.trim();
    if (imageSource == null || imageSource.isEmpty) return _fallback();

    if (_isAssetSource(imageSource)) {
      return Image.asset(
        imageSource,
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }

    return Image.network(
      imageSource,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => placeholder ??
      Container(
        width: width,
        height: height,
        color: const Color(0xFFF3F4F6),
        alignment: Alignment.center,
        child: const Icon(Icons.restaurant, color: Color(0xFF9CA3AF)),
      );

  bool _isAssetSource(String value) =>
      value.startsWith('assets/') || value.startsWith('asset:');
}
