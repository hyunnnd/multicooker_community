import 'package:flutter/material.dart';

class UserActionRequiredModal extends StatelessWidget {
  const UserActionRequiredModal({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onComplete,
    required this.onAddMinute,
    required this.onStop,
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onComplete;
  final VoidCallback onAddMinute;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: ColoredBox(color: Color(0x99000000))),
      Center(
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.notification_important_outlined,
                  size: 38,
                  color: Color(0xFF3378C0),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: onComplete, child: Text(actionLabel)),
                TextButton(
                  onPressed: onAddMinute,
                  child: const Text('1분 더 조리'),
                ),
                TextButton(
                  onPressed: onStop,
                  child: const Text(
                    '조리 중지',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
