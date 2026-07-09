import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/widgets/global_cooker_overlay.dart';

class GrapheneMultiCookerApp extends StatelessWidget {
  const GrapheneMultiCookerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final fixedTextChild = MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child ?? const SizedBox.shrink(),
        );
        return ListenableBuilder(
          listenable: appRouter.routeInformationProvider,
          builder: (context, _) => GlobalCookerOverlay(
            currentPath: appRouter.routeInformationProvider.value.uri.path,
            onOpenCooking: (recipeId) => appRouter.go('/recipes/$recipeId/cook'),
            child: fixedTextChild,
          ),
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
          primary: const Color(0xFFF97316),
          secondary: const Color(0xFF0A2540),
          error: const Color(0xFFEF4444),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF111827),
          elevation: 0,
          surfaceTintColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.black.withOpacity(.06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
