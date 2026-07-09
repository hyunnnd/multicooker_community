import 'package:flutter/material.dart';

import '../../../recipe/data/models/cooker_step.dart';

class CookerStatusPanel extends StatelessWidget {
  const CookerStatusPanel({
    required this.step,
    required this.remainingSeconds,
    super.key,
  });

  final CookerStep? step;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    if (step == null) return const SizedBox.shrink();
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF292929),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '쿠커 상태 · ${step!.label}',
            style: const TextStyle(
              color: Color(0xFFFFF9ED),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.thermostat, color: Color(0xFFFE7902)),
              Text('${step!.temperature}℃', style: _valueStyle),
              const Spacer(),
              const Icon(Icons.timer_outlined, color: Color(0xFFFE7902)),
              Text(
                '$minutes:${seconds.toString().padLeft(2, '0')}',
                style: _valueStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _valueStyle = TextStyle(
  color: Colors.white,
  fontSize: 24,
  fontWeight: FontWeight.w900,
);
