import 'package:flutter/material.dart';

import '../../data/models/cooker_step.dart';

class CookerStepCard extends StatelessWidget {
  const CookerStepCard({required this.step, super.key});

  final CookerStep step;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF2FF),
        foregroundColor: const Color(0xFF3378C0),
        child: Text('${step.stepNo}'),
      ),
      title: Text(
        step.label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${step.temperature}℃ · ${step.timeMin}분'),
      trailing: const Icon(Icons.memory, color: Color(0xFF3378C0)),
    ),
  );
}
