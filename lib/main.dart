import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/language/language_provider.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/remote_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/network/dio_client.dart';
import 'core/storage/secure_token_storage.dart';
import 'features/ai_recommend/data/ai_recommend_repository.dart';
import 'features/ai_recommend/provider/ai_recommend_provider.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/provider/auth_provider.dart';
import 'features/community/data/community_repository.dart';
import 'features/community/provider/community_provider.dart';
import 'features/cooking/provider/cooking_session_provider.dart';
import 'features/device/data/ble/sdk_cooker_service.dart';
import 'features/device/data/device_repository.dart';
import 'features/device/provider/device_provider.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/profile/provider/profile_provider.dart';
import 'features/recipe/data/api_recipe_repository.dart';
import 'features/recipe/provider/recipe_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = SecureTokenStorage();
  final notificationService = LocalNotificationService(tokenStorage);
  await notificationService.initialize(
    onRouteRequested: (route) {
      if (route.trim().isNotEmpty) appRouter.go(route);
    },
  );
  final dioClient = DioClient(tokenStorage);
  final remoteNotificationService = RemoteNotificationService(
    dio: dioClient.apiDio,
    localNotifications: notificationService,
  );
  final authRepository = AuthRepository(
    AuthApi(dioClient.authDio),
    LocalAuthApi(dioClient.apiDio),
    tokenStorage,
  );
  final bleService = SdkCookerService();
  final profileRepository = ProfileRepository(dioClient.apiDio);

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: notificationService),
        Provider.value(value: remoteNotificationService),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(authRepository)),
        ChangeNotifierProvider(
          create: (_) =>
              DeviceProvider(DeviceRepository(dioClient.apiDio), bleService),
        ),
        ChangeNotifierProvider(
          create: (_) => RecipeProvider(
            ApiRecipeRepository(dioClient.apiDio),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => CookingSessionProvider(
            bleService,
            profileRepository: profileRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              AiRecommendProvider(AiRecommendRepository(dioClient.apiDio)),
        ),
        ChangeNotifierProvider<CommunityProvider>(
          create: (_) =>
              CommunityProvider(CommunityRepository(dio: dioClient.apiDio)),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileProvider(profileRepository),
        ),
      ],
      child: const GrapheneMultiCookerApp(),
    ),
  );
}
