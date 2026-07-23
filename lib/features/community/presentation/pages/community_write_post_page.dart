part of '../community_screen.dart';

class _WritePostPage extends StatefulWidget {
  const _WritePostPage({
    super.key,
    required this.onBack,
    required this.onSubmit,
    this.initialCategory,
    this.initialPost,
  });

  final VoidCallback onBack;
  final Future<bool> Function(
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

class _WritePostPageState extends State<_WritePostPage> with WidgetsBindingObserver {
  late PostCategory _category;
  late final TextEditingController _title;
  late final TextEditingController _content;

  final _imagePicker = ImagePicker();
  final _draftStorage = CommunityDraftStorage();

  Timer? _draftTimer;
  String _draftAccountKey = '';
  bool _restoringDraft = false;
  bool _draftRestored = false;

  Uint8List? _previewBytes;
  String? _previewImage;
  String? _pickedFilename;
  String? _pickedImagePath;
  bool _imageRemoved = false;
  bool _submitting = false;
  bool _submissionCompleted = false;

  bool get _isEdit => widget.initialPost != null;

  bool get _canSubmit =>
      _title.text.trim().isNotEmpty &&
      _content.text.trim().isNotEmpty &&
      _content.text.length <= 2000 &&
      !_submitting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _category = widget.initialPost?.category ?? widget.initialCategory ?? PostCategory.free;

    _title = TextEditingController(text: widget.initialPost?.title ?? '')
      ..addListener(_onDraftFieldChanged);

    _content = TextEditingController(text: widget.initialPost?.content ?? '')
      ..addListener(_onDraftFieldChanged);

    _previewImage = widget.initialPost?.imageUrl;
    if (!_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    if (!_isEdit && !_submissionCompleted && _draftAccountKey.isNotEmpty) {
      unawaited(_saveDraft());
    }
    _title
      ..removeListener(_onDraftFieldChanged)
      ..dispose();
    _content
      ..removeListener(_onDraftFieldChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isEdit || _submissionCompleted) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_saveDraft());
    }
  }

  void _onDraftFieldChanged() {
    if (mounted) setState(() {});
    if (_isEdit || _restoringDraft) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), _saveDraft);
  }

  String _currentAccountKey() {
    final auth = context.read<AuthProvider>();
    return auth.currentEmail ?? auth.currentNickname ?? 'guest';
  }

  Future<void> _restoreDraft() async {
    if (!mounted || _isEdit) return;
    _draftAccountKey = _currentAccountKey();
    final draft = await _draftStorage.read(_draftAccountKey);
    if (!mounted || draft == null || draft.isEmpty) return;
    _restoringDraft = true;
    _title.text = draft.title;
    _content.text = draft.content;
    final imagePath = draft.imagePath;
    Uint8List? restoredImage;
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = io.File(imagePath);
      if (await file.exists()) {
        restoredImage = await file.readAsBytes();
      }
    }
    if (!mounted) return;
    setState(() {
      _category = draft.category;
      _pickedImagePath = restoredImage == null ? null : imagePath;
      _pickedFilename = restoredImage == null
          ? null
          : imagePath!.split(RegExp(r'[\/]')).last;
      _previewBytes = restoredImage;
      _draftRestored = true;
    });
    _restoringDraft = false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('임시 저장된 게시글을 불러왔습니다.')),
    );
  }

  Future<void> _saveDraft() async {
    if (_isEdit) return;
    _draftAccountKey = _draftAccountKey.isEmpty
        ? _currentAccountKey()
        : _draftAccountKey;
    await _draftStorage.write(
      _draftAccountKey,
      CommunityPostDraft(
        category: _category,
        title: _title.text,
        content: _content.text,
        imagePath: _pickedImagePath,
        savedAt: DateTime.now(),
      ),
    );
  }

  void _setCategory(PostCategory category) {
    setState(() => _category = category);
    _onDraftFieldChanged();
  }

  Future<void> requestBack() async {
    if (_isEdit || (_title.text.trim().isEmpty && _content.text.trim().isEmpty)) {
      widget.onBack();
      return;
    }
    await _saveDraft();
    if (!mounted) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('게시글 작성을 종료하시겠습니까?'),
        content: const Text('작성 중인 내용은 임시 저장되어 다음에 다시 불러옵니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('계속 작성'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) widget.onBack();
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _previewBytes = bytes;
      _pickedFilename = picked.name;
      _pickedImagePath = picked.path;
      _previewImage = null;
      _imageRemoved = false;
    });
    _onDraftFieldChanged();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _submitting = true);
    try {
      var imageUrl = _previewImage;
      if (_previewBytes != null) {
        imageUrl = await context.read<CommunityProvider>().uploadPostImage(
              bytes: _previewBytes!,
              filename: _pickedFilename ?? 'community.jpg',
            );
      } else if (_imageRemoved) {
        imageUrl = '';
      }

      final succeeded = await widget.onSubmit(
        _category,
        _title.text.trim(),
        _content.text.trim(),
        imageUrl,
      );
      if (succeeded) {
        _submissionCompleted = true;
        if (!_isEdit && _draftAccountKey.isNotEmpty) {
          await _draftStorage.clear(_draftAccountKey);
        }
        if (mounted) widget.onBack();
      }
    } catch (_) {
      if (mounted) {
        final message = context.read<CommunityProvider>().errorMessage ??
            '사진을 업로드하지 못했습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                  SizedBox(
                    width: 48,
                    child: AppBackButton(onPressed: requestBack),
                  ),
                  Expanded(
                    child: Text(
                      _isEdit ? '게시글 수정' : '게시글 작성',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
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
                                onTap: () => _setCategory(PostCategory.free),
                              ),
                              const SizedBox(width: 8),
                              _CategorySelect(
                                label: 'Q&A',
                                selected: _category == PostCategory.qa,
                                onTap: () => _setCategory(PostCategory.qa),
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
                          if (_draftRestored) ...[
                            const SizedBox(height: 8),
                            const Text(
                              '임시 저장본이 복원되었습니다.',
                              style: TextStyle(fontSize: 11, color: _orangeText),
                            ),
                          ],
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
                        maxLength: 2000,
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
                          counterText: '',
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.75,
                          color: _text2,
                        ),
                      ),
                    ),

                    if (_previewBytes != null ||
                        (_previewImage != null && _previewImage!.isNotEmpty))
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
                                onTap: () {
                                  setState(() {
                                    _previewImage = null;
                                    _previewBytes = null;
                                    _pickedFilename = null;
                                    _pickedImagePath = null;
                                    _imageRemoved = _isEdit;
                                  });
                                  _onDraftFieldChanged();
                                },
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
                    '${_content.text.length}/2,000자',
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
