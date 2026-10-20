import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';
import 'training_session.dart';
import 'training_history_service.dart';

class InterimDemoScreen extends StatefulWidget {
  const InterimDemoScreen({super.key});

  @override
  State<InterimDemoScreen> createState() => _InterimDemoScreenState();
}

class _InterimDemoScreenState extends State<InterimDemoScreen> {
  final Random _random = Random();
  final Stopwatch _sw = Stopwatch();

  late List<int> _solution; // the single valid answer (9 cells)
  late List<bool> _isClue; // locked by POSITION
  late List<int?> _board;

  int _activeRow = 0;
  int _mistakes = 0;
  int _correct = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  // ---------------------------------------------------------------------
  // Puzzle generation (unique-solution guaranteed)
  // ---------------------------------------------------------------------
  int _countSolutions(List<int?> start) {
    final g = List<int?>.from(start);
    int count = 0;

    bool fits(int i, int v) {
      final r = i ~/ 3, c = i % 3;
      for (var k = 0; k < 3; k++) {
        if (k != c && g[r * 3 + k] == v) return false;
        if (k != r && g[k * 3 + c] == v) return false;
      }
      return true;
    }

    void solve(int i) {
      if (count > 1) return;
      if (i == 9) {
        count++;
        return;
      }
      if (g[i] != null) {
        solve(i + 1);
        return;
      }
      for (var v = 1; v <= 3; v++) {
        if (fits(i, v)) {
          g[i] = v;
          solve(i + 1);
          g[i] = null;
        }
      }
    }

    solve(0);
    return count;
  }

  // Assigns fields directly (no setState) so it can be used in initState.
  void _newGame() {
    final first = <int>[1, 2, 3]..shuffle(_random);
    final shift = _random.nextBool() ? 1 : 2;
    final sol = <int>[];
    for (var r = 0; r < 3; r++) {
      final s = r == 0 ? 0 : (r == 1 ? shift : 3 - shift);
      for (var c = 0; c < 3; c++) {
        sol.add(first[(c + s) % 3]);
      }
    }

    final order = List<int>.generate(9, (i) => i)..shuffle(_random);
    var k = 3;
    late List<int?> puzzle;
    while (true) {
      puzzle = List<int?>.filled(9, null);
      for (var i = 0; i < k; i++) {
        puzzle[order[i]] = sol[order[i]];
      }
      if (_countSolutions(puzzle) == 1) break; // checked at generation
      k++; // add another clue until the answer is unique
    }

    _solution = sol;
    _board = puzzle;
    _isClue = List<bool>.generate(9, (i) => puzzle[i] != null);
    _activeRow = 0;
    _mistakes = 0;
    _correct = 0;
    _completed = false;
    _sw
      ..reset()
      ..start();
    _advanceDoneRows();
  }

  // ---------------------------------------------------------------------
  // Game logic (runs after each drop, never inside build)
  // ---------------------------------------------------------------------
  bool _rowDone(int r) {
    for (var c = 0; c < 3; c++) {
      if (_board[r * 3 + c] != _solution[r * 3 + c]) return false;
    }
    return true;
  }

  void _advanceDoneRows() {
    while (_activeRow < 2 && _rowDone(_activeRow)) {
      _activeRow++;
    }
  }

  List<int> _pool() {
    final pool = [1, 2, 3];
    for (var c = 0; c < 3; c++) {
      final v = _board[_activeRow * 3 + c];
      if (v != null) pool.remove(v);
    }
    return pool;
  }

  void _onDrop(int target, Map<String, dynamic> data) {
    if (_completed) return;
    if (target ~/ 3 != _activeRow || _isClue[target]) return;

    final fromBoard = data['from'] == 'board';
    if (fromBoard) {
      final o = data['index'] as int;
      if (o == target || _isClue[o] || o ~/ 3 != _activeRow) return;
    }

    final prevRow = _activeRow;
    setState(() {
      if (fromBoard) {
        final o = data['index'] as int;
        final tmp = _board[target];
        _board[target] = _board[o];
        _board[o] = tmp;
      } else {
        _board[target] = data['value'] as int;
      }

      // Mistake counts ONLY if the tile just dropped is wrong.
      if (_board[target] == _solution[target]) {
        _correct++;
      } else {
        _mistakes++;
      }

      _advanceDoneRows();
      if (_activeRow == 2 && _rowDone(2)) {
        _completed = true;
        _sw.stop();
      }
    });

    if (_completed) {
      _onFinished();
    } else if (_activeRow != prevRow) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Row $prevRow done! Moving to Row ${_activeRow + 1}.'.replaceFirst(
                'Row $prevRow', 'Row ${prevRow + 1}')),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  void _removeFromBoard(Map<String, dynamic> data) {
    if (data['from'] != 'board' || _completed) return;
    final o = data['index'] as int;
    if (_isClue[o] || o ~/ 3 != _activeRow) return;
    setState(() => _board[o] = null);
  }

  void _onFinished() {
    final secs = _sw.elapsedMilliseconds / 1000;
    TrainingHistoryService.instance.addSession(TrainingSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      activity: 'Interim Demo',
      date: DateTime.now(),
      difficulty: 'Standard',
      durationSeconds: secs.round(),
      correctAttempts: _correct,
      incorrectAttempts: _mistakes,
      completed: true,
      notes: 'Row-by-row 3x3 board | $_mistakes mistake(s)',
    ));

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Demo Completed!'),
        content: Text(
            'You completed the board in ${fmtSeconds(secs)} with $_mistakes mistake(s).'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(_newGame);
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
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_completed
            ? 'Demo Finished!'
            : 'Interim Demo: Row ${_activeRow + 1} of 3'),
      ),
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
                    width: 300,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _banner(),
                        const SizedBox(height: 16),
                        _inventory(),
                        const SizedBox(height: 16),
                        _buttons(),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _banner(),
                const SizedBox(height: 8),
                Expanded(child: _boardArea()),
                const SizedBox(height: 8),
                _inventory(),
                const SizedBox(height: 8),
                _buttons(),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _banner() {
    return Container(
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
            _completed
                ? 'All rows completed!'
                : 'Active row: ${_activeRow + 1}   •   Mistakes: $_mistakes',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: kTeal),
          ),
          const SizedBox(height: 4),
          const Text(
            'Fill each row so no number repeats in any row or column. '
            'Green = correct, red = wrong.',
            style: TextStyle(fontSize: 13, color: kInk),
          ),
        ],
      ),
    );
  }

  Widget _boardArea() {
    return LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      return Center(
        child: Container(
          width: side,
          height: side,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kTeal.withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            children: List.generate(
              3,
              (r) => Expanded(
                child: Row(
                  children: List.generate(
                    3,
                    (col) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: _cell(r * 3 + col, side / 3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _cell(int idx, double size) {
    final row = idx ~/ 3;
    final value = _board[idx];
    final clue = _isClue[idx];
    final active = row == _activeRow && !_completed;
    final done = row < _activeRow || _completed;
    final canEdit = active && !clue;
    final fontSize = size * 0.42;

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (_) => canEdit,
      onAcceptWithDetails: (d) => _onDrop(idx, d.data),
      builder: (context, candidate, rejected) {
        Color bg;
        Color border;
        Color text;
        double bw = 1.5;

        if (clue) {
          bg = const Color(0xFFE1F2F3);
          border = kTeal;
          text = kTeal;
        } else if (done) {
          bg = Colors.green.shade50;
          border = Colors.green.shade300;
          text = Colors.green.shade700;
        } else if (!active) {
          bg = const Color(0xFFF8FAFC);
          border = Colors.grey.shade300;
          text = Colors.grey;
        } else if (value == null) {
          bg = candidate.isNotEmpty
              ? kTeal.withValues(alpha: 0.2)
              : Colors.white;
          border = kTeal;
          bw = 3;
          text = kTeal;
        } else if (value == _solution[idx]) {
          bg = Colors.green.shade50;
          border = Colors.green;
          bw = 3;
          text = Colors.green.shade700;
        } else {
          bg = Colors.red.shade50;
          border = Colors.red;
          bw = 3;
          text = Colors.red;
        }

        final box = Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: bw),
          ),
          alignment: Alignment.center,
          child: value != null
              ? Text('$value',
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: text))
              : (active
                  ? Text('Drop',
                      style: TextStyle(
                          color: Colors.grey, fontSize: fontSize * 0.4))
                  : null),
        );

        if (canEdit && value != null) {
          return Draggable<Map<String, dynamic>>(
            data: {'from': 'board', 'index': idx, 'value': value},
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: size * 0.6,
                height: size * 0.6,
                decoration: BoxDecoration(
                    color: kTeal, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text('$value',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
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

  Widget _inventory() {
    final pool = _pool();
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (d) => d.data['from'] == 'board',
      onAcceptWithDetails: (d) => _removeFromBoard(d.data),
      builder: (context, candidate, rejected) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: candidate.isNotEmpty
                ? Colors.red.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: candidate.isNotEmpty ? Colors.red : Colors.grey.shade300,
                width: 2),
          ),
          alignment: Alignment.center,
          child: _completed
              ? const Text('All rows solved!',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16))
              : pool.isEmpty
                  ? const Text(
                      'Row full. Swap the red tiles (or drag one here) to fix it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.black54, fontWeight: FontWeight.w600))
                  : Wrap(
                      spacing: 14,
                      children: pool.map((n) {
                        return Draggable<Map<String, dynamic>>(
                          data: {'from': 'pool', 'value': n},
                          feedback: Material(
                            color: Colors.transparent,
                            child: _poolTile(n, 72, filled: true),
                          ),
                          childWhenDragging:
                              Opacity(opacity: 0.3, child: _poolTile(n, 64)),
                          child: _poolTile(n, 64),
                        );
                      }).toList(),
                    ),
        );
      },
    );
  }

  Widget _poolTile(int n, double size, {bool filled = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? kTeal : const Color(0xFFE1F2F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kTeal, width: 2),
      ),
      alignment: Alignment.center,
      child: Text('$n',
          style: TextStyle(
              color: filled ? Colors.white : kTeal,
              fontSize: size * 0.45,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buttons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () => setState(_newGame),
          icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
          label: const Text('New Puzzle',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    );
  }
}