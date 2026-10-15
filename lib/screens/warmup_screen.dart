import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';

enum WarmUpPhase { idle, playing, done }

// Top-level helper function for grid cell coordinates
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
  int? _tileAt; // Current position of the tile
  int _mistakesThisMove = 0;
  double _reactionTime = 0;
  final List<MoveResult> _results = [];
  late String _message =
      'Drag the tile to the mole as quickly as possible!\nPress Start $_name to begin.';

  WarmUpSummary? _summary;
  Difficulty? _level;

  String get _name => widget.coolDown ? 'Cool-Down' : 'Whack-a-Mole Assessment';
  double get _totalSeconds => _total.elapsedMilliseconds / 1000;
  double get _lapSeconds => _lap.elapsedMilliseconds / 1000;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _path = widget.coolDown
          ? List<int>.of(sessionPath ?? generatePath())
          : generatePath();
      _move = 0;
      _tileAt = null; // Start with tile in inventory or starting slot
      _mistakesThisMove = 0;
      _reactionTime = 0;
      _results.clear();
      _summary = null;
      _level = null;
      _phase = WarmUpPhase.playing;
      _message = 'Whack the mole! Drag the tile to cell ${cellLabel(_path[_move])}.';
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

  void _onTilePickedUp() {
    if (_reactionTime == 0 && _lap.isRunning) {
      _reactionTime = _lapSeconds;
    }
  }

  void _handleTileDrop(int targetCellIndex) {
    if (_phase != WarmUpPhase.playing) return;

    final currentTarget = _path[_move];
    final int? from = _tileAt;

    if (targetCellIndex != currentTarget) {
      // Wrong drop location
      setState(() {
        _mistakesThisMove++;
        _message = 'Missed! Drag to the active mole at ${cellLabel(currentTarget)}.';
      });
      return;
    }

    // Correct placement (Mole Hit!)
    setState(() {
      final dist = from == null ? 0.0 : cellDistance(from, currentTarget);
      _results.add(MoveResult(
          _reactionTime == 0 ? _lapSeconds : _reactionTime,
          _lapSeconds,
          dist,
          _mistakesThisMove,
          from == null));

      _tileAt = currentTarget;
      _move++;
      _mistakesThisMove = 0;
      _reactionTime = 0;

      if (_move >= _path.length) {
        _finish();
      } else {
        _lap
          ..reset()
          ..start();
        _message = 'Great hit! Next mole appeared at ${cellLabel(_path[_move])}.';
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
        'Warm-Up (Whack-a-Mole)',
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
          // Header Status
          SizedBox(
            height: 50,
            child: Center(
              child: Text(
                _message,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600, color: kInk),
              ),
            ),
          ),
          Text(
            fmtSeconds(_totalSeconds),
            style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold, color: kTeal),
          ),
          const SizedBox(height: 8),

          // Responsive 3x3 Whack-a-Mole Grid
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = min(constraints.maxWidth, constraints.maxHeight);
                return Center(
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: _buildBoard(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Inventory / Starting Tile Pool (when tile is not on board)
          if (_phase == WarmUpPhase.playing && _tileAt == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Draggable<String>(
                data: 'tile',
                onDragStarted: _onTilePickedUp,
                feedback: Material(
                  color: Colors.transparent,
                  child: _buildTileUI(isDragging: true),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildTileUI(),
                ),
                child: _buildTileUI(),
              ),
            ),

          // Bottom Action
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
                      'Target ${_move + 1} of ${_path.length}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kBlue),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildBoard() {
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
                  child: _buildCell(r * 3 + c),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int index) {
    final bool isTargetMole =
        _phase == WarmUpPhase.playing && _path[_move] == index;
    final bool hasTile = _tileAt == index;

    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        _handleTileDrop(index);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: isTargetMole
                ? const Color(0xFFFFEBEE) // Light red highlight for active mole
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isTargetMole ? Colors.redAccent : const Color(0xFFE0E0E0),
              width: isTargetMole ? 3.5 : 1.5,
            ),
            boxShadow: isTargetMole
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
              // Cell Coordinate Label
              Positioned(
                bottom: 6,
                right: 8,
                child: Text(cellLabel(index),
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
              ),

              // Mole Indicator (Pop-Up Target)
              if (isTargetMole && !hasTile)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.stars_rounded, size: 36, color: Colors.redAccent),
                    SizedBox(height: 2),
                    Text('HIT!',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent)),
                  ],
                ),

              // Draggable Tile inside cell
              if (hasTile)
                Draggable<String>(
                  data: 'tile',
                  onDragStarted: _onTilePickedUp,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _buildTileUI(isDragging: true),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _buildTileUI(),
                  ),
                  child: _buildTileUI(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTileUI({bool isDragging = false}) {
    return Container(
      width: isDragging ? 70 : 64,
      height: isDragging ? 70 : 64,
      decoration: BoxDecoration(
        color: kTeal,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'Tile',
        style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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