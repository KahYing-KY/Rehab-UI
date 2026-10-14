import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';

enum PuzzleDifficulty { easy, medium, hard }

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  late List<int?> _board;
  final Random _random = Random();
  PuzzleDifficulty _currentDifficulty = PuzzleDifficulty.medium;
  final Stopwatch sw = Stopwatch()..start();
  bool _isSolved = false;

  @override
  void initState() {
    super.initState();
    trainingStarted = true;

    if (currentDifficulty != null) {
      switch (currentDifficulty!) {
        case Difficulty.easy:
          _currentDifficulty = PuzzleDifficulty.easy;
          break;
        case Difficulty.medium:
          _currentDifficulty = PuzzleDifficulty.medium;
          break;
        case Difficulty.hard:
          _currentDifficulty = PuzzleDifficulty.hard;
          break;
      }
    }
    _generateRandomPuzzle();
  }

  void _generateRandomPuzzle() {
    setState(() {
      _isSolved = false;
      sw.reset();
      sw.start();

      final List<int> firstRow = List.generate(3, (i) => i + 1)..shuffle(_random);
      final List<int> secondRow = List.generate(3, (i) => firstRow[(i + 1) % 3]);
      final List<int> thirdRow = List.generate(3, (i) => firstRow[(i + 2) % 3]);

      final List<int> completeGrid = List<int>.from(firstRow)
        ..addAll(secondRow)
        ..addAll(thirdRow);

      _board = List<int?>.from(completeGrid);
      
      int holesCount;
      switch (_currentDifficulty) {
        case PuzzleDifficulty.easy:
          holesCount = 2;
          break;
        case PuzzleDifficulty.medium:
          holesCount = 5;
          break;
        case PuzzleDifficulty.hard:
          holesCount = 7;
          break;
      }

      final List<int> indices = List.generate(9, (index) => index)..shuffle(_random);
      for (int i = 0; i < holesCount; i++) {
        _board[indices[i]] = null;
      }
    });
  }

  List<int> _getSidebarPool() {
    final List<int> requiredPool = List.generate(9, (index) => (index ~/ 3) + 1);
    for (var num in _board) {
      if (num != null) {
        requiredPool.remove(num);
      }
    }
    return requiredPool;
  }

  Set<int> _findConflictingIndices() {
    final Set<int> conflictingIndices = {};

    for (int row = 0; row < 3; row++) {
      final Map<int, List<int>> rowValues = {};
      for (int col = 0; col < 3; col++) {
        int index = row * 3 + col;
        int? val = _board[index];
        if (val != null) {
          rowValues.putIfAbsent(val, () => []).add(index);
        }
      }
      rowValues.forEach((val, indices) {
        if (indices.length > 1) conflictingIndices.addAll(indices);
      });
    }

    for (int col = 0; col < 3; col++) {
      final Map<int, List<int>> colValues = {};
      for (int row = 0; row < 3; row++) {
        int index = row * 3 + col;
        int? val = _board[index];
        if (val != null) {
          colValues.putIfAbsent(val, () => []).add(index);
        }
      }
      colValues.forEach((val, indices) {
        if (indices.length > 1) conflictingIndices.addAll(indices);
      });
    }

    return conflictingIndices;
  }

  void _checkSolved(Set<int> conflictingIndices, List<int> sidebarPool) {
    if (!_isSolved && sidebarPool.isEmpty && !_board.contains(null) && conflictingIndices.isEmpty) {
      _isSolved = true;
      sw.stop();
      final secs = sw.elapsedMilliseconds / 1000;
      history.add(SessionRecord('Sudoku', DateTime.now(), secs,
          'Puzzle solved (${currentDifficulty?.label ?? _currentDifficulty.name} level)'));
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Well done!'),
            content: Text('You solved the puzzle in ${fmtSeconds(secs)}.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(_generateRandomPuzzle);
                },
                child: const Text('Play again'),
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

  @override
  Widget build(BuildContext context) {
    final conflictingIndices = _findConflictingIndices();
    final sidebarPool = _getSidebarPool();
    _checkSolved(conflictingIndices, sidebarPool);

    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku Training')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDFF1F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "Today's level: ${currentDifficulty?.label ?? _currentDifficulty.name.toUpperCase()}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: kTeal),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "3x3 Sudoku Mini Puzzle",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kInk),
              ),
              const SizedBox(height: 4),
              const Text(
                "Each row and column must contain digits 1, 2, and 3",
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: PuzzleDifficulty.values.map((difficulty) {
                  final bool isSelected = _currentDifficulty == difficulty;
                  final String label = difficulty.name[0].toUpperCase() + difficulty.name.substring(1);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _currentDifficulty = difficulty;
                          _generateRandomPuzzle();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? kTeal : Colors.grey[300],
                        foregroundColor: isSelected ? Colors.white : Colors.black87,
                        elevation: isSelected ? 2 : 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.blueGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey, width: 3),
                ),
                width: 280,
                height: 280,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _board.length,
                  itemBuilder: (context, index) {
                    final isConflicting = conflictingIndices.contains(index);
                    final tileValue = _board[index];

                    return DragTarget<Map<String, dynamic>>(
                      onAcceptWithDetails: (details) {
                        setState(() {
                          final data = details.data;
                          final String from = data['from'];
                          final int draggedValue = data['value'];

                          if (from == 'board') {
                            final int originalIndex = data['index'];
                            final temp = _board[index];
                            _board[index] = _board[originalIndex];
                            _board[originalIndex] = temp;
                          } else if (from == 'sidebar') {
                            _board[index] = draggedValue;
                          }
                        });
                      },
                      builder: (context, candidateData, rejectedData) {
                        if (tileValue == null) {
                          return _buildTile(null);
                        }

                        return Draggable<Map<String, dynamic>>(
                          data: {'from': 'board', 'index': index, 'value': tileValue},
                          dragAnchorStrategy: pointerDragAnchorStrategy,
                          feedback: Material(
                            color: Colors.transparent,
                            child: _buildTile(tileValue, isDragging: true, hasConflict: isConflicting),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.2,
                            child: _buildTile(tileValue, hasConflict: isConflicting),
                          ),
                          child: _buildTile(tileValue, hasConflict: isConflicting),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Available Inventory (Drag to Grid)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              DragTarget<Map<String, dynamic>>(
                onAcceptWithDetails: (details) {
                  setState(() {
                    final data = details.data;
                    if (data['from'] == 'board') {
                      final int originalIndex = data['index'];
                      _board[originalIndex] = null;
                    }
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 320,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: candidateData.isNotEmpty ? Colors.red.withValues(alpha: 0.1) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: candidateData.isNotEmpty ? Colors.red : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: sidebarPool.isEmpty && !_board.contains(null) && conflictingIndices.isEmpty
                        ? const Center(
                            child: Text(
                              "Solved!",
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          )
                        : Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: sidebarPool.map((number) {
                              return Draggable<Map<String, dynamic>>(
                                data: {'from': 'sidebar', 'value': number},
                                dragAnchorStrategy: pointerDragAnchorStrategy,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: _buildTile(number, isDragging: true),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _buildTile(number),
                                ),
                                child: _buildTile(number),
                              );
                            }).toList(),
                          ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _generateRandomPuzzle,
                    icon: const Icon(Icons.casino, color: Colors.white),
                    label: const Text("New Puzzle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(int? value, {bool isDragging = false, bool hasConflict = false}) {
    Color tileColor = Colors.white;
    Color textColor = Colors.black87;

    if (hasConflict) {
      tileColor = const Color(0xFFFFEBEE);
      textColor = Colors.red;
    } else if (isDragging) {
      tileColor = kTeal;
      textColor = Colors.white;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: value == null ? Colors.blueGrey.withValues(alpha: 0.3) : tileColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasConflict ? Colors.red : (value == null ? Colors.transparent : Colors.grey[300]!),
          width: hasConflict ? 2 : 1,
        ),
        boxShadow: isDragging
            ? [const BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 1)]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        value != null ? '$value' : '',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
    );
  }
}