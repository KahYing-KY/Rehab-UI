import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import 'training_session.dart';
import 'training_history_service.dart';

enum WarmUpPhase { idle, playing, done }

String cellLabel(int index) => '(${index ~/ 3 + 1},${index % 3 + 1})';

class MoveResult {
  final double reaction; // task shown -> tile lifted
  final double movement; // tile lifted -> first placement
  final double distance; // squares moved (0 when from bank)
  final int mistakes;
  final bool isFirst; // true when the tile came from the bank
  MoveResult(
      this.reaction, this.movement, this.distance, this.mistakes, this.isFirst);
}

class WarmUpScreen extends StatefulWidget {
  final bool coolDown;
  const WarmUpScreen({super.key, this.coolDown = false});

  @override
  State<WarmUpScreen> createState() => _WarmUpScreenState();
}

class _WarmUpScreenState extends State<WarmUpScreen> {
  final Stopwatch _total = Stopwatch();
  final Stopwatch _lap = Stopwatch();
  Timer? _ticker;

  List<WarmUpTask> _tasks = [];
  WarmUpPhase _phase = WarmUpPhase.idle;
  int _taskIndex = 0;

  final Map<int, String> _board = {};
  String? _held;
  bool _isCorrection = false;
  int? _correctionFrom;

  bool _gotReaction = false;
  bool _initialDone = false;
  double _reaction = 0;
  double _pickupAt = 0;
  double _movement = 0;
  int _mistakesThisTask = 0;

  final List<MoveResult> _results = [];
  late String _message =
      'Pick up the tile and whack the mole as quickly as you can!\nPress Start to begin.';

  WarmUpSummary? _summary;
  Difficulty? _level;

  String get _name => widget.coolDown ? 'Cool-Down' : 'Whack-a-Mole Assessment';
  double get _totalSeconds => _total.elapsedMilliseconds / 1000;
  double get _lapSeconds => _lap.elapsedMilliseconds / 1000;
  WarmUpTask get _task => _tasks[_taskIndex];
  int? get _expectedSource => _isCorrection ? _correctionFrom : _task.from;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _instruction() {
    final t = _task;
    return t.from == null
        ? 'Pick up Tile ${t.tileId} from the bank and whack the mole at ${cellLabel(t.to)}.'
        : 'Pick up Tile ${t.tileId} at ${cellLabel(t.from!)} and whack the mole at ${cellLabel(t.to)}.';
  }

  void _resetTaskState() {
    _gotReaction = false;
    _initialDone = false;
    _reaction = 0;
    _pickupAt = 0;
    _movement = 0;
    _mistakesThisTask = 0;
  }

  void _start() {
    setState(() {
      _tasks = widget.coolDown
          ? List<WarmUpTask>.of(sessionTasks ?? generateTasks())
          : generateTasks();
      _taskIndex = 0;
      _board.clear();
      _held = null;
      _isCorrection = false;
      _correctionFrom = null;
      _resetTaskState();
      _results.clear();
      _summary = null;
      _level = null;
      _phase = WarmUpPhase.playing;
      _message = _instruction();
      _total
        ..reset()
        ..start();
      _lap
        ..reset()
        ..start();
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onLift() {
    if (!_isCorrection && !_gotReaction) {
      _reaction = _lapSeconds;
      _gotReaction = true;
    }
    _pickupAt = _lapSeconds;
  }

  // ---- tapping the bank ----
  void _tapBank(String tile) {
    if (_phase != WarmUpPhase.playing || _held != null) return;
    if (_expectedSource != null || tile != _task.tileId) {
      setState(() => _message = 'Follow the instruction: ${_instruction()}');
      return;
    }
    setState(() {
      _onLift();
      _held = tile;
      _message =
          'Tile $tile lifted. Whack the mole at ${cellLabel(_task.to)}!';
    });
  }

  // ---- tapping a board cell ----
  void _tapCell(int i) {
    if (_phase != WarmUpPhase.playing) return;

    // PICK UP from the board
    if (_held == null) {
      final tile = _board[i];
      if (tile == null || i != _expectedSource) {
        setState(() => _message = _isCorrection
            ? 'Pick up Tile ${_task.tileId} at ${cellLabel(_correctionFrom!)}.'
            : 'Follow the instruction: ${_instruction()}');
        return;
      }
      setState(() {
        _onLift();
        _board.remove(i);
        _held = tile;
        _message =
            'Tile $tile lifted. Whack the mole at ${cellLabel(_task.to)}!';
      });
      return;
    }

    // PLACE the tile
    if (_board[i] != null) {
      setState(() => _message =
          'Cell ${cellLabel(i)} is occupied. Choose an empty cell.');
      return;
    }

    setState(() {
      final tile = _held!;
      if (!_initialDone) {
        _movement = _lapSeconds - _pickupAt;
        _initialDone = true;
      }
      _board[i] = tile;
      _held = null;

      if (i == _task.to) {
        _completeTask();
      } else {
        _mistakesThisTask++;
        _isCorrection = true;
        _correctionFrom = i;
        _message =
            'Missed! Move Tile $tile from ${cellLabel(i)} to the mole at ${cellLabel(_task.to)}.';
      }
    });
  }

  // Called inside setState
  void _completeTask() {
    final t = _task;
    _results.add(MoveResult(
      _reaction,
      _movement,
      t.from == null ? 0 : cellDistance(t.from!, t.to),
      _mistakesThisTask,
      t.from == null,
    ));

    _isCorrection = false;
    _correctionFrom = null;
    _resetTaskState();
    _taskIndex++;

    if (_taskIndex >= _tasks.length) {
      _finish();
    } else {
      _lap
        ..reset()
        ..start();
      _message = 'Great hit! ${_instruction()}';
    }
  }

  double _avg(Iterable<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  // Called inside setState
  void _finish() {
    _total.stop();
    _lap.stop();
    _ticker?.cancel();
    _phase = WarmUpPhase.done;

    final boardMoves = _results.where((r) => !r.isFirst).toList();
    final sumMove = boardMoves.fold<double>(0, (a, r) => a + r.movement);
    final sumDist = boardMoves.fold<double>(0, (a, r) => a + r.distance);

    final summary = WarmUpSummary(
      avgMovement: _avg(boardMoves.map((r) => r.movement)),
      avgReaction: _avg(_results.map((r) => r.reaction)),
      avgSpeed: sumMove > 0 ? sumDist / sumMove : 0,
      mistakes: _results.fold<int>(0, (a, r) => a + r.mistakes),
      totalSeconds: _totalSeconds,
    );
    _summary = summary;

    if (widget.coolDown) {
      coolDownSummary = summary;
      final w = warmUpSummary;
      TrainingHistoryService.instance.addSession(TrainingSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        activity: 'Cool-Down',
        date: DateTime.now(),
        difficulty: currentDifficulty?.label ?? 'Standard',
        durationSeconds: summary.totalSeconds.round(),
        completed: true,
        notes: w == null
            ? 'Avg move ${summary.avgMovement.toStringAsFixed(1)} s | '
                '${summary.mistakes} mistake(s)'
            : 'Speed ${w.avgSpeed.toStringAsFixed(2)} to '
                '${summary.avgSpeed.toStringAsFixed(2)} squares/s vs warm-up | '
                '${summary.mistakes} mistake(s)',
      ));
    } else {
      final level = levelFor(summary.avgMovement, summary.mistakes);
      _level = level;
      currentDifficulty = level;
      warmUpSummary = summary;
      sessionTasks = List<WarmUpTask>.of(_tasks);
      warmUpDone = true;
      TrainingHistoryService.instance.addSession(TrainingSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        activity: 'Warm-Up',
        date: DateTime.now(),
        difficulty: level.label,
        durationSeconds: summary.totalSeconds.round(),
        completed: true,
        notes: 'Level set: ${level.label} | avg move '
            '${summary.avgMovement.toStringAsFixed(1)} s | '
            '${summary.mistakes} mistake(s)',
      ));
    }
    _message = '$_name complete!';
  }

  // =========================================================================
  // UI
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_name), centerTitle: true),
      body: SafeArea(
        child: _phase == WarmUpPhase.done ? _buildResult() : _buildTest(),
      ),
    );
  }

  Widget _buildTest() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Center(
              child: Text(
                _message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: kInk),
              ),
            ),
          ),
          Text(
            fmtSeconds(_totalSeconds),
            style: const TextStyle(
                fontSize: 30, fontWeight: FontWeight.bold, color: kTeal),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final side =
                    c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
                return Center(
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: _buildBoard(side),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (_phase == WarmUpPhase.playing) _buildBank(),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: _phase == WarmUpPhase.idle
                ? FilledButton(
                    onPressed: _start,
                    style: FilledButton.styleFrom(
                        backgroundColor: kBlue,
                        minimumSize: const Size.fromHeight(52)),
                    child: Text('Start $_name',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  )
                : Center(
                    child: Text(
                      'Task ${_taskIndex + 1} of ${_tasks.length}'
                      '${_held != null ? '   •   Holding Tile $_held' : ''}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kBlue),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(double side) {
    return Column(
      children: List.generate(
        3,
        (r) => Expanded(
          child: Row(
            children: List.generate(
              3,
              (c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _buildCell(r * 3 + c, side / 3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int index, double cellSide) {
    final playing = _phase == WarmUpPhase.playing;
    final bool isMole = playing && _task.to == index;
    final bool isSource =
        playing && _held == null && _expectedSource == index;
    final tile = _board[index];

    Color bg = Colors.white;
    Color border = const Color(0xFFE0E0E0);
    double bw = 1.5;
    if (isSource) {
      bg = const Color(0xFFE3F0FF);
      border = kBlue;
      bw = 3;
    }
    if (isMole) {
      bg = const Color(0xFFFFEBEE);
      border = Colors.redAccent;
      bw = 3.5;
    }

    return GestureDetector(
      onTap: () => _tapCell(index),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: bw),
          boxShadow: isMole
              ? [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 4,
              right: 8,
              child: Text(cellLabel(index),
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
            ),
            if (isMole && tile == null)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.stars_rounded, size: 34, color: Colors.redAccent),
                  Text('HIT!',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent)),
                ],
              ),
            if (tile != null) _tileUi(tile, cellSide * 0.55),
          ],
        ),
      ),
    );
  }

  Widget _tileUi(String id, double size, {bool glow = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kTeal,
        borderRadius: BorderRadius.circular(14),
        border: glow ? Border.all(color: kBlue, width: 3) : null,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        id,
        style: TextStyle(
            fontSize: size * 0.45,
            fontWeight: FontWeight.bold,
            color: Colors.white),
      ),
    );
  }

  Widget _buildBank() {
    final onBoard = _board.values.toSet();
    final inBank = ['A', 'B']
        .where((t) => !onBoard.contains(t) && t != _held)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F2F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Tile Bank',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          if (inBank.isEmpty)
            const Text('(empty)', style: TextStyle(color: Colors.black54)),
          ...inBank.map((t) {
            final pickable = _held == null &&
                _expectedSource == null &&
                t == _task.tileId;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => _tapBank(t),
                child: _tileUi(t, 56, glow: pickable),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _line(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      );

  Widget _buildResult() {
    final s = _summary!;
    final w = warmUpSummary;

    final List<Widget> rows;
    final String headline;
    if (widget.coolDown && w != null) {
      headline = 'Compared with your warm-up';
      rows = [
        _line('Movement time: ${fmtSeconds(w.avgMovement)} to '
            '${fmtSeconds(s.avgMovement)}'),
        _line('Speed: ${w.avgSpeed.toStringAsFixed(2)} to '
            '${s.avgSpeed.toStringAsFixed(2)} squares/s'),
        _line('Reaction time: ${fmtSeconds(w.avgReaction)} to '
            '${fmtSeconds(s.avgReaction)}'),
        _line('Wrong placements: ${w.mistakes} to ${s.mistakes}'),
      ];
    } else {
      headline = "Today's Level: ${_level?.label ?? 'Not set'}";
      rows = [
        _line('Average movement time: ${fmtSeconds(s.avgMovement)}'),
        _line('Average reaction time: ${fmtSeconds(s.avgReaction)}'),
        _line('Average speed: ${s.avgSpeed.toStringAsFixed(2)} squares/s'),
        _line('Wrong placements: ${s.mistakes}'),
      ];
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$_name complete!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: kInk)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kTeal, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kTeal)),
                const SizedBox(height: 12),
                ...rows,
              ],
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
                backgroundColor: kTeal,
                minimumSize: const Size.fromHeight(54)),
            child: Text(widget.coolDown ? 'Finish Session' : 'Continue',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          if (!widget.coolDown) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _start,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              child:
                  const Text('Redo Assessment', style: TextStyle(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }
}