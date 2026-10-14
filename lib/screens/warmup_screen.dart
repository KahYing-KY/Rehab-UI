import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';

enum WarmUpPhase { idle, waitingLift, carrying, done }

String cellLabel(int index) => '(${index ~/ 3 + 1},${index % 3 + 1})';

class MoveResult {
  final double reaction;
  final double movement;
  final double distance;
  final int mistakes;
  final bool isFirst;
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

  List<int> _path = [];
  WarmUpPhase _phase = WarmUpPhase.idle;
  int _move = 0;
  int? _tileAt;
  int _mistakesThisMove = 0;
  double _reactionTime = 0;
  final List<MoveResult> _results = [];
  late String _message =
      'Pick a tile and move it as instructed.\nPress Start $_name to begin.';

  WarmUpSummary? _summary;
  Difficulty? _level;

  String get _name => widget.coolDown ? 'Cool-Down' : 'Warm-Up';
  double get _totalSeconds => _total.elapsedMilliseconds / 1000;
  double get _lapSeconds => _lap.elapsedMilliseconds / 1000;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _instruction() {
    final to = cellLabel(_path[_move]);
    if (_move == 0) return 'Pick a tile and place it at $to.';
    return 'Move the tile from ${cellLabel(_path[_move - 1])} to $to.';
  }

  void _start() {
    setState(() {
      _path = widget.coolDown
          ? List<int>.of(sessionPath ?? generatePath())
          : generatePath();
      _move = 0;
      _tileAt = null;
      _mistakesThisMove = 0;
      _reactionTime = 0;
      _results.clear();
      _summary = null;
      _level = null;
      _phase = WarmUpPhase.waitingLift;
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

  void _lift() {
    if (_phase != WarmUpPhase.waitingLift) return;
    setState(() {
      _reactionTime = _lapSeconds;
      _lap
        ..reset()
        ..start();
      _phase = WarmUpPhase.carrying;
      _message = 'Now place it at ${cellLabel(_path[_move])}.';
    });
  }

  void _tapCell(int i) {
    if (_phase != WarmUpPhase.waitingLift && _phase != WarmUpPhase.carrying) {
      return;
    }
    final target = _path[_move];
    final int? from = _move == 0 ? null : _path[_move - 1];

    if (_phase == WarmUpPhase.waitingLift) {
      if (from == null) {
        setState(() => _message = 'Press "Pick Up Tile" first.');
      } else if (i == from) {
        _lift();
      } else {
        setState(() =>
            _message = 'Tap the tile at ${cellLabel(from)} to pick it up.');
      }
      return;
    }

    if (from != null && i == from) return;
    if (i != target) {
      setState(() {
        _mistakesThisMove++;
        _message = 'Not there - place it at ${cellLabel(target)}.';
      });
      return;
    }

    setState(() {
      final dist = from == null ? 0.0 : cellDistance(from, target);
      _results.add(MoveResult(
          _reactionTime, _lapSeconds, dist, _mistakesThisMove, from == null));
      _tileAt = target;
      _move++;
      _mistakesThisMove = 0;
      if (_move >= _path.length) {
        _finish();
      } else {
        _phase = WarmUpPhase.waitingLift;
        _lap
          ..reset()
          ..start();
        _message = 'Good! ${_instruction()}';
      }
    });
  }

  double _avg(Iterable<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  void _finish() {
    _total.stop();
    _lap.stop();
    _ticker?.cancel();
    _phase = WarmUpPhase.done;

    final board = _results.where((r) => !r.isFirst).toList();
    final sumMove = board.fold<double>(0, (a, r) => a + r.movement);
    final sumDist = board.fold<double>(0, (a, r) => a + r.distance);

    final summary = WarmUpSummary(
      avgMovement: _avg(board.map((r) => r.movement)),
      avgReaction: _avg(_results.map((r) => r.reaction)),
      avgSpeed: sumMove > 0 ? sumDist / sumMove : 0,
      mistakes: _results.fold<int>(0, (a, r) => a + r.mistakes),
      totalSeconds: _totalSeconds,
    );
    _summary = summary;

    if (widget.coolDown) {
      coolDownSummary = summary;
      final w = warmUpSummary;
      history.add(SessionRecord(
        'Cool-Down',
        DateTime.now(),
        summary.totalSeconds,
        w == null
            ? 'Avg move ${summary.avgMovement.toStringAsFixed(1)} s'
            : 'Speed ${w.avgSpeed.toStringAsFixed(2)} to '
                '${summary.avgSpeed.toStringAsFixed(2)} squares/s vs warm-up',
      ));
    } else {
      final level = levelFor(summary.avgMovement, summary.mistakes);
      _level = level;
      currentDifficulty = level;
      warmUpSummary = summary;
      sessionPath = List<int>.of(_path);
      warmUpDone = true;
      history.add(SessionRecord(
        'Warm-Up',
        DateTime.now(),
        summary.totalSeconds,
        'Level set: ${level.label} - avg move '
            '${summary.avgMovement.toStringAsFixed(1)} s, '
            '${summary.mistakes} mistake(s)',
      ));
    }
    _message = '$_name complete!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_name)),
      body: SafeArea(
        child: _phase == WarmUpPhase.done ? _buildResult() : _buildTest(),
      ),
    );
  }

  Widget _bottomAction() {
    if (_phase == WarmUpPhase.idle) {
      return FilledButton(
        onPressed: _start,
        style: FilledButton.styleFrom(
            backgroundColor: kBlue, minimumSize: const Size.fromHeight(56)),
        child: Text('Start $_name',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      );
    }
    if (_phase == WarmUpPhase.waitingLift && _move == 0) {
      return FilledButton.icon(
        onPressed: _lift,
        icon: const Icon(Icons.touch_app),
        label: const Text('Pick Up Tile',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
            backgroundColor: kTeal, minimumSize: const Size.fromHeight(56)),
      );
    }
    return Center(
      child: Text('Move ${_move + 1} of ${_path.length}',
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, color: kBlue)),
    );
  }

  Widget _buildTest() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: 60,
            child: Center(
              child: Text(
                _message,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w600, color: kInk),
              ),
            ),
          ),
          Text(fmtSeconds(_totalSeconds),
              style: const TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w700, color: kTeal)),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final side = min(c.maxWidth, c.maxHeight);
                return Center(
                  child: SizedBox(width: side, height: side, child: _board()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(height: 56, child: _bottomAction()),
          const SizedBox(height: 4),
          const Text(
            'Simulation Mode: pick-up and placement are simulated with taps.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _board() {
    return Column(
      children: List.generate(
        3,
        (r) => Expanded(
          child: Row(
            children: List.generate(
              3,
              (c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: _cell(r * 3 + c),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(int i) {
    final carrying = _phase == WarmUpPhase.carrying;
    final hasTile = _tileAt == i;
    final lifted = carrying && hasTile;
    final isTarget = carrying && _path[_move] == i;

    return GestureDetector(
      onTap: () => _tapCell(i),
      child: Container(
        decoration: BoxDecoration(
          color: isTarget ? const Color(0xFFE3ECF8) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isTarget ? kBlue : const Color(0xFFE0E0E0),
            width: isTarget ? 3 : 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasTile)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: lifted ? const Color(0xFFB2DFE4) : kTeal,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('Tile',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                if (isTarget)
                  const Text('Move here',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: kBlue)),
                Text(cellLabel(i), style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _change(double before, double after, String less, String more) {
    if ((after - before).abs() < 0.05) return 'about the same';
    return after < before ? less : more;
  }

  Widget _line(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 17)),
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
            '${fmtSeconds(s.avgMovement)} '
            '(${_change(w.avgMovement, s.avgMovement, 'faster', 'slower')})'),
        _line('Speed: ${w.avgSpeed.toStringAsFixed(2)} to '
            '${s.avgSpeed.toStringAsFixed(2)} squares/s '
            '(${_change(w.avgSpeed, s.avgSpeed, 'slower', 'faster')})'),
        _line('Reaction time: ${fmtSeconds(w.avgReaction)} to '
            '${fmtSeconds(s.avgReaction)} '
            '(${_change(w.avgReaction, s.avgReaction, 'faster', 'slower')})'),
        _line('Wrong placements: ${w.mistakes} to ${s.mistakes} '
            '(${_change(w.mistakes.toDouble(), s.mistakes.toDouble(), 'fewer', 'more')})'),
      ];
    } else {
      headline = "Today's level: ${_level?.label ?? 'Not set'}";
      rows = [
        _line('Average movement time: ${fmtSeconds(s.avgMovement)}'),
        _line('Average reaction time: ${fmtSeconds(s.avgReaction)}'),
        _line('Average speed: ${s.avgSpeed.toStringAsFixed(2)} squares/s'),
        _line('Wrong placements: ${s.mistakes}'),
      ];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$_name complete!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700, color: kInk)),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: kTeal)),
                const SizedBox(height: 12),
                ...rows,
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
                backgroundColor: kTeal,
                minimumSize: const Size.fromHeight(58)),
            child: Text(widget.coolDown ? 'Finish Session' : 'Continue',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          if (!widget.coolDown) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _start,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child:
                  const Text('Redo Warm-Up', style: TextStyle(fontSize: 17)),
            ),
          ],
        ],
      ),
    );
  }
}