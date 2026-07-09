class RecipeInstructionStep {
  const RecipeInstructionStep({
    required this.id,
    required this.stepNo,
    required this.title,
    required this.description,
    this.imageUrl,
    this.requiresUserAction = false,
    this.actionLabel,
    this.linkedCookerStepId,
    this.estimatedTimeMin,
  });

  final String id;
  final int stepNo;
  final String title;
  final String description;
  final String? imageUrl;
  final bool requiresUserAction;
  final String? actionLabel;
  final String? linkedCookerStepId;
  final int? estimatedTimeMin;
}
