import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/main_navigation.dart';
import '../provider/ai_recommend_provider.dart';

const _blue = Color(0xFF2F80ED);
const _blueSoft = Color(0xFFEAF2FF);
const _ink = Color(0xFF292929);
const _sub = Color(0xFF77736C);
const _border = Color(0xFFE8E2D7);

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
    if (image != null && mounted) setState(() => _image = image);
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
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('AI 식재료 인식'),
      ),
      bottomNavigationBar: const MainNavigationBar(currentIndex: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _blueSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: _image == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 56,
                            color: _blue,
                          ),
                          SizedBox(height: 14),
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
                            '한 화면에 겹치지 않게 놓으면 인식이 쉬워요',
                            style: TextStyle(color: _sub),
                          ),
                        ],
                      )
                    : Image.file(File(_image!.path), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: ai.isLoading
                        ? null
                        : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('촬영'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: ai.isLoading
                        ? null
                        : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('앨범'),
                  ),
                ),
              ],
            ),
            if (ai.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                '분석하지 못했습니다. 로그인과 네트워크 상태를 확인해주세요.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _image == null || ai.isLoading ? null : _analyze,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
          ],
        ),
      ),
    );
  }
}
