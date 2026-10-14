import 'package:flutter/material.dart';
import '../main.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final items = history.reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('My Progress')),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 80, color: kTeal),
                    const SizedBox(height: 16),
                    const Text('No sessions yet',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                        'Finish a warm-up or a Sudoku puzzle and it will show up here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17)),
                    const SizedBox(height: 20),
                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = items[i];
                final isSudoku = r.type == 'Sudoku';
                return Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: Icon(isSudoku ? Icons.grid_on : Icons.touch_app,
                        size: 36,
                        color: isSudoku
                            ? kTeal
                            : (r.type == 'Cool-Down' ? kGreen : kBlue)),
                    title: Text('${r.type} - ${fmtSeconds(r.seconds)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    subtitle: Text('${r.detail}\n${_date(r.date)}'),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}