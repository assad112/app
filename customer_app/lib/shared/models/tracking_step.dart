class TrackingStep {
  const TrackingStep({
    required this.titleKey,
    required this.isComplete,
    required this.isCurrent,
  });

  final String titleKey;
  final bool isComplete;
  final bool isCurrent;
}
