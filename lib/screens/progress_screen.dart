import 'package:flutter/material.dart';
import '../main.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // 1. Separate Interim Demo runs from Main Rehab workflow
    final demoItems = history.where((r) => r.type.contains('Interim Demo')).toList().reversed.toList();
    final rehabItems = history.where((r) => !r.type.contains('Interim Demo')).toList();

    // 2. Group rehab items STARTING from each 'Warm-Up'
    List<List<SessionRecord>> groupedRehabSessions = [];
    List<SessionRecord> currentGroup = [];

    for (var record in rehabItems) {
      if (record.type == 'Warm-Up') {
        // When a new Warm-Up starts, save the previous session if it exists
        if (currentGroup.isNotEmpty) {
          groupedRehabSessions.add(List.from(currentGroup));
          currentGroup.clear();
        }
      }
      currentGroup.add(record);
    }
    
    // Add the active/latest session
    if (currentGroup.isNotEmpty) {
      groupedRehabSessions.add(List.from(currentGroup));
    }

    // Reverse sessions so newest session appears at the top (Rehab Session N, N-1... 1)
    final sessionsToDisplay = groupedRehabSessions.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My Progress & Sessions')),
      body: history.isEmpty
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
                        'Complete an Interim Demo or a full rehab session to see your progress here.',
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. INTERIM DEMO SECTION
                const Text(
                  'Interim Demo Sessions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTeal),
                ),
                const SizedBox(height: 10),
                demoItems.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text('No interim demo runs recorded yet.', style: TextStyle(color: Colors.grey)),
                      )
                    : Column(
                        children: List.generate(demoItems.length, (i) {
                          int sessionNum = demoItems.length - i;
                          final r = demoItems[i];
                          return Card(
                            color: Colors.white,
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              leading: CircleAvatar(
                                backgroundColor: kTeal.withValues(alpha: 0.15),
                                child: Text('$sessionNum', style: const TextStyle(fontWeight: FontWeight.bold, color: kTeal)),
                              ),
                              title: Text('Demo Run $sessionNum - ${fmtSeconds(r.seconds)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              subtitle: Text('${r.detail}\nPlayed at: ${_date(r.date)}'),
                              isThreeLine: true,
                            ),
                          );
                        }),
                      ),

                const SizedBox(height: 24),

                // 2. MAIN REHAB SESSIONS (Grouped properly by Warm-Up start)
                const Text(
                  'Main Rehab Sessions (Warm-Up to Cool-Down)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kBlue),
                ),
                const SizedBox(height: 10),
                sessionsToDisplay.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text('No complete therapy sessions recorded yet.', style: TextStyle(color: Colors.grey)),
                      )
                    : Column(
                        children: List.generate(sessionsToDisplay.length, (i) {
                          int sessionNum = sessionsToDisplay.length - i;
                          final sessionRecords = sessionsToDisplay[i];
                          
                          SessionRecord? warmUp;
                          SessionRecord? coolDown;
                          for (var rec in sessionRecords) {
                            if (rec.type == 'Warm-Up') warmUp = rec;
                            if (rec.type == 'Cool-Down') coolDown = rec;
                          }

                          String? improvementText;
                          if (warmUp != null && coolDown != null) {
                            double diff = warmUp.seconds - coolDown.seconds;
                            if (diff > 0) {
                              improvementText = 'Improved by ${fmtSeconds(diff)} faster in Cool-Down!';
                            } else {
                              improvementText = 'Cool-Down time: ${fmtSeconds(coolDown.seconds)}';
                            }
                          }

                          return Card(
                            color: Colors.white,
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Rehab Session $sessionNum',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kBlue),
                                      ),
                                      if (sessionRecords.isNotEmpty)
                                        Text(
                                          _date(sessionRecords.first.date),
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  ...sessionRecords.map((r) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: [
                                            Icon(
                                              r.type == 'Sudoku' ? Icons.grid_on : Icons.touch_app,
                                              size: 20,
                                              color: r.type == 'Cool-Down' ? kGreen : (r.type == 'Sudoku' ? kTeal : kBlue),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                '${r.type}: ${fmtSeconds(r.seconds)} - ${r.detail}',
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                  if (improvementText != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.trending_up, color: Colors.green, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              improvementText,
                                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
              ],
            ),
    );
  }
}