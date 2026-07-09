part of '../community_screen.dart';

class _WritePostPage extends StatefulWidget {
  const _WritePostPage({
    required this.onBack,
    required this.onSubmit,
    this.initialCategory,
    this.initialPost,
  });

  final VoidCallback onBack;
  final Future<void> Function(
    PostCategory category,
    String title,
    String content,
    String? imageUrl,
  ) onSubmit;
  final PostCategory? initialCategory;
  final CommunityPost? initialPost;

  @override
  State<_WritePostPage> createState() => _WritePostPageState();
}

class _WritePostPageState extends State<_WritePostPage> {
  late PostCategory _category;
  late final TextEditingController _title;
  late final TextEditingController _content;

  final _imagePicker = ImagePicker();

  Uint8List? _previewBytes;
  String? _previewImage;
  bool _submitting = false;

  bool get _isEdit => widget.initialPost != null;

  bool get _canSubmit =>
      _title.text.trim().isNotEmpty &&
      _content.text.trim().isNotEmpty &&
      !_submitting;

  @override
  void initState() {
    super.initState();
    _category = widget.initialPost?.category ?? widget.initialCategory ?? PostCategory.free;

    _title = TextEditingController(text: widget.initialPost?.title ?? '')
      ..addListener(() {
        if (mounted) setState(() {});
      });

    _content = TextEditingController(text: widget.initialPost?.content ?? '')
      ..addListener(() {
        if (mounted) setState(() {});
      });

    _previewImage = widget.initialPost?.imageUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _previewBytes = bytes;
      _previewImage = picked.path;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _submitting = true);
    await widget.onSubmit(
      _category,
      _title.text.trim(),
      _content.text.trim(),
      _previewImage,
    );

    if (mounted) setState(() => _submitting = false);
  }

  InputDecoration _plainInputDecoration({
    required String hintText,
    required TextStyle hintStyle,
    String? counterText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle,
      counterText: counterText,
      filled: true,
      fillColor: Colors.white,
      hoverColor: Colors.white,
      focusColor: Colors.white,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      isCollapsed: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
      ),
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _gray100)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: const SizedBox(
                      width: 48,
                      child: Icon(Icons.arrow_back, size: 20, color: _gray500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _isEdit ? '게시글 수정' : '게시글 작성',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _text,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _canSubmit ? _submit : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _canSubmit ? _orange : _gray100,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _isEdit ? '완료' : '등록',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _canSubmit ? Colors.white : _gray400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ColoredBox(
                color: Colors.white,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('게시판', style: TextStyle(fontSize: 12, color: _gray400)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _CategorySelect(
                                label: '자유',
                                selected: _category == PostCategory.free,
                                onTap: () => setState(() => _category = PostCategory.free),
                              ),
                              const SizedBox(width: 8),
                              _CategorySelect(
                                label: 'Q&A',
                                selected: _category == PostCategory.qa,
                                onTap: () => setState(() => _category = PostCategory.qa),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _category == PostCategory.qa
                                ? '사용법, 레시피 등 궁금한 걸 물어봐요'
                                : '일상, 꿀팁 등 자유롭게 이야기해요',
                            style: const TextStyle(fontSize: 12, color: _gray400),
                          ),
                        ],
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Divider(height: 1, color: _gray100),
                    ),

                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: TextField(
                        controller: _title,
                        maxLength: 50,
                        cursorColor: _orange,
                        decoration: _plainInputDecoration(
                          hintText: '제목을 입력하세요',
                          counterText: '',
                          hintStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _gray300,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _text,
                        ),
                      ),
                    ),

                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_title.text.length}/50',
                          style: const TextStyle(fontSize: 11, color: _gray300),
                        ),
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 2, 16, 0),
                      child: Divider(height: 1, color: _gray100),
                    ),

                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
                      child: TextField(
                        controller: _content,
                        minLines: 9,
                        maxLines: 16,
                        cursorColor: _orange,
                        decoration: _plainInputDecoration(
                          hintText: _category == PostCategory.qa
                              ? '궁금한 점을 자세히 적어주세요.\n(모델명, 조리 방법 등을 함께 적으면 더 좋아요)'
                              : '내용을 자유롭게 입력하세요.',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            height: 1.75,
                            color: _gray300,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.75,
                          color: _text2,
                        ),
                      ),
                    ),

                    if (_previewImage != null && _previewImage!.isNotEmpty)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _previewBytes != null
                                  ? Image.memory(
                                      _previewBytes!,
                                      width: 112,
                                      height: 112,
                                      fit: BoxFit.cover,
                                    )
                                  : _NetworkImageBox(
                                      url: _previewImage!,
                                      width: 112,
                                      height: 112,
                                    ),
                            ),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _previewImage = null;
                                  _previewBytes = null;
                                }),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _gray100)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: const Row(
                      children: [
                        Icon(Icons.image_outlined, size: 20, color: _gray500),
                        SizedBox(width: 6),
                        Text('사진', style: TextStyle(fontSize: 13, color: _gray500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('|', style: TextStyle(fontSize: 16, color: _gray200)),
                  const Spacer(),
                  Text(
                    _content.text.isNotEmpty ? '${_content.text.length}자' : '최대 2,000자',
                    style: const TextStyle(fontSize: 12, color: _gray400),
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
