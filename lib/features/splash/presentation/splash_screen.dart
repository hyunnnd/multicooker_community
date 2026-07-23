import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/graphene_mark_3d.dart';
import '../../auth/provider/auth_provider.dart';
import '../../profile/provider/profile_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final auth = context.read<AuthProvider>();
    await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 1650)),
      auth.checkAuthStatus(),
      Future<void>.delayed(const Duration(milliseconds: 620)).then((_) {
        if (mounted) setState(() => _showTitle = true);
      }),
    ]);
    if (!mounted) return;
    if (!auth.isAuthenticated) {
      context.go('/login');
      return;
    }

    final profile = context.read<ProfileProvider>();
    final settingsLoaded = auth.localApiReady && await profile.loadSettings();
    if (!mounted) return;
    context.go(
      settingsLoaded && !profile.settings.tutorialCompleted
          ? '/my/tutorial'
          : '/home',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFF5),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GrapheneMark3D(size: 112),
            const SizedBox(height: 18),
            AnimatedSlide(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              offset: _showTitle ? Offset.zero : const Offset(0, 0.18),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _showTitle ? 1 : 0,
                child: const Text(
                  'GRAPHENE COOKER',
                  style: TextStyle(
                    color: Color(0xFF292929),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
