import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';

class InterimDemoScreen extends StatefulWidget {
  const InterimDemoScreen({super.key});

  @override
  State<InterimDemoScreen> createState() => _InterimDemoScreenState();
}

class _InterimDemoScreenState extends State<InterimDemoScreen> {
  late List<int?> _board;
  late List<int> _solutionGrid;
  int _activeRowIndex = 0; // 0 = Row 1, 1 = Row 2, 2 = Row 3
  int _mistakeCount = 0; // Tracks incorrect/conflicting tile placements
  
  final Random _random = Random();
  final Stopwatch sw = Stopwatch()..start();
  bool _isDemoCompleted = false;

  @override
  void initState() {
    super.initState();
    trainingStarted = true;
    _initNewGame();
  }

  void _initNewGame() {
    setState(() {
      _activeRowIndex = 0;
      _isDemoCompleted = false;
      _mistakeCount = 0; // Reset mistakes on new game
      sw.reset();
      sw.start();

      // 1. Generate a valid 3x3 Latin square solution
      final List<int> firstRow = List.generate(3, (i) => i + 1)..shuffle(_random);
      final List<int> secondRow = List.generate(3, (i) => firstRow[(i + 1) % 3]);
      final List<int> thirdRow = List.generate(3, (i) => firstRow[(i + 2) % 3]);
      _solutionGrid = [...firstRow, ...secondRow, ...thirdRow];

      // 2. Place exactly ONE '1', ONE '2', and ONE '3' as initial clues across the board
      _board = List.filled(9, null);
      List<int> availableIndices = List.generate(9, (i) => i)..shuffle(_random);
      
      Set<int> placedNumbers = {};
      for (int idx in availableIndices) {
        int num = _solutionGrid[idx];
        if (!placedNumbers.contains(num)) {
          _board[idx] = num;
          placedNumbers.add(num);
        }
        if (placedNumbers.length == 3) break;
      }
    });
  }

  // Inventory pool for active row
  List<int> _getInventoryPool() {
    int startIdx = _activeRowIndex * 3;
    List<int> activeRowSlots = [
      _board[startIdx] ?? 0,
      _board[startIdx + 1] ?? 0,
      _board[startIdx + 2] ?? 0,
    ];

    final List<int> pool = [1, 2, 3];
    for (var val in activeRowSlots) {
      if (val != 0) pool.remove(val);
    }
    return pool;
  }

  // Check BOTH row and column conflicts to strictly enforce Latin Square rules
  Set<int> _findConflicts() {
    final Set<int> conflicts = {};

    // 1. Check all rows for duplicates
    for (int r = 0; r < 3; r++) {
      Map<int, List<int>> rowCounts = {};
      for (int c = 0; c < 3; c++) {
        int idx = r * 3 + c;
        int? val = _board[idx];
        if (val != null) {
          rowCounts.putIfAbsent(val, () => []).add(idx);
        }
      }
      rowCounts.forEach((val, indices) {
        if (indices.length > 1) {
          conflicts.addAll(indices);
        }
      });
    }

    // 2. Check all columns for duplicates
    for (int c = 0; c < 3; c++) {
      Map<int, List<int>> colCounts = {};
      for (int r = 0; r < 3; r++) {
        int idx = r * 3 + c;
        int? val = _board[idx];
        if (val != null) {
          colCounts.putIfAbsent(val, () => []).add(idx);
        }
      }
      colCounts.forEach((val, indices) {
        if (indices.length > 1) {
          conflicts.addAll(indices);
        }
      });
    }

    return conflicts;
  }

  void _checkRowCompleted(Set<int> conflicts) {
    int startIdx = _activeRowIndex * 3;
    bool rowComplete = true;
    for (int i = 0; i < 3; i++) {
      if (_board[startIdx + i] == null) rowComplete = false;
    }

    // Only allow advancing if the active row is complete AND there are zero row/column conflicts
    if (rowComplete && conflicts.isEmpty && !_isDemoCompleted) {
      sw.stop();
      final secs = sw.elapsedMilliseconds / 1000;

      if (_activeRowIndex < 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Row ${_activeRowIndex + 1} completed! Moving to Row ${_activeRowIndex + 2}.')),
          );
          setState(() {
            _activeRowIndex++;
            sw.start();
          });
        });
      } else {
        setState(() {
          _isDemoCompleted = true;
        });
        // Log history with total time and tracked mistake count
        history.add(SessionRecord(
          'Interim Demo (Row-by-Row)', 
          DateTime.now(), 
          secs, 
          'Completed all 3 rows | Mistakes: $_mistakeCount'
        ));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Demo Completed!'),
              content: Text('You successfully completed the 3x3 board row-by-row in ${fmtSeconds(secs)} with $_mistakeCount mistake(s).'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _initNewGame();
                  },
                  child: const Text('Restart Demo'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = _findConflicts();
    final inventory = _getInventoryPool();
    if (!_isDemoCompleted) _checkRowCompleted(conflicts);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isDemoCompleted ? 'Demo Finished!' : 'Interim Demo: Row ${_activeRowIndex + 1} of 3',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  // 1. Header Banner Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFF1F1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isDemoCompleted ? 'All Rows Completed!' : 'Active Row Focus: ${_activeRowIndex + 1}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTeal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isDemoCompleted
                              ? 'Great job demonstrating the physical board progression!'
                              : 'Complete rows following Latin Square rules (no duplicate numbers in any row or column).',
                          style: const TextStyle(fontSize: 13, color: kInk),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // 2. 3x3 GRID (Flexible Responsive Fit)
                  Flexible(
                    flex: 6,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Container(
                        width: 340,
                        height: 340,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kTeal.withValues(alpha: 0.3), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: 9,
                          itemBuilder: (context, index) {
                            int row = index ~/ 3;
                            bool isActiveRow = (row == _activeRowIndex && !_isDemoCompleted);
                            final val = _board[index];
                            bool isInitialClue = (val != null && val == _solutionGrid[index] && _isOriginalClue(index));
                            bool hasConflict = conflicts.contains(index);

                            return DragTarget<Map<String, dynamic>>(
                              onAcceptWithDetails: (details) {
                                if (isActiveRow && !isInitialClue) {
                                  setState(() {
                                    final data = details.data;
                                    if (data['from'] == 'board') {
                                      int orig = data['index'];
                                      var temp = _board[index];
                                      _board[index] = _board[orig];
                                      _board[orig] = temp;
                                    } else if (data['from'] == 'inventory') {
                                      _board[index] = data['value'];
                                    }

                                    // Track mistake if the new placement causes a conflict
                                    if (_findConflicts().isNotEmpty) {
                                      _mistakeCount++;
                                    }
                                  });
                                }
                              },
                              builder: (context, candidateData, rejectedData) {
                                Color bgColor;
                                Color borderColor;
                                if (isInitialClue) {
                                  bgColor = const Color(0xFFE1F2F3);
                                  borderColor = kTeal;
                                } else if (isActiveRow) {
                                  if (hasConflict) {
                                    bgColor = Colors.red.shade50;
                                    borderColor = Colors.red;
                                  } else if (val == null) {
                                    bgColor = Colors.white;
                                    borderColor = kTeal;
                                  } else {
                                    bgColor = const Color(0xFFE1F2F3);
                                    borderColor = kTeal;
                                  }
                                } else {
                                  bgColor = const Color(0xFFF8FAFC);
                                  borderColor = Colors.grey.shade300;
                                }

                                return Container(
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: borderColor,
                                      width: isActiveRow ? 3 : 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: val != null
                                      ? (isInitialClue
                                          ? Text('$val', style: const TextStyle(fontSize: 24, color: kTeal, fontWeight: FontWeight.bold))
                                          : (isActiveRow
                                              ? Draggable<Map<String, dynamic>>(
                                                  data: {'from': 'board', 'index': index, 'value': val},
                                                  feedback: Material(
                                                    color: Colors.transparent,
                                                    child: Container(
                                                      width: 70,
                                                      height: 70,
                                                      decoration: BoxDecoration(color: hasConflict ? Colors.red : kTeal, borderRadius: BorderRadius.circular(12)),
                                                      alignment: Alignment.center,
                                                      child: Text('$val', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ),
                                                  childWhenDragging: Opacity(
                                                    opacity: 0.3,
                                                    child: Text('$val', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: hasConflict ? Colors.red : kTeal)),
                                                  ),
                                                  child: Text('$val', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: hasConflict ? Colors.red : kTeal)),
                                                )
                                              : Text('$val', style: const TextStyle(fontSize: 24, color: kTeal, fontWeight: FontWeight.bold))))
                                      : const Text('Drop', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // 3. Active Row Inventory Section
                  Text(
                    'Active Row Inventory Tiles',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kInk),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    alignment: Alignment.center,
                    child: _isDemoCompleted
                        ? const Text("All Rows Solved Successfully!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15))
                        : (inventory.isEmpty
                            ? const Text("Row complete! Advancing...", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15))
                            : Wrap(
                                spacing: 12,
                                children: inventory.map((numberItem) {
                                  return Draggable<Map<String, dynamic>>(
                                    data: {'from': 'inventory', 'value': numberItem},
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(12)),
                                        alignment: Alignment.center,
                                        child: Text('$numberItem', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(opacity: 0.3, child: _buildTile(numberItem)),
                                    child: _buildTile(numberItem),
                                  );
                                }).toList(),
                              )),
                  ),

                  const Spacer(),

                  // 4. Action Buttons Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _initNewGame,
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                        label: const Text('Reset Demo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTeal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text('Back to Home'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isOriginalClue(int index) {
    return _board[index] == _solutionGrid[index];
  }

  Widget _buildTile(int numberVal) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFE1F2F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kTeal, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$numberVal',
        style: const TextStyle(color: kTeal, fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }
}