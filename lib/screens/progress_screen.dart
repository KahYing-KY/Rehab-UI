import 'package:flutter/material.dart';
import '../main.dart';
import 'training_session.dart';
import 'training_history_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String filter = 'All';

  // activity name -> chip label
  static const Map<String, String> _filters = {
    'All': 'All',
    'Warm-Up': 'Warm-Up',
    'Sudoku Training': 'Sudoku',
    'Cool-Down': 'Cool-Down',
    'Rhythm Game': 'Rhythm',
    'Interim Demo': 'Demo',
    'Reach Quest': 'Reach Quest',
  };

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s.toString().padLeft(2, '0')}s' : '${s}s';
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This removes all saved training sessions.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) TrainingHistoryService.instance.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final history = TrainingHistoryService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
        actions: [
          IconButton(
            tooltip: 'Clear history',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmClear,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: history,
        builder: (context, child) {
          final allSessions = history.sessions;
          final sessions = allSessions
              .where((s) => filter == 'All' || s.activity == filter)
              .toList();

          final scored = sessions.where((s) => s.hasAccuracy).toList();
          final averageAccuracy = scored.isEmpty
              ? null
              : scored.fold<double>(0, (sum, s) => sum + s.accuracy) /
                  scored.length;
          final totalSeconds =
              sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Your Training History',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'Warm-ups, Sudoku, cool-downs, the Rhythm Game and demos.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: _metricCard('Sessions', '${sessions.length}',
                              Icons.history)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _metricCard(
                              'Avg accuracy',
                              averageAccuracy == null
                                  ? '—'
                                  : '${averageAccuracy.toStringAsFixed(1)}%',
                              Icons.track_changes)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _metricCard('Total time',
                              _fmtDuration(totalSeconds), Icons.timer_outlined)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _filters.entries.map((e) {
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: filter == e.key,
                        onSelected: (_) => setState(() => filter = e.key),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Session Records (${sessions.length})',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (sessions.isEmpty)
                    const Card(
                      color: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.bar_chart_rounded,
                                size: 56, color: kTeal),
                            SizedBox(height: 12),
                            Text('No training sessions yet',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 17)),
                            SizedBox(height: 8),
                            Text(
                              'Complete a session and its results will appear here.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...sessions.map(_sessionCard),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: kTeal, size: 26),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String activity) {
    switch (activity) {
      case 'Sudoku Training':
        return Icons.grid_3x3;
      case 'Interim Demo':
        return Icons.view_module;
      case 'Rhythm Game':
        return Icons.music_note_rounded;
      case 'Cool-Down':
      case 'Warm-Up':
      default:
        return Icons.touch_app;
    }
  }

  Color _colorFor(String activity) {
    switch (activity) {
      case 'Sudoku Training':
        return kTeal;
      case 'Cool-Down':
        return kGreen;
      case 'Rhythm Game':
        return Colors.deepPurple;
      case 'Interim Demo':
        return Colors.orange;
      default:
        return kBlue;
    }
  }

  Widget _sessionCard(TrainingSession session) {
    final d = session.date;
    final dateText = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
    final color = _colorFor(session.activity);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(_iconFor(session.activity), color: color),
        title: Text(session.activity,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '$dateText  •  ${_fmtDuration(session.durationSeconds)}'
            '${session.hasAccuracy ? '  •  ${session.accuracy.toStringAsFixed(0)}%' : ''}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _detailRow('Difficulty / level', session.difficulty),
          _detailRow('Duration', '${session.durationSeconds} seconds'),
          if (session.hasAccuracy) ...[
            _detailRow('Correct attempts', '${session.correctAttempts}'),
            _detailRow('Incorrect attempts', '${session.incorrectAttempts}'),
            _detailRow('Accuracy', '${session.accuracy.toStringAsFixed(1)}%'),
          ],
          if (session.notes.isNotEmpty) _detailRow('Notes', session.notes),
          _detailRow(
              'Status', session.completed ? 'Completed' : 'Stopped early'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}