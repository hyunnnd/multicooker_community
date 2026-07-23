part of '../community_screen.dart';

class _WriteReviewPage extends StatefulWidget {
  const _WriteReviewPage({
    required this.initialRecipeId,
    required this.initialRecipeTitle,
    required this.initialRecipeImage,
    required this.initialRating,
    required this.onBack,
    required this.onSubmit,
  });

  final String initialRecipeId;
  final String initialRecipeTitle;
  final String initialRecipeImage;
  final int initialRating;
  final VoidCallback onBack;
  final Future<void> Function(String recipeId, String recipeTitle, String recipeImage, int rating, String content) onSubmit;

  @override
  State<_WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<_WriteReviewPage> {
  late final TextEditingController _recipeController;
  final _contentController = TextEditingController();
  late int _rating;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _recipeController = TextEditingController(text: widget.initialRecipeTitle);
    _rating = widget.initialRating.clamp(1, 5).toInt();
  }

  @override
  void dispose() {
    _recipeController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: AppBackButton(onPressed: widget.onBack),
        title: const Text('후기 작성'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: const Text('등록', style: TextStyle(color: _orange, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _gray100)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('리뷰할 레시피', style: TextStyle(fontSize: 12, color: _gray500, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _recipeController,
                  readOnly: widget.initialRecipeId.isNotEmpty,
                  decoration: InputDecoration(
                    hintText: '레시피 이름을 입력하세요',
                    filled: true,
                    fillColor: widget.initialRecipeId.isNotEmpty
                        ? _gray100
                        : Colors.white,
                  ),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _text),
                ),
                const SizedBox(height: 14),
                const Text('별점', style: TextStyle(fontSize: 12, color: _gray500, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      GestureDetector(
                        onTap: () => setState(() => _rating = i),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.star_rounded, size: 32, color: i <= _rating ? _yellow : _gray200),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text('$_rating점', style: const TextStyle(fontSize: 13, color: _text2, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _gray100)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('후기 내용', style: TextStyle(fontSize: 12, color: _gray500, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  minLines: 8,
                  maxLines: 12,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: '조리 결과, 맛, 시간, 온도 설정에 대한 후기를 작성해 주세요.',
                    counterStyle: TextStyle(fontSize: 11, color: _gray400),
                  ),
                  style: const TextStyle(fontSize: 14, height: 1.5, color: _text2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _orange,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(_submitting ? '등록 중...' : '후기 등록', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_recipeController.text.trim().isEmpty || _contentController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    await widget.onSubmit(
      widget.initialRecipeId.isEmpty ? _recipeController.text.trim() : widget.initialRecipeId,
      _recipeController.text.trim(),
      widget.initialRecipeImage,
      _rating,
      _contentController.text.trim(),
    );
    if (mounted) setState(() => _submitting = false);
  }
}
