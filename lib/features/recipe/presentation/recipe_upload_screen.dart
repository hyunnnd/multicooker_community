import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/language/language_provider.dart';
import '../../auth/provider/auth_provider.dart';
import '../data/models/cooker_step.dart';
import '../data/models/recipe.dart';
import '../data/models/recipe_instruction_step.dart';
import '../data/models/recipe_step.dart';
import '../provider/recipe_provider.dart';
import 'widgets/figma_recipe_widgets.dart';

class RecipeUploadScreen extends StatefulWidget {
  const RecipeUploadScreen({
    super.key,
    this.returnToMyRecipes = false,
    this.initialRecipe,
  });

  final bool returnToMyRecipes;
  final Recipe? initialRecipe;

  bool get isEditing => initialRecipe != null;

  @override
  State<RecipeUploadScreen> createState() => _RecipeUploadScreenState();
}

class _RecipeUploadScreenState extends State<RecipeUploadScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  late final List<_UploadIngredient> _ingredients;
  late final List<_UploadStage> _stages;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final recipe = widget.initialRecipe;
    if (recipe == null) {
      _ingredients = [_UploadIngredient()];
      _stages = [_UploadStage()];
      return;
    }

    _title.text = recipe.title;
    _description.text = recipe.description;
    _ingredients = recipe.ingredients.isEmpty
        ? [_UploadIngredient()]
        : recipe.ingredients
            .map(
              (ingredient) => _UploadIngredient.fromValues(
                name: ingredient.name,
                amount: ingredient.amount,
              ),
            )
            .toList(growable: true);
    _stages = [
      for (var index = 0; index < recipe.cookerSteps.length; index++)
        _UploadStage.fromRecipe(
          cookerStep: recipe.cookerSteps[index],
          instructionStep: index < recipe.instructionSteps.length
              ? recipe.instructionSteps[index]
              : null,
        ),
    ];
    if (_stages.isEmpty) _stages.add(_UploadStage());
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final item in _ingredients) {
      item.dispose();
    }
    for (final stage in _stages) {
      stage.dispose();
    }
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < 3) {
      final message = _pageError();
      if (message != null) {
        _toast(message);
        return;
      }
      setState(() => _page++);
      return;
    }
    await _submit();
  }

  String? _pageError() {
    final lang = context.read<LanguageProvider>();
    if (_page == 0 && _title.text.trim().isEmpty) {
      return lang.t('레시피 이름을 입력해 주세요.', 'Enter a recipe name.');
    }
    if (_page == 1 &&
        !_ingredients.any((item) => item.name.text.trim().isNotEmpty)) {
      return lang.t('재료를 한 개 이상 입력해 주세요.', 'Enter at least one ingredient.');
    }
    if (_page == 2) {
      for (final stage in _stages) {
        if (stage.title.text.trim().isEmpty) {
          return lang.t('단계 제목을 입력해 주세요.', 'Enter a step title.');
        }
        if (stage.description.text.trim().isEmpty) {
          return lang.t('해야 할 일을 입력해 주세요.', 'Enter what to do in this step.');
        }
        final temp = int.tryParse(stage.temperature.text);
        final min = int.tryParse(stage.minutes.text);
        if (temp == null || temp < 1 || temp > 300)
          return lang.t(
            '온도는 1~300 사이로 입력해 주세요.',
            'Enter a temperature from 1 to 300.',
          );
        if (min == null || min < 1 || min > 999)
          return lang.t(
            '시간은 1~999분 사이로 입력해 주세요.',
            'Enter minutes from 1 to 999.',
          );
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final message = _pageError();
    if (message != null) {
      _toast(message);
      return;
    }
    final auth = context.read<AuthProvider>();
    final lang = context.read<LanguageProvider>();
    if (!auth.isAuthenticated) {
      _toast(lang.t('레시피를 저장하려면 로그인해 주세요.', 'Sign in to save a recipe.'));
      context.push('/login');
      return;
    }

    var elapsedSeconds = 0;
    final steps = <RecipeStep>[];
    for (final stage in _stages) {
      elapsedSeconds += int.parse(stage.minutes.text) * 60;
      steps.add(
        RecipeStep(
          temperature: double.parse(stage.temperature.text),
          timeOffset: elapsedSeconds.toDouble(),
        ),
      );
    }

    final provider = context.read<RecipeProvider>();
    final editingRecipe = widget.initialRecipe;
    final saved = editingRecipe == null
        ? await provider.uploadRecipe(
            title: _title.text.trim(),
            description: _serverDescription(),
            steps: steps,
          )
        : await provider.updateMyRecipe(
            recipeId: editingRecipe.id,
            title: _title.text.trim(),
            description: _serverDescription(),
            steps: steps,
          );
    if (!mounted) return;
    if (!saved) {
      _toast(
        provider.errorMessage ??
            lang.t(
              widget.isEditing ? '레시피를 수정하지 못했습니다.' : '레시피를 저장하지 못했습니다.',
              widget.isEditing ? 'Could not update the recipe.' : 'Could not save the recipe.',
            ),
      );
      return;
    }

    final recipe = provider.lastUploadedRecipe;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          lang.t(
            widget.isEditing ? '레시피를 수정했어요' : '레시피를 공유했어요',
            widget.isEditing ? 'Recipe updated' : 'Recipe shared',
          ),
        ),
        content: Text(
          lang.t(
            widget.isEditing
                ? '수정한 내용이 목록과 상세 화면에 반영되었습니다.'
                : '업로드한 레시피를 목록과 상세 화면에서 확인할 수 있어요.',
            widget.isEditing
                ? 'The changes are now visible in the list and detail screen.'
                : 'You can find it in the recipe list and detail screen.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(widget.returnToMyRecipes ? '/my/recipes' : '/recipes');
            },
            child: Text(lang.t('목록 보기', 'View list')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: figmaOrange),
            onPressed: () {
              Navigator.pop(context);
              if (recipe != null) {
                provider.selectRecipe(recipe.id);
                context.go('/recipes/${recipe.id}');
              } else {
                context.go(widget.returnToMyRecipes ? '/my/recipes' : '/recipes');
              }
            },
            child: Text(lang.t('레시피 확인', 'View recipe')),
          ),
        ],
      ),
    );
  }

  String _serverDescription() {
    final ingredients = _ingredients
        .where((item) => item.name.text.trim().isNotEmpty)
        .map((item) {
          final amount = item.amount.text.trim();
          return '- ${item.name.text.trim()}${amount.isEmpty ? '' : ' $amount'}';
        })
        .join('\n');
    final desc = _description.text.trim();
    final stageText = _stages
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key + 1;
          final stage = entry.value;
          return '$index. ${stage.title.text.trim()}\n${stage.description.text.trim()}';
        })
        .join('\n');
    return [
      if (desc.isNotEmpty) desc,
      if (ingredients.isNotEmpty) '재료\n$ingredients',
      if (stageText.isNotEmpty) '조리 단계\n$stageText',
    ].join('\n\n');
  }

  int get _totalMinutes => _stages.fold(
    0,
    (sum, stage) => sum + (int.tryParse(stage.minutes.text) ?? 0),
  );

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final loading = recipeProvider.isLoading || recipeProvider.isSaving;
    final lang = context.watch<LanguageProvider>();
    final labels = [
      lang.t('기본 정보', 'Basics'),
      lang.t('재료', 'Ingredients'),
      lang.t('조리 단계', 'Steps'),
      lang.t('미리보기', 'Preview'),
    ];
    return Scaffold(
      backgroundColor: figmaBg,
      appBar: AppBar(
        title: Text(widget.isEditing ? '레시피 수정' : '레시피 등록'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => _page == 0 ? context.pop() : setState(() => _page--),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_page + 1}/${labels.length}',
                style: const TextStyle(
                  color: figmaGray400,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: figmaOrange,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: loading ? null : _next,
            child: Text(
              loading
                  ? lang.t('저장 중...', 'Saving...')
                  : (_page < 3
                        ? lang.t('다음', 'Next')
                        : lang.t(
                            widget.isEditing ? '레시피 수정하기' : '레시피 등록하기',
                            widget.isEditing ? 'Update recipe' : 'Publish recipe',
                          )),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _Progress(page: _page, labels: labels),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: ListView(
                key: ValueKey(_page),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_page == 0)
                    _BasicPage(title: _title, description: _description),
                  if (_page == 1)
                    _IngredientPage(
                      ingredients: _ingredients,
                      onChanged: () => setState(() {}),
                    ),
                  if (_page == 2)
                    _CookerPage(
                      stages: _stages,
                      onChanged: () => setState(() {}),
                    ),
                  if (_page == 3)
                    _PreviewPage(
                      title: _title.text,
                      description: _description.text,
                      ingredients: _ingredients,
                      stages: _stages,
                      totalMinutes: _totalMinutes,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadIngredient {
  _UploadIngredient();

  _UploadIngredient.fromValues({required String name, required String amount}) {
    this.name.text = name;
    this.amount.text = amount;
  }

  final name = TextEditingController();
  final amount = TextEditingController();

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _UploadStage {
  _UploadStage();

  _UploadStage.fromRecipe({
    required CookerStep cookerStep,
    RecipeInstructionStep? instructionStep,
  }) {
    title.text = instructionStep?.title.trim().isNotEmpty == true
        ? instructionStep!.title
        : cookerStep.label;
    description.text = instructionStep?.description.trim().isNotEmpty == true
        ? instructionStep!.description
        : '${cookerStep.temperature}°C에서 ${cookerStep.timeMin}분 조리합니다.';
    temperature.text = cookerStep.temperature.toString();
    minutes.text = cookerStep.timeMin.toString();
  }

  final title = TextEditingController();
  final description = TextEditingController();
  final temperature = TextEditingController(text: '180');
  final minutes = TextEditingController(text: '10');
  String? imagePath;

  void dispose() {
    title.dispose();
    description.dispose();
    temperature.dispose();
    minutes.dispose();
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.page, required this.labels});
  final int page;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: i <= page ? 1 : 0,
                    minHeight: 4,
                    backgroundColor: figmaGray100,
                    valueColor: const AlwaysStoppedAnimation(figmaOrange),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: i <= page ? figmaOrange : figmaGray400,
                  ),
                ),
              ],
            ),
          ),
          if (i != labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

class _BasicPage extends StatelessWidget {
  const _BasicPage({required this.title, required this.description});
  final TextEditingController title;
  final TextEditingController description;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageTitle(
          lang.t('기본 정보를 입력해 주세요', 'Enter the basic information'),
          lang.t(
            '레시피 이름과 짧은 소개를 먼저 적어요.',
            'Start with a name and short intro.',
          ),
        ),
        const SizedBox(height: 20),
        _Field(
          label: lang.t('레시피 이름 *', 'Recipe name *'),
          controller: title,
          hint: lang.t('예: 멀티쿠커 닭가슴살 볶음', 'Ex. Multi-cooker chicken stir-fry'),
        ),
        const SizedBox(height: 14),
        _Field(
          label: lang.t('소개글', 'Intro'),
          controller: description,
          hint: lang.t('이 레시피를 간단히 소개해 주세요.', 'Briefly introduce this recipe.'),
          maxLines: 4,
        ),
      ],
    );
  }
}

class _IngredientPage extends StatelessWidget {
  const _IngredientPage({required this.ingredients, required this.onChanged});
  final List<_UploadIngredient> ingredients;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final count = ingredients
        .where((item) => item.name.text.trim().isNotEmpty)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageTitle(
          lang.t('재료를 입력해 주세요', 'Enter ingredients'),
          lang.t('$count개 입력됨', '$count entered'),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < ingredients.length; i++) ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _Field(
                  label: i == 0 ? lang.t('재료명', 'Ingredient') : '',
                  controller: ingredients[i].name,
                  hint: lang.t('재료명', 'Ingredient'),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _Field(
                  label: i == 0 ? lang.t('양', 'Amount') : '',
                  controller: ingredients[i].amount,
                  hint: '300g',
                  onChanged: (_) => onChanged(),
                ),
              ),
              if (ingredients.length > 1)
                IconButton(
                  tooltip: lang.t('재료 삭제', 'Remove ingredient'),
                  onPressed: () {
                    ingredients.removeAt(i).dispose();
                    onChanged();
                  },
                  icon: const Icon(Icons.close_rounded, color: figmaGray400),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          style: _outlineStyle(),
          onPressed: () {
            ingredients.add(_UploadIngredient());
            onChanged();
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(lang.t('재료 추가', 'Add ingredient')),
        ),
        const SizedBox(height: 14),
        _Tip(
          lang.t(
            '재료 정보는 현재 서버 필드가 없어 소개글에 함께 저장됩니다.',
            'Ingredient data is saved together with the intro because the server has no separate field yet.',
          ),
        ),
      ],
    );
  }
}

class _CookerPage extends StatelessWidget {
  const _CookerPage({required this.stages, required this.onChanged});
  final List<_UploadStage> stages;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageTitle(
          lang.t('쿠커 조리값을 입력해 주세요', 'Enter cooker settings'),
          lang.t('${stages.length}/10단계', '${stages.length}/10 steps'),
        ),
        const SizedBox(height: 8),
        Text(
          lang.t(
            '서버에는 각 단계의 종료 시점을 누적 초 단위로 변환해 저장합니다.',
            'Each step is saved as a cumulative end time in seconds.',
          ),
          style: const TextStyle(
            fontSize: 12,
            color: figmaGray500,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < stages.length; i++) ...[
          _StageCard(
            index: i,
            stage: stages[i],
            canRemove: stages.length > 1,
            onRemove: () {
              stages.removeAt(i).dispose();
              onChanged();
            },
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
        ],
        if (stages.length < 10)
          OutlinedButton.icon(
            style: _outlineStyle(),
            onPressed: () {
              stages.add(_UploadStage());
              onChanged();
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(lang.t('조리 단계 추가', 'Add cooking step')),
          ),
      ],
    );
  }
}

class _PreviewPage extends StatelessWidget {
  const _PreviewPage({
    required this.title,
    required this.description,
    required this.ingredients,
    required this.stages,
    required this.totalMinutes,
  });
  final String title;
  final String description;
  final List<_UploadIngredient> ingredients;
  final List<_UploadStage> stages;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final filledIngredients = ingredients
        .where((item) => item.name.text.trim().isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageTitle(
          lang.t('등록 전 미리보기', 'Preview before publishing'),
          lang.t('공유될 내용을 한 번 확인해 주세요.', 'Review what will be shared.'),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const UserBadge(tiny: true),
                  const SizedBox(width: 8),
                  Text(
                    '$totalMinutes분',
                    style: const TextStyle(
                      color: figmaGray500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title.isEmpty ? lang.t('레시피 제목', 'Recipe title') : title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: figmaGray900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description.isEmpty
                    ? lang.t(
                        '레시피 소개글이 여기에 표시됩니다.',
                        'Recipe intro will appear here.',
                      )
                    : description,
                style: const TextStyle(color: figmaGray500, height: 1.45),
              ),
              const SizedBox(height: 18),
              Text(
                lang.t('재료', 'Ingredients'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: figmaGray900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in filledIngredients)
                    Chip(
                      backgroundColor: figmaOrangeLight,
                      side: BorderSide.none,
                      label: Text(
                        '${item.name.text.trim()} ${item.amount.text.trim()}'
                            .trim(),
                        style: const TextStyle(
                          color: figmaOrange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                lang.t('조리 단계', 'Cooking steps'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: figmaGray900,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < stages.length; i++) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: figmaGray50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: figmaGray100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stages[i].imagePath != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(stages[i].imagePath!),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          _Dot('${i + 1}'),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              stages[i].title.text.trim().isEmpty
                                  ? lang.t('${i + 1}단계', 'Step ${i + 1}')
                                  : stages[i].title.text.trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: figmaGray900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stages[i].description.text.trim(),
                        style: const TextStyle(
                          color: figmaGray500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${stages[i].temperature.text}°C · ${stages[i].minutes.text}${lang.t('분', ' min')}',
                        style: const TextStyle(
                          color: figmaOrange,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Tip(
          lang.t(
            '등록 후 서버 조회 결과에 포함되면 다른 사용자 목록에도 같은 방식으로 노출됩니다.',
            'After publishing, it appears in other users’ lists if the server returns it.',
          ),
        ),
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.index,
    required this.stage,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });
  final int index;
  final _UploadStage stage;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;
    stage.imagePath = image.path;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              _Dot('${index + 1}'),
              const SizedBox(width: 8),
              Text(
                lang.t('${index + 1}단계', 'Step ${index + 1}'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: figmaGray900,
                ),
              ),
              const Spacer(),
              if (canRemove)
                IconButton(
                  tooltip: lang.t('단계 삭제', 'Remove step'),
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: figmaGray400,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _Field(
            label: '',
            controller: stage.title,
            hint: lang.t('단계 제목 (ex. 예열하기)', 'Step title (ex. Preheat)'),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          _Field(
            label: '',
            controller: stage.description,
            hint: lang.t(
              '이 단계에서 해야 할 일을 설명해 주세요',
              'Describe what to do in this step',
            ),
            maxLines: 3,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickImage,
            child: Container(
              height: stage.imagePath == null ? 92 : 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: figmaGray200,
                  width: 1.4,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: stage.imagePath == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.photo_camera_outlined,
                          color: figmaGray400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang.t('단계 사진 추가', 'Add step photo'),
                          style: const TextStyle(
                            color: figmaGray400,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(stage.imagePath!), fit: BoxFit.cover),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: Text(
                                lang.t('변경', 'Change'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: figmaNavy,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.thermostat_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lang.t('쿠커 설정 켜짐', 'Cooker settings on'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: lang.t('온도 (°C)', 'Temp (°C)'),
                  controller: stage.temperature,
                  hint: '180',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: lang.t('시간 (분)', 'Time (min)'),
                  controller: stage.minutes,
                  hint: '10',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label.isNotEmpty) ...[
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: figmaGray700,
          ),
        ),
        const SizedBox(height: 8),
      ],
      TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: _border(),
          enabledBorder: _border(),
          focusedBorder: _border(figmaOrange),
        ),
      ),
    ],
  );
}

class _PageTitle extends StatelessWidget {
  const _PageTitle(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: figmaGray900,
        ),
      ),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: figmaGray500, height: 1.45)),
    ],
  );
}

class _Tip extends StatelessWidget {
  const _Tip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: figmaOrangeLight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: figmaOrange.withOpacity(0.18)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: figmaOrangeDark,
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: figmaOrange, shape: BoxShape.circle),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  border: Border.all(color: figmaGray100),
  borderRadius: BorderRadius.circular(12),
);

OutlineInputBorder _border([Color color = figmaGray100]) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(8),
  borderSide: BorderSide(color: color),
);

ButtonStyle _outlineStyle() => OutlinedButton.styleFrom(
  foregroundColor: figmaOrange,
  side: const BorderSide(color: figmaOrange),
  minimumSize: const Size.fromHeight(46),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
);
