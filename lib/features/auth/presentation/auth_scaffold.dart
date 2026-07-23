import 'package:flutter/material.dart';

import '../../../core/widgets/main_navigation.dart';
import '../../../core/widgets/main_route_back_scope.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.showBack = false,
    this.backPath = '/login',
    this.scrollable = true,
    this.showBrandHeader = true,
    this.toast,
  });

  final String title;
  final List<Widget> children;
  final bool showBack;
  final String backPath;
  final bool scrollable;
  final bool showBrandHeader;
  final Widget? toast;

  @override
  Widget build(BuildContext context) {
    final themedScaffold = Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          foregroundColor: Color(0xFF111827),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Color(0xFFF8FAFC),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF97316)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF111827),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        extendBodyBehindAppBar: showBack,
        appBar: showBack
            ? AppBar(
                backgroundColor: const Color(0xFFF8FAFC),
                surfaceTintColor: const Color(0xFFF8FAFC),
                scrolledUnderElevation: 0,
                shadowColor: Colors.transparent,
                leadingWidth: 64,
                leading: AppBackButton(fallbackPath: backPath),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 26),
                    child: Center(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : null,
        body: SafeArea(
          top: !showBack,
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(24, showBack ? 0 : 24, 24, 24),
                    physics: scrollable
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    children: [
                      if (showBrandHeader) ...[
                        SizedBox(height: showBack ? 0 : 28),
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1E6),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFFDE4CC),
                              ),
                            ),
                            child: const Icon(
                              Icons.kitchen_rounded,
                              size: 28,
                              color: Color(0xFFF97316),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else
                        const SizedBox(height: 128),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (toast != null)
                Positioned(left: 24, right: 24, bottom: 24, child: toast!),
            ],
          ),
        ),
      ),
    );

    if (!showBack) return themedScaffold;
    return MainRouteBackScope(
      popCurrentRouteFirst: true,
      fallbackPath: backPath,
      child: themedScaffold,
    );
  }
}
