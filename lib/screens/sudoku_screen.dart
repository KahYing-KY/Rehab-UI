import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';
import 'training_session.dart';
import 'training_history_service.dart';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  static const List<int> _base = [
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

  final Random _random = Random();
  final Stopwatch _sw = Stopwatch();

  late List<int> _solution;
  late List<int?> _board;
  late List<bool> _locked;

  int _activeBox = 0;
  Difficulty _difficulty = Difficulty.medium;
  int _mistakes = 0;
  int _correct = 0;
  int _hintsUsed = 0;
  bool _solved = false;
  bool _showHint = false;
  int? _hintCell;
  String _hintText = '';

  @override
  void initState() {
    super.initState();
    _difficulty = currentDifficulty ?? Difficulty.medium;
    trainingStarted = true;
    _newPuzzle();
  }

  // ---------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------
  int _boxOf(int idx) => ((idx ~/ 9) ~/ 3) * 3 + ((idx % 9) ~/ 3);

  List<int> _boxCells(int box) {
    final br = (box ~/ 3) * 3, bc = (box % 3) * 3;
    return [
      for (var r = 0; r < 3; r++)
        for (var c = 0; c < 3; c++) (br + r) * 9 + (bc + c)
    ];
  }

  // True when the given holes have exactly ONE valid fill.
  bool _hasUniqueFill(List<int> holes) {
    final g = List<int?>.from(_solution);
    for (final h in holes) {
      g[h] = null;
    }
    int count = 0;

    bool fits(int idx, int v) {
      final r = idx ~/ 9, c = idx % 9;
      for (var k = 0; k < 9; k++) {
        if (g[r * 9 + k] == v) return false;
        if (g[k * 9 + c] == v) return false;
      }
      final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          if (g[(br + i) * 9 + bc + j] == v) return false;
        }
      }
      return true;
    }

    void solve(int pos) {
      if (count > 1) return;
      if (pos == holes.length) {
        count++;
        return;
      }
      final idx = holes[pos];
      for (var v = 1; v <= 9; v++) {
        if (fits(idx, v)) {
          g[idx] = v;
          solve(pos + 1);
          g[idx] = null;
        }
      }
    }

    solve(0);
    return count == 1;
  }

  // Assigns fields directly (callers wrap in setState when needed).
  void _newPuzzle() {
    final map = List<int>.generate(9, (i) => i + 1)..shuffle(_random);
    _solution = _base.map((v) => map[v - 1]).toList();
    _activeBox = _random.nextInt(9); // random 3x3 box every game

    var holes = switch (_difficulty) {
      Difficulty.easy => 3,
      Difficulty.medium => 5,
      Difficulty.hard => 7,
    };

    final boxIdx = _boxCells(_activeBox);
    List<int> chosen = [];
    while (true) {
      var found = false;
      for (var a = 0; a < 40; a++) {
        final cells = List<int>.of(boxIdx)..shuffle(_random);
        chosen = cells.take(holes).toList();
        if (_hasUniqueFill(chosen)) {
          found = true;
          break;
        }
      }
      if (found || holes <= 1) break;
      holes--;
    }

    _board = List<int?>.from(_solution);
    for (final h in chosen) {
      _board[h] = null;
    }
    _locked = List<bool>.generate(81, (i) => _board[i] != null);

    _mistakes = 0;
    _correct = 0;
    _hintsUsed = 0;
    _solved = false;
    _showHint = false;
    _hintCell = null;
    _hintText = '';
    _sw
      ..reset()
      ..start();
  }

  List<int> _pool() {
    final present = <int>{};
    for (final i in _boxCells(_activeBox)) {
      if (_board[i] != null) present.add(_board[i]!);
    }
    return [
      for (var n = 1; n <= 9; n++)
        if (!present.contains(n)) n
    ];
  }

  // ---------------------------------------------------------------------
  // drag & drop (all checks happen here, not in build)
  // ---------------------------------------------------------------------
  void _onDrop(int index, Map<String, dynamic> data) {
    if (_solved || _locked[index] || _boxOf(index) != _activeBox) return;

    final fromBoard = data['from'] == 'board';
    if (fromBoard) {
      final o = data['index'] as int;
      if (o == index || _locked[o] || _boxOf(o) != _activeBox) return;
    }

    setState(() {
      if (fromBoard) {
        final o = data['index'] as int;
        final tmp = _board[index];
        _board[index] = _board[o];
        _board[o] = tmp;
      } else {
        _board[index] = data['value'] as int;
      }
      _showHint = false;
      _hintCell = null;

      // Mistake counts ONLY if the tile just dropped is wrong.
      if (_board[index] == _solution[index]) {
        _correct++;
      } else {
        _mistakes++;
      }
    });
    _checkSolved();
  }

  void _removeFromBoard(Map<String, dynamic> data) {
    if (data['from'] != 'board' || _solved) return;
    final o = data['index'] as int;
    if (_locked[o] || _boxOf(o) != _activeBox) return;
    setState(() {
      _board[o] = null;
      _showHint = false;
      _hintCell = null;
    });
  }

  void _checkSolved() {
    if (_solved) return;
    for (var i = 0; i < 81; i++) {
      if (_board[i] != _solution[i]) return;
    }
    setState(() {
      _solved = true;
      _sw.stop();
    });
    final secs = _sw.elapsedMilliseconds / 1000;

    TrainingHistoryService.instance.addSession(TrainingSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      activity: 'Sudoku Training',
      date: DateTime.now(),
      difficulty: _difficulty.label,
      durationSeconds: secs.round(),
      correctAttempts: _correct,
      incorrectAttempts: _mistakes,
      completed: true,
      notes:
          'Box ${_activeBox ~/ 3 + 1},${_activeBox % 3 + 1} | Hints used: $_hintsUsed',
    ));

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Box Completed!'),
        content: Text(
            'You filled the box in ${fmtSeconds(secs)} with $_mistakes mistake(s) '
            'and $_hintsUsed hint(s).'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(_newPuzzle);
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
  }

  // ---------------------------------------------------------------------
  // hint
  // ---------------------------------------------------------------------
  void _giveHint() {
    if (_solved) return;
    final box = _boxCells(_activeBox);
    final missing = _pool();

    int? bestCell;
    List<int> bestCands = [];
    for (final idx in box) {
      if (_board[idx] != null) continue;
      final r = idx ~/ 9, c = idx % 9;
      final cands = <int>[];
      for (var v = 1; v <= 9; v++) {
        var ok = true;
        for (var k = 0; k < 9 && ok; k++) {
          if (_board[r * 9 + k] == v || _board[k * 9 + c] == v) ok = false;
        }
        for (final b in box) {
          if (_board[b] == v) ok = false;
        }
        if (ok) cands.add(v);
      }
      if (cands.isNotEmpty &&
          (bestCell == null || cands.length < bestCands.length)) {
        bestCell = idx;
        bestCands = cands;
      }
    }

    setState(() {
      _hintsUsed++;
      _showHint = true;
      if (missing.isEmpty) {
        _hintCell = null;
        _hintText =
            'The box is full but some tiles are red. Swap or remove them.';
      } else if (bestCell == null) {
        _hintCell = null;
        _hintText =
            'Missing: ${missing.join(', ')}. A red tile is blocking a cell, so remove it.';
      } else {
        _hintCell = bestCell;
        final r = bestCell ~/ 9 + 1, c = bestCell % 9 + 1;
        _hintText = 'Missing: ${missing.join(', ')}. '
            'Try the highlighted cell (row $r, col $c): it can only be '
            '${bestCands.join(' or ')}.';
      }
    });
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku Training')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 720 && c.maxWidth > c.maxHeight * 1.1;
            if (wide) {
              return Row(
                children: [
                  Expanded(child: _boardArea()),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 320,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(),
                          const SizedBox(height: 10),
                          _controls(),
                          if (_showHint) ...[
                            const SizedBox(height: 10),
                            _hintBanner(),
                          ],
                          const SizedBox(height: 14),
                          _pool().isEmpty && !_solved
                              ? _poolBox()
                              : _poolBox(),
                          const SizedBox(height: 14),
                          _buttons(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 6),
                _controls(),
                if (_showHint) ...[
                  const SizedBox(height: 6),
                  _hintBanner(),
                ],
                const SizedBox(height: 6),
                Expanded(child: _boardArea()),
                const SizedBox(height: 6),
                _poolBox(),
                const SizedBox(height: 6),
                _buttons(),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFDFF1F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Fill the empty box (row ${_activeBox ~/ 3 + 1}, col ${_activeBox % 3 + 1})'
        '   •   Mistakes: $_mistakes',
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: kTeal),
      ),
    );
  }

  Widget _controls() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        ...Difficulty.values.map((d) {
          final selected = _difficulty == d;
          return ChoiceChip(
            label: Text(d.label),
            selected: selected,
            selectedColor: kTeal,
            labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal),
            onSelected: (_) => setState(() {
              _difficulty = d;
              _newPuzzle();
            }),
          );
        }),
        ElevatedButton.icon(
          onPressed: _giveHint,
          icon: Icon(Icons.lightbulb_outline, color: Colors.amber.shade800),
          label: const Text('Hint'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade50,
            foregroundColor: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _hintBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade600),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_hintText, style: const TextStyle(fontSize: 13)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _showHint = false;
              _hintCell = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _boardArea() {
    return LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      return Center(child: SizedBox(width: side, height: side, child: _board9(side)));
    });
  }

  Widget _board9(double side) {
    final cell = ((side - 6) / 3 - 8) / 3;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kInk,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: List.generate(
          3,
          (br) => Expanded(
            child: Row(
              children: List.generate(3, (bc) {
                final box = br * 3 + bc;
                final active = box == _activeBox;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: active
                          ? kTeal.withValues(alpha: 0.12)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: active ? kTeal : Colors.grey.shade400,
                          width: active ? 3 : 1),
                    ),
                    child: Column(
                      children: List.generate(
                        3,
                        (r) => Expanded(
                          child: Row(
                            children: List.generate(3, (c) {
                              final idx = (br * 3 + r) * 9 + (bc * 3 + c);
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(1),
                                  child: _cell(idx, cell, active),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(int idx, double cell, bool boxActive) {
    final value = _board[idx];
    final locked = _locked[idx];
    final isHint = _hintCell == idx;
    final fontSize = max(10.0, cell * 0.55);

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (_) => boxActive && !locked && !_solved,
      onAcceptWithDetails: (d) => _onDrop(idx, d.data),
      builder: (context, candidate, rejected) {
        Color bg;
        Color border;
        Color text;
        double bw = 1;

        if (!boxActive) {
          bg = Colors.grey.shade200;
          border = Colors.grey.shade300;
          text = Colors.grey.shade700;
        } else if (locked) {
          bg = Colors.blueGrey.shade100;
          border = Colors.blueGrey.shade300;
          text = Colors.black87;
        } else if (value == null) {
          bg = candidate.isNotEmpty
              ? kTeal.withValues(alpha: 0.3)
              : Colors.white;
          border = kTeal;
          bw = 1.5;
          text = kTeal;
        } else if (value == _solution[idx]) {
          bg = Colors.green.shade50;
          border = Colors.green;
          bw = 2;
          text = Colors.green.shade700;
        } else {
          bg = Colors.red.shade50;
          border = Colors.red;
          bw = 2;
          text = Colors.red;
        }
        if (isHint) {
          border = Colors.amber.shade700;
          bw = 3;
          bg = Colors.amber.shade50;
        }

        final box = Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border, width: bw),
          ),
          alignment: Alignment.center,
          child: value == null
              ? null
              : Text('$value',
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: text)),
        );

        if (boxActive && !locked && value != null && !_solved) {
          return Draggable<Map<String, dynamic>>(
            data: {'from': 'board', 'index': idx, 'value': value},
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: cell * 1.4,
                height: cell * 1.4,
                decoration: BoxDecoration(
                    color: kTeal, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text('$value',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize * 1.3,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: box),
            child: box,
          );
        }
        return box;
      },
    );
  }

  Widget _poolBox() {
    final pool = _pool();
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (d) => d.data['from'] == 'board',
      onAcceptWithDetails: (d) => _removeFromBoard(d.data),
      builder: (context, candidate, rejected) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: candidate.isNotEmpty
                ? Colors.red.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: candidate.isNotEmpty ? Colors.red : Colors.grey.shade300,
                width: 2),
          ),
          alignment: Alignment.center,
          child: _solved
              ? const Text('Solved!',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 18))
              : pool.isEmpty
                  ? const Text(
                      'Box full. Swap or drag red tiles here to fix them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.black54, fontWeight: FontWeight.w600))
                  : Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: pool.map((n) {
                        return Draggable<Map<String, dynamic>>(
                          data: {'from': 'pool', 'value': n},
                          feedback: Material(
                            color: Colors.transparent,
                            child: _poolTile(n, filled: true, size: 58),
                          ),
                          childWhenDragging:
                              Opacity(opacity: 0.3, child: _poolTile(n)),
                          child: _poolTile(n),
                        );
                      }).toList(),
                    ),
        );
      },
    );
  }

  Widget _poolTile(int n, {bool filled = false, double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? kTeal : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kTeal, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      alignment: Alignment.center,
      child: Text('$n',
          style: TextStyle(
              color: filled ? Colors.white : kTeal,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.45)),
    );
  }

  Widget _buttons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () => setState(_newPuzzle),
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('New Puzzle',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: kTeal),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to Home'),
        ),
      ],
    );
  }
}