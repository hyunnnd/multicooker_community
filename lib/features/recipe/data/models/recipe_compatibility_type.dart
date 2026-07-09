enum RecipeCompatibilityType {
  fullAuto,
  guidedCook,
  partialCook,
  complexGuidedCook,
  manualOnly,
}

extension RecipeCompatibilityTypeLabel on RecipeCompatibilityType {
  String get label => switch (this) {
    RecipeCompatibilityType.fullAuto => 'Full Auto',
    RecipeCompatibilityType.guidedCook => 'Guided Cook',
    RecipeCompatibilityType.partialCook => 'Partial Cook',
    RecipeCompatibilityType.complexGuidedCook => 'Complex Guided',
    RecipeCompatibilityType.manualOnly => 'Manual Only',
  };
}
