class TrainingSession {
  final String id;
  final String activity;
  final DateTime date;
  final String difficulty;
  final int durationSeconds;
  final int correctAttempts;
  final int incorrectAttempts;
  final bool completed;

  // Free-text detail (e.g. warm-up level, cool-down comparison, mistakes).
  final String notes;

  const TrainingSession({
    required this.id,
    required this.activity,
    required this.date,
    required this.difficulty,
    required this.durationSeconds,
    this.correctAttempts = 0,
    this.incorrectAttempts = 0,
    required this.completed,
    this.notes = '',
  });

  int get totalAttempts => correctAttempts + incorrectAttempts;

  // Warm-Up and Cool-Down don't count attempts, so they have no accuracy.
  bool get hasAccuracy => totalAttempts > 0;

  double get accuracy {
    if (totalAttempts == 0) return 0;
    return correctAttempts / totalAttempts * 100;
  }
}