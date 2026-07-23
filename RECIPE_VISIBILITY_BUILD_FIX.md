# Recipe visibility build fix

Fixed the compile mismatch between the custom profile recipe-management UI and the appmaster recipe domain layer.

- Added `Recipe.visibility`, `Recipe.isPublic`, and `Recipe.visibilityLabel`.
- Added `RecipeProvider.setMyRecipeVisibility`.
- Added repository/API support for `PATCH /users/me/recipes/{recipe_id}/visibility`.
- Parsed `visibility` from catalog and personal recipe API responses.
- Kept the existing appmaster upload/edit method signatures unchanged to avoid affecting unrelated screens.
