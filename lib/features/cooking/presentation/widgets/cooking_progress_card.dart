import 'package:flutter/material.dart';

class CookingProgressCard extends StatelessWidget {
  const CookingProgressCard({
    required this.current,
    required this.total,
    required this.recipeTitle,
    super.key,
  });

  final int current;
  final int total;
  final String recipeTitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                recipeTitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              'STEP $current / $total',
              style: const TextStyle(
                color: Color(0xFF3378C0),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: current / total, minHeight: 7),
      ],
    ),
  );
}
