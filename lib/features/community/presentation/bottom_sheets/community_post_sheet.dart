import 'package:flutter/material.dart';

import '../../../../core/widgets/app_image.dart';

import '../../data/models/community_models.dart';
import '../community_styles.dart';

class CommunityPostSheet extends StatefulWidget {
  const CommunityPostSheet({
    required this.title,
    required this.onBack,
    required this.onSubmit,
    this.initialPost,
    super.key,
  });

  final String title;
  final CommunityPost? initialPost;
  final VoidCallback onBack;
  final void Function(PostCategory category, String title, String content, String? imageUrl) onSubmit;

  @override
  State<CommunityPostSheet> createState() => _CommunityPostSheetState();
}

class _CommunityPostSheetState extends State<CommunityPostSheet> {
  late PostCategory _category;
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _imageController;
  bool _showImageUrl = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialPost?.category ?? PostCategory.free;
    _titleController = TextEditingController(text: widget.initialPost?.title ?? '');
    _contentController = TextEditingController(text: widget.initialPost?.content ?? '');
    _imageController = TextEditingController(text: widget.initialPost?.imageUrl ?? '');
    _showImageUrl = _imageController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  String get _categoryDescription => _category == PostCategory.free ? '일상, 꿀팁 등 자유롭게 이야기해요' : '사용법, 레시피 등 궁금한 걸 물어봐요';

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialPost != null;
    final valid = _titleController.text.trim().isNotEmpty && _contentController.text.trim().isNotEmpty;
    final imageUrl = _imageController.text.trim();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF4B5563)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      isEdit ? '게시글 수정' : '게시글 작성',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: valid
                            ? () => widget.onSubmit(
                                  _category,
                                  _titleController.text,
                                  _contentController.text,
                                  imageUrl.isEmpty ? null : imageUrl,
                                )
                            : null,
                        style: TextButton.styleFrom(
                          backgroundColor: valid ? kCommunityOrange : const Color(0xFFF3F4F6),
                          foregroundColor: valid ? Colors.white : const Color(0xFF9CA3AF),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: Text(isEdit ? '완료' : '등록', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('게시판', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _CategoryPill(
                              category: PostCategory.free,
                              selected: _category == PostCategory.free,
                              onTap: () => setState(() => _category = PostCategory.free),
                            ),
                            const SizedBox(width: 8),
                            _CategoryPill(
                              category: PostCategory.qa,
                              selected: _category == PostCategory.qa,
                              onTap: () => setState(() => _category = PostCategory.qa),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_categoryDescription, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                  const _ThinDivider(top: 18),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: TextField(
                      controller: _titleController,
                      onChanged: (_) => setState(() {}),
                      maxLength: 50,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                      decoration: const InputDecoration(
                        hintText: '제목을 입력하세요',
                        hintStyle: TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w700),
                        counterStyle: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const _ThinDivider(top: 4),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TextField(
                      controller: _contentController,
                      onChanged: (_) => setState(() {}),
                      minLines: 10,
                      maxLines: 16,
                      maxLength: 2000,
                      style: const TextStyle(fontSize: 14, height: 1.75, color: Color(0xFF374151)),
                      decoration: InputDecoration(
                        hintText: _category == PostCategory.qa
                            ? '궁금한 점을 자세히 적어주세요.\n(모델명, 조리 방법 등을 함께 적으면 더 좋아요)'
                            : '내용을 자유롭게 입력하세요.',
                        hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                        counterText: '',
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_showImageUrl) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: TextField(
                        controller: _imageController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '이미지 URL을 입력하세요',
                          prefixIcon: const Icon(Icons.image_outlined, size: 18),
                          suffixIcon: imageUrl.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () => setState(_imageController.clear),
                                  icon: const Icon(Icons.close, size: 16),
                                ),
                        ),
                      ),
                    ),
                    if (imageUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AppImage(
                                source: imageUrl,
                                width: 112,
                                height: 112,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  width: 112,
                                  height: 112,
                                  alignment: Alignment.center,
                                  color: const Color(0xFFF3F4F6),
                                  child: const Icon(Icons.image_not_supported_outlined, color: kCommunitySubtext),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: InkWell(
                                onTap: () => setState(() {
                                  _imageController.clear();
                                  _showImageUrl = false;
                                }),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(.6), shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))) ,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _showImageUrl = !_showImageUrl),
                    icon: const Icon(Icons.image_outlined, size: 20),
                    label: const Text('사진'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF6B7280), padding: EdgeInsets.zero),
                  ),
                  const SizedBox(width: 10),
                  const Text('|', style: TextStyle(color: Color(0xFFE5E7EB), fontSize: 16)),
                  const Spacer(),
                  Text(
                    _contentController.text.isNotEmpty ? '${_contentController.text.length}자' : '최대 2,000자',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category, required this.selected, required this.onTap});

  final PostCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = category == PostCategory.free ? const Color(0xFF2563EB) : kCommunityOrange;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? activeColor : kCommunityBorder),
        ),
        child: Text(
          category.label,
          style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, color: selected ? Colors.white : const Color(0xFF9CA3AF)),
        ),
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider({this.top = 0});
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, left: 16, right: 16),
        child: Container(height: 1, color: const Color(0xFFF3F4F6)),
      );
}
