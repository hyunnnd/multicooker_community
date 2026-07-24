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
  final Future<void> Function(
    String recipeId,
    String recipeTitle,
    String recipeImage,
    String? reviewImageUrl,
    int rating,
    String content,
  ) onSubmit;

  @override
  State<_WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<_WriteReviewPage> {
  late final TextEditingController _recipeController;
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();
  Uint8List? _reviewImageBytes;
  String? _reviewImageFilename;
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _gray100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      '사진 첨부',
                      style: TextStyle(
                        fontSize: 12,
                        color: _gray500,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 5),
                    Text(
                      '(선택)',
                      style: TextStyle(fontSize: 11, color: _gray400),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_reviewImageBytes == null)
                  InkWell(
                    onTap: _submitting ? null : _pickReviewImage,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 104,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _gray100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _gray200),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 30, color: _gray500),
                          SizedBox(height: 7),
                          Text(
                            '조리 결과 사진 추가',
                            style: TextStyle(
                              fontSize: 13,
                              color: _gray500,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '사진은 1장까지 등록할 수 있습니다.',
                            style: TextStyle(fontSize: 11, color: _gray400),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          _reviewImageBytes!,
                          width: double.infinity,
                          height: 210,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _submitting
                                ? null
                                : () => setState(() {
                                      _reviewImageBytes = null;
                                      _reviewImageFilename = null;
                                    }),
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(Icons.close_rounded, size: 19, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: FilledButton.tonalIcon(
                          onPressed: _submitting ? null : _pickReviewImage,
                          icon: const Icon(Icons.photo_library_outlined, size: 17),
                          label: const Text('사진 변경'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
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

  Future<void> _pickReviewImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _reviewImageBytes = bytes;
      _reviewImageFilename = picked.name;
    });
  }

  Future<void> _submit() async {
    if (_recipeController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      return;
    }
    setState(() => _submitting = true);
    try {
      String? reviewImageUrl;
      if (_reviewImageBytes != null) {
        reviewImageUrl = await context.read<CommunityProvider>().uploadPostImage(
              bytes: _reviewImageBytes!,
              filename: _reviewImageFilename ?? 'review.jpg',
            );
      }
      await widget.onSubmit(
        widget.initialRecipeId.isEmpty
            ? _recipeController.text.trim()
            : widget.initialRecipeId,
        _recipeController.text.trim(),
        widget.initialRecipeImage,
        reviewImageUrl,
        _rating,
        _contentController.text.trim(),
      );
    } catch (_) {
      if (mounted) {
        final message = context.read<CommunityProvider>().errorMessage ??
            '후기 사진을 업로드하지 못했습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
