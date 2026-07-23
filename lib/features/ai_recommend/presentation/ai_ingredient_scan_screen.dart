import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/main_navigation.dart';
import '../data/ai_recommend_result.dart';
import '../provider/ai_recommend_provider.dart';

const _blue = Color(0xFFF97316);
const _ink = Color(0xFF111827);
const _sub = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);

class AiIngredientScanScreen extends StatefulWidget {
  const AiIngredientScanScreen({super.key});

  @override
  State<AiIngredientScanScreen> createState() => _AiIngredientScanScreenState();
}

class _AiIngredientScanScreenState extends State<AiIngredientScanScreen> {
  final _picker = ImagePicker();
  XFile? _image;

  Future<void> _pick(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image != null && mounted) {
      setState(() {
        _image = image;
      });
    }
  }

  Future<void> _analyze() async {
    final image = _image;
    if (image == null) return;
    final ok = await context.read<AiRecommendProvider>().analyzeImage(
      filePath: image.path,
      filename: image.name,
      contentType: image.mimeType ?? _contentType(image.name),
    );
    if (!mounted) return;
    if (ok) {
      context.push('/ai-recommendations');
    }
  }

  String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiRecommendProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: const MainNavigationBar(currentIndex: 0),
      body: SafeArea(
        child: Column(
          children: [
            const _AiHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _border),
                      ),
                      child: _image == null
                          ? const _CaptureGuide()
                          : Image.file(File(_image!.path), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _CaptureButton(
                          icon: Icons.camera_alt_outlined,
                          label: '촬영',
                          onPressed: ai.isLoading
                              ? null
                              : () => _pick(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CaptureButton(
                          icon: Icons.photo_library_outlined,
                          label: '앨범',
                          onPressed: ai.isLoading
                              ? null
                              : () => _pick(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                  if (ai.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    const ErrorView('분석하지 못했습니다. 로그인과 네트워크 상태를 확인해주세요.'),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _image == null || ai.isLoading ? null : _analyze,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: ai.isLoading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(ai.isLoading ? '식재료를 분석하고 있어요' : '분석하고 추천받기'),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    '추천 받은 레시피',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (ai.recommendationHistory.isEmpty)
                    const _EmptyRecommendationHistory()
                  else
                    for (final recipe in ai.recommendationHistory) ...[
                      _RecommendationHistoryCard(recipe: recipe),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiHeader extends StatelessWidget {
  const _AiHeader();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
    ),
    child: const Text(
      'AI 식재료 인식',
      style: TextStyle(
        fontSize: 18,
        height: 1.2,
        fontWeight: FontWeight.w900,
        color: _ink,
      ),
    ),
  );
}

class _CaptureGuide extends StatelessWidget {
  const _CaptureGuide();

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(
        width: 60,
        height: 60,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFFFF1E6),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Icon(Icons.camera_alt_outlined, color: _blue, size: 28),
        ),
      ),
      SizedBox(height: 18),
      Text(
        '식재료가 잘 보이게 촬영해주세요',
        style: TextStyle(
          color: _ink,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(height: 6),
      Text(
        '한 화면에 겹치지 않게 놓으면\n인식이 쉬워요',
        textAlign: TextAlign.center,
        style: TextStyle(color: _sub, height: 1.5),
      ),
    ],
  );
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      foregroundColor: _ink,
      side: const BorderSide(color: _border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    icon: Icon(icon, color: _ink),
    label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _EmptyRecommendationHistory extends StatelessWidget {
  const _EmptyRecommendationHistory();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: const Row(
      children: [
        Icon(Icons.menu_book_outlined, color: _sub),
        SizedBox(width: 10),
        Text('분석한 식재료로 추천을 받아보세요', style: TextStyle(color: _sub)),
      ],
    ),
  );
}

class _RecommendationHistoryCard extends StatelessWidget {
  const _RecommendationHistoryCard({required this.recipe});

  final AiRecommendedRecipe recipe;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1E6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.restaurant_menu_rounded, color: _blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                recipe.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _sub),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(recipe.similarity * 100).round()}%',
          style: const TextStyle(
            color: _blue,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
