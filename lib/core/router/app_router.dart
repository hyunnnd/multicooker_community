import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_recommend/presentation/ai_ingredient_scan_screen.dart';
import '../../features/ai_recommend/presentation/ai_recipe_recommendation_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_complete_screen.dart';
import '../../features/auth/presentation/register_email_screen.dart';
import '../../features/auth/presentation/register_verify_code_screen.dart';
import '../../features/auth/presentation/reset_password_complete_screen.dart';
import '../../features/auth/presentation/reset_password_email_screen.dart';
import '../../features/auth/presentation/reset_password_verify_code_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/cooking/presentation/cooking_complete_screen.dart';
import '../../features/cooking/presentation/cooking_preparation_screen.dart';
import '../../features/cooking/presentation/recipe_cooking_flow_screen.dart';
import '../../features/device/presentation/device_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/pet/presentation/pet_test_screen.dart';
import '../../features/profile/presentation/profile_pages.dart';
import '../../features/recipe/data/models/recipe.dart';
import '../../features/recipe/presentation/recipe_browse_screens.dart';
import '../../features/recipe/presentation/recipe_detail_screen.dart';
import '../../features/recipe/presentation/recipe_list_screen.dart';
import '../../features/recipe/presentation/recipe_results_screen.dart';
import '../../features/recipe/presentation/recipe_search_screen.dart';
import '../../features/recipe/presentation/recipe_upload_screen.dart';
import '../../features/recipe/provider/recipe_provider.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../widgets/app_back_paths.dart';
import '../widgets/main_route_back_scope.dart';


Widget _withBackFallback(
  GoRouterState state,
  Widget child, {
  String? fallbackPath,
}) {
  return MainRouteBackScope(
    popCurrentRouteFirst: true,
    fallbackPath: fallbackPath ?? appBackFallbackForPath(state.uri.path),
    child: child,
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterEmailScreen()),
    GoRoute(
      path: '/register/verify',
      builder: (_, state) => RegisterVerifyCodeScreen(
        email: state.uri.queryParameters['email'] ?? '',
      ),
    ),
    GoRoute(
      path: '/register/complete',
      builder: (_, state) => RegisterCompleteScreen(
        email: state.uri.queryParameters['email'] ?? '',
      ),
    ),
    GoRoute(
      path: '/reset',
      builder: (_, _) => const ResetPasswordEmailScreen(),
    ),
    GoRoute(
      path: '/reset/verify',
      builder: (_, state) => ResetPasswordVerifyCodeScreen(
        email: state.uri.queryParameters['email'] ?? '',
      ),
    ),
    GoRoute(
      path: '/reset/complete',
      builder: (_, state) => ResetPasswordCompleteScreen(
        email: state.uri.queryParameters['email'] ?? '',
      ),
    ),
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: '/pet-test',
      builder: (_, state) =>
          _withBackFallback(state, const PetTestScreen()),
    ),
    GoRoute(
      path: '/device',
      builder: (_, state) =>
          _withBackFallback(state, const DeviceScreen()),
    ),
    GoRoute(path: '/recipes', builder: (_, _) => const RecipeListScreen()),
    GoRoute(
      path: '/recipes/upload',
      builder: (_, state) =>
          _withBackFallback(state, const RecipeUploadScreen()),
    ),
    GoRoute(
      path: '/recipes/search',
      builder: (_, state) =>
          _withBackFallback(state, const RecipeSearchScreen()),
    ),
    GoRoute(
      path: '/recipes/cook-method',
      builder: (_, state) =>
          _withBackFallback(state, const CookMethodScreen()),
    ),
    GoRoute(
      path: '/recipes/food-type',
      builder: (_, state) =>
          _withBackFallback(state, const FoodTypeScreen()),
    ),
    GoRoute(
      path: '/recipes/themes',
      builder: (_, state) =>
          _withBackFallback(state, const ThemeSelectScreen()),
    ),
    GoRoute(
      path: '/recipes/browse',
      builder: (_, state) => _withBackFallback(
        state,
        RecipeBrowseListScreen(
          title: state.uri.queryParameters['title'] ?? '레시피',
          type: state.uri.queryParameters['type'] ?? '전체',
        ),
      ),
    ),
    GoRoute(
      path: '/recipes/results',
      builder: (_, state) => _withBackFallback(
        state,
        RecipeResultsScreen(query: state.uri.queryParameters['q'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/recipes/:id',
      builder: (_, state) => _withBackFallback(
        state,
        RecipeDetailScreen(recipeId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/recipes/:id/prepare',
      builder: (_, state) => _withBackFallback(
        state,
        CookingPreparationScreen(recipeId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/recipes/:id/cook',
      builder: (_, state) => _withBackFallback(
        state,
        RecipeCookingFlowScreen(recipeId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/cooking',
      builder: (_, state) =>
          _withBackFallback(state, const RecipeCookingFlowScreen()),
    ),
    GoRoute(
      path: '/cooking/complete',
      builder: (_, state) =>
          _withBackFallback(state, const CookingCompleteScreen()),
    ),
    GoRoute(path: '/ai', redirect: (_, _) => '/ai-scan'),
    GoRoute(
      path: '/ai-scan',
      builder: (_, state) =>
          _withBackFallback(state, const AiIngredientScanScreen()),
    ),
    GoRoute(
      path: '/ai-recommendations',
      builder: (_, state) =>
          _withBackFallback(state, const AiRecipeRecommendationScreen()),
    ),
    GoRoute(
      path: '/community',
      builder: (_, state) => CommunityScreen(
        initialTab: state.uri.queryParameters['tab'],
        initialRecipeId: state.uri.queryParameters['recipeId'],
        initialRecipeTitle: state.uri.queryParameters['recipeTitle'],
        initialRecipeImage: state.uri.queryParameters['recipeImage'],
        initialReviewRating:
            int.tryParse(state.uri.queryParameters['rating'] ?? '') ?? 5,
        initialWriteReview: state.uri.queryParameters['write'] == '1',
        initialPostId: int.tryParse(state.uri.queryParameters['postId'] ?? ''),
      ),
    ),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(
      path: '/settings/app',
      builder: (_, state) =>
          _withBackFallback(state, const AppSettingsScreen()),
    ),
    GoRoute(
      path: '/my/recipes',
      builder: (_, state) =>
          _withBackFallback(state, const MyRecipesScreen()),
    ),
    GoRoute(
      path: '/my/recipes/new',
      builder: (_, state) => _withBackFallback(
        state,
        const RecipeUploadScreen(returnToMyRecipes: true),
      ),
    ),
    GoRoute(
      path: '/my/recipes/:id/edit',
      builder: (context, state) {
        final extra = state.extra;
        final recipe = extra is Recipe
            ? extra
            : context
                .read<RecipeProvider>()
                .recipeById(state.pathParameters['id'] ?? '');
        if (recipe == null) {
          return _withBackFallback(state, const MyRecipesScreen());
        }
        return _withBackFallback(
          state,
          RecipeUploadScreen(
            returnToMyRecipes: true,
            initialRecipe: recipe,
          ),
        );
      },
    ),
    GoRoute(
      path: '/my/saved-recipes',
      builder: (_, state) =>
          _withBackFallback(state, const SavedRecipesScreen()),
    ),
    GoRoute(
      path: '/my/reviews',
      builder: (_, state) =>
          _withBackFallback(state, const MyReviewsScreen()),
    ),
    GoRoute(
      path: '/my/comments',
      builder: (_, state) =>
          _withBackFallback(state, const MyCommentsScreen()),
    ),
    GoRoute(
      path: '/my/cooking-history',
      builder: (_, state) =>
          _withBackFallback(state, const CookingHistoryScreen()),
    ),
    GoRoute(
      path: '/my/tutorial',
      builder: (_, state) =>
          _withBackFallback(state, const TutorialScreen()),
    ),
  ],
);
