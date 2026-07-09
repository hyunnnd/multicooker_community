class CookerStep {
  const CookerStep({
    required this.id,
    required this.stepNo,
    required this.label,
    required this.temperature,
    required this.timeMin,
    this.requiresUserConfirmationBeforeStart = false,
    this.userActionBeforeStart,
    this.userActionAfterFinish,
  });

  final String id;
  final int stepNo;
  final String label;
  final int temperature;
  final int timeMin;
  final bool requiresUserConfirmationBeforeStart;
  final String? userActionBeforeStart;
  final String? userActionAfterFinish;
}
