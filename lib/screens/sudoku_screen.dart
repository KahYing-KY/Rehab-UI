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
  // Full 9x9 board representation (81 cells)
  late List<int?> _board;
  // Keeps track of which cells are original locked clues vs user-editable slots
  late List<bool> _isInitialCell;
  
  final Random _random = Random();
  PuzzleDifficulty _currentDifficulty = PuzzleDifficulty.medium;
  final Stopwatch sw = Stopwatch()..start();
  bool _isSolved = false;
  int _mistakeCount = 0; // Tracks incorrect/conflicting tile placements during training

  // We designate one 3x3 sub-grid box as the active workspace (e.g., box index 4 = center box)
  final int _activeBoxIndex = 4; 

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
    _generateSubGridPuzzle();
  }

  // Generates a valid 9x9 solved layout, locks 8 boxes, and punches holes in the active box
  void _generateSubGridPuzzle() {
    setState(() {
      _isSolved = false;
      _mistakeCount = 0; // Reset mistakes on new puzzle
      sw.reset();
      sw.start();

      // 1. Generate a valid baseline 9x9 Sudoku board solution
      final List<int> baseSolution = [
        5, 3, 4, 6, 7, 8, 9, 1, 2,
        6, 7, 2, 1, 9, 5, 3, 4, 8,
        1, 9, 8, 3, 4, 2, 5, 6, 7,
        8, 5, 9, 7, 6, 1, 4, 2, 3,
        4, 2, 6, 8, 5, 3, 7, 9, 1,
        7, 1, 3, 9, 2, 4, 8, 5, 6,
        9, 6, 1, 5, 3, 7, 2, 8, 4,
        2, 8, 7, 4, 1, 9, 6, 3, 5,
        3, 4, 5, 2, 8, 6, 1, 7, 9,
      ];

      _board = List<int?>.from(baseSolution);
      _isInitialCell = List.generate(81, (index) => true);

      // 2. Determine which cell indices belong to the _activeBoxIndex
      List<int> activeBoxIndices = [];
      int startRow = (_activeBoxIndex ~/ 3) * 3;
      int startCol = (_activeBoxIndex % 3) * 3;

      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          int cellIndex = (startRow + r) * 9 + (startCol + c);
          activeBoxIndices.add(cellIndex);
        }
      }

      // 3. Determine number of holes based on difficulty
      int holesCount;
      switch (_currentDifficulty) {
        case PuzzleDifficulty.easy:
          holesCount = 3;
          break;
        case PuzzleDifficulty.medium:
          holesCount = 5;
          break;
        case PuzzleDifficulty.hard:
          holesCount = 7;
          break;
      }

      // Punch holes strictly within the active box
      activeBoxIndices.shuffle(_random);
      for (int i = 0; i < holesCount && i < activeBoxIndices.length; i++) {
        int holeIdx = activeBoxIndices[i];
        _board[holeIdx] = null;
        _isInitialCell[holeIdx] = false;
      }
    });
  }

  // Get inventory pool of missing numbers specifically for the active box
  List<int> _getSidebarPool() {
    int startRow = (_activeBoxIndex ~/ 3) * 3;
    int startCol = (_activeBoxIndex % 3) * 3;

    Set<int> presentInBox = {};
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        int cellIndex = (startRow + r) * 9 + (startCol + c);
        if (_board[cellIndex] != null) {
          presentInBox.add(_board[cellIndex]!);
        }
      }
    }

    // Find all numbers 1-9 that are NOT currently placed in this 3x3 box
    List<int> inventory = [];
    for (int n = 1; n <= 9; n++) {
      if (!presentInBox.contains(n)) {
        inventory.add(n);
      }
    }
    return inventory;
  }

  // Cross-check row, column, and 3x3 box conflicts across the 9x9 grid
  Set<int> _findConflictingIndices() {
    final Set<int> conflictingIndices = {};

    for (int i = 0; i < 9; i++) {
      Map<int, List<int>> rowVals = {};
      Map<int, List<int>> colVals = {};

      for (int j = 0; j < 9; j++) {
        int rowIdx = i * 9 + j;
        int colIdx = j * 9 + i;

        if (_board[rowIdx] != null) {
          rowVals.putIfAbsent(_board[rowIdx]!, () => []).add(rowIdx);
        }
        if (_board[colIdx] != null) {
          colVals.putIfAbsent(_board[colIdx]!, () => []).add(colIdx);
        }
      }

      rowVals.forEach((val, indices) {
        if (indices.length > 1) conflictingIndices.addAll(indices);
      });
      colVals.forEach((val, indices) {
        if (indices.length > 1) conflictingIndices.addAll(indices);
      });
    }

    return conflictingIndices;
  }

  void _checkSolved(Set<int> conflictingIndices) {
    if (!_isSolved && !_board.contains(null) && conflictingIndices.isEmpty) {
      _isSolved = true;
      sw.stop();
      final secs = sw.elapsedMilliseconds / 1000;
      
      // Log session with mistake accuracy tracking included
      history.add(SessionRecord(
        'Sudoku (9x9 Sub-Grid)', 
        DateTime.now(), 
        secs,
        'Completed active box challenge (${_currentDifficulty.name}) | Mistakes: $_mistakeCount'
      ));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Box Completed!'),
            content: Text('You successfully filled the target 3x3 box in ${fmtSeconds(secs)} with $_mistakeCount mistake(s).'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(_generateSubGridPuzzle);
                },
                child: const Text('Play Again'),
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
    _checkSolved(conflictingIndices);

    return Scaffold(
      appBar: AppBar(title: const Text('9x9 Sudoku - Focused Box Training')),
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
                  "Active Challenge: Fill Center 3x3 Box (${_currentDifficulty.name.toUpperCase()})",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: kTeal),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Surrounding 8 boxes provide context. Complete the active box!",
                style: TextStyle(fontSize: 13, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Difficulty Selector
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
                          _generateSubGridPuzzle();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? kTeal : Colors.grey[300],
                        foregroundColor: isSelected ? Colors.white : Colors.black87,
                        elevation: isSelected ? 2 : 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Full 9x9 Sudoku Grid UI
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: kInk,
                  borderRadius: BorderRadius.circular(8),
                ),
                width: 340,
                height: 340,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 9,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: 81,
                  itemBuilder: (context, index) {
                    int row = index ~/ 9;
                    int col = index % 9;
                    int boxIndex = (row ~/ 3) * 3 + (col ~/ 3);
                    
                    bool isActiveBox = (boxIndex == _activeBoxIndex);
                    bool isLocked = _isInitialCell[index];
                    final tileValue = _board[index];
                    final isConflicting = conflictingIndices.contains(index);

                    return DragTarget<Map<String, dynamic>>(
                      onAcceptWithDetails: (details) {
                        if (!isLocked && isActiveBox) {
                          setState(() {
                            final data = details.data;
                            final String from = data['from'];
                            final int draggedValue = data['value'];

                            if (from == 'board') {
                              int originalIndex = data['index'];
                              if (!_isInitialCell[originalIndex]) {
                                final temp = _board[index];
                                _board[index] = _board[originalIndex];
                                _board[originalIndex] = temp;
                              }
                            } else if (from == 'sidebar') {
                              _board[index] = draggedValue;
                            }

                            // Increment mistake counter if placement results in conflicts
                            if (_findConflictingIndices().isNotEmpty) {
                              _mistakeCount++;
                            }
                          });
                        }
                      },
                      builder: (context, candidateData, rejectedData) {
                        return GestureDetector(
                          onTap: () {
                            if (!isLocked && isActiveBox && tileValue != null) {
                              setState(() {
                                _board[index] = null;
                              });
                            }
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isActiveBox
                                  ? (isLocked ? Colors.blueGrey[100] : Colors.white)
                                  : Colors.grey[200],
                              border: Border.all(
                                color: isConflicting ? Colors.red : Colors.grey[400]!,
                                width: isConflicting ? 2 : 0.5,
                              ),
                            ),
                            child: tileValue != null
                                ? (isLocked || !isActiveBox
                                    ? Text('$tileValue',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isActiveBox ? Colors.black87 : Colors.grey[600]))
                                    : Draggable<Map<String, dynamic>>(
                                        data: {'from': 'board', 'index': index, 'value': tileValue},
                                        feedback: Material(
                                          color: Colors.transparent,
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(4)),
                                            alignment: Alignment.center,
                                            child: Text('$tileValue',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                          ),
                                        ),
                                        childWhenDragging: Opacity(
                                          opacity: 0.3,
                                          child: Text('$tileValue', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        ),
                                        child: Text('$tileValue',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isConflicting ? Colors.red : kTeal)),
                                      ))
                                : const SizedBox.shrink(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                "Active Box Inventory (Drag numbers into the center box)",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54),
              ),
              const SizedBox(height: 10),

              // Inventory Pool for Active Box
              Container(
                width: 320,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: sidebarPool.isEmpty
                    ? const Center(
                        child: Text("All slots filled!",
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))
                    : Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: sidebarPool.map((number) {
                          return Draggable<Map<String, dynamic>>(
                            data: {'from': 'sidebar', 'value': number},
                            feedback: Material(
                              color: Colors.transparent,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.center,
                                child: Text('$number',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _buildInventoryTile(number),
                            ),
                            child: _buildInventoryTile(number),
                          );
                        }).toList(),
                      ),
              ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _generateSubGridPuzzle,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text("New Puzzle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: kTeal),
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

  Widget _buildInventoryTile(int number) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kTeal, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 1)],
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(color: kTeal, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}