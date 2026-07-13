import 'package:flutter/material.dart';

import '../../data/models/recipe_instruction_step.dart';

class InstructionStepCard extends StatelessWidget {
  const InstructionStepCard({required this.step, super.key});

  final RecipeInstructionStep step;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFF3378C0),
            foregroundColor: Colors.white,
            child: Text('${step.stepNo}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  step.description,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: step.imageUrl == null
                      ? const Icon(
                          Icons.image_outlined,
                          color: Color(0xFF3378C0),
                          size: 32,
                        )
                      : Image.network(
                          step.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.image_outlined,
                            color: Color(0xFF3378C0),
                          ),
                        ),
                ),
                if (step.requiresUserAction) ...[
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 16,
                        color: Color(0xFFC2410C),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '사용자 확인 필요',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFC2410C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
