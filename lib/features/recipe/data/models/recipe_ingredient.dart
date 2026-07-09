class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    required this.amount,
    this.isRequired = true,
    this.isPrepared = false,
  });

  final String name;
  final String amount;
  final bool isRequired;
  final bool isPrepared;

  RecipeIngredient copyWith({bool? isPrepared}) => RecipeIngredient(
    name: name,
    amount: amount,
    isRequired: isRequired,
    isPrepared: isPrepared ?? this.isPrepared,
  );
}
