// RehabSudoku - Step 1: Warm-Up session that sets the Sudoku difficulty
// Replace everything in lib/main.dart with this file.
// No extra packages needed.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const RehabSudokuApp());

// ===========================================================================
// 1. COLORS
// ===========================================================================
const kTeal = Color(0xFF187D8A);
const kBlue = Color(0xFF5374B5);
const kGreen = Color(0xFF4A9A77);
const kBg = Color(0xFFF4F8FB);
const kInk = Color(0xFF1A1F22);

// ===========================================================================
// 2. WARM-UP SETTINGS  (change these numbers to tune the test)
//    These thresholds are PLACEHOLDERS - agree on real values with your
//    therapist / supervisor before using this with patients.
// ===========================================================================

/// How many board-to-board moves come AFTER the first placement.
/// (The first prompt is always "pick a tile and place it at ...", so the
/// patient does kMoves + 1 prompts in total.)
const int kMoves = 6;

/// Each session gets a RANDOM route, but it is only accepted if its total
/// length (in grid squares, summed over the board-to-board moves) is inside
/// this band. That keeps every session's overall difficulty similar.
/// (Tuned for kMoves = 6. If you change kMoves, change these too.)
const double kMinTotalDistance = 9.0;
const double kMaxTotalDistance = 11.0;

/// Average MOVEMENT time per move (seconds from picking the tile up to
/// placing it). At or below this -> Hard.
const double kHardMaxSeconds = 2.0;

/// At or below this (but above the Hard limit) -> Medium. Slower -> Easy.
const double kMediumMaxSeconds = 4.0;

/// This many wrong placements (or more) lowers the level by one step.
const int kMistakeLimit = 3;

// ===========================================================================
// 3. DIFFICULTY + SHARED STATE
// ===========================================================================
enum Difficulty { easy, medium, hard }

extension DifficultyLabel on Difficulty {
  String get label => name[0].toUpperCase() + name.substring(1);
}

/// Turns warm-up results into a Sudoku difficulty.
Difficulty levelFor(double avgMoveSeconds, int mistakes) {
  Difficulty d;
  if (avgMoveSeconds <= kHardMaxSeconds) {
    d = Difficulty.hard;
  } else if (avgMoveSeconds <= kMediumMaxSeconds) {
    d = Difficulty.medium;
  } else {
    d = Difficulty.easy;
  }
  // Many mistakes -> step down one level.
  if (mistakes >= kMistakeLimit && d != Difficulty.easy) {
    d = (d == Difficulty.hard) ? Difficulty.medium : Difficulty.easy;
  }
  return d;
}

/// Has the patient finished the warm-up this session?
/// (Resets when the session ends or the app restarts.)
bool warmUpDone = false;

/// Has the patient opened Sudoku Training this session? (unlocks Cool-Down)
bool trainingStarted = false;

/// The level set by the latest warm-up.
Difficulty? currentDifficulty;

/// The route (cell indices 0-8) used in this session's warm-up.
/// The cool-down repeats the SAME route so the two can be compared directly.
List<int>? sessionPath;

class WarmUpSummary {
  final double avgMovement; // seconds per move (first prompt left out)
  final double avgReaction; // seconds
  final double avgSpeed; // grid squares per second
  final int mistakes;
  final double totalSeconds;
  WarmUpSummary({
    required this.avgMovement,
    required this.avgReaction,
    required this.avgSpeed,
    required this.mistakes,
    required this.totalSeconds,
  });
}

WarmUpSummary? warmUpSummary;
WarmUpSummary? coolDownSummary;

/// Starts a fresh session (called after the cool-down is finished).
/// My Progress history is kept.
void resetSession() {
  warmUpDone = false;
  trainingStarted = false;
  currentDifficulty = null;
  sessionPath = null;
  warmUpSummary = null;
  coolDownSummary = null;
}

/// Straight-line distance between two cells, in grid squares.
double cellDistance(int a, int b) {
  final dr = (a ~/ 3) - (b ~/ 3);
  final dc = (a % 3) - (b % 3);
  return sqrt((dr * dr + dc * dc).toDouble());
}

/// Random route: the first cell, then kMoves more cells (never the same cell
/// twice in a row). Retries until the total distance is inside the band.
List<int> generatePath() {
  final rng = Random();
  List<int> last = [];
  for (var attempt = 0; attempt < 500; attempt++) {
    final path = <int>[rng.nextInt(9)];
    var total = 0.0;
    for (var m = 0; m < kMoves; m++) {
      int next;
      do {
        next = rng.nextInt(9);
      } while (next == path.last);
      total += cellDistance(path.last, next);
      path.add(next);
    }
    last = path;
    if (total >= kMinTotalDistance && total <= kMaxTotalDistance) return path;
  }
  return last; // fallback (very unlikely)
}

class SessionRecord {
  final String type; // 'Sudoku' or 'Warm-Up'
  final DateTime date;
  final double seconds;
  final String detail;
  SessionRecord(this.type, this.date, this.seconds, this.detail);
}

/// Simple in-memory history. Later: swap for shared_preferences / Firebase.
final List<SessionRecord> history = [];

String fmtSeconds(double s) => '${s.toStringAsFixed(1)} s';

// ===========================================================================
// 4. APP
// ===========================================================================
class RehabSudokuApp extends StatelessWidget {
  const RehabSudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RehabSudoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kTeal),
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kTeal,
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ===========================================================================
// 5. HOME
// ===========================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Opens a screen, and refreshes Home when we come back
  // (so the lock and the level update after the warm-up).
  void _go(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      // Cool-down finished -> the session is over, start fresh.
      if (coolDownSummary != null) resetSession();
      if (mounted) setState(() {});
    });
  }

  void _hint(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final levelText = warmUpDone
        ? "Today's level: ${currentDifficulty!.label}"
        : "Start with your warm-up to set today's level.";

    return Scaffold(
      appBar: AppBar(title: const Text('RehabSudoku')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFDFF1F1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hello, Patient!',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: kInk)),
                const SizedBox(height: 10),
                const Text('Welcome to your rehabilitation session.',
                    style: TextStyle(fontSize: 17, color: kInk)),
                const SizedBox(height: 10),
                Text(levelText,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: kTeal)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('What would you like to do today?',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600, color: kInk)),
          const SizedBox(height: 16),

          // Step 1: Warm-Up (new random route; sets today's level)
          ActionCard(
            icon: Icons.touch_app,
            color: kBlue,
            title: 'Warm-Up',
            description:
                "Move a tile around the board to get your arm ready. This sets today's Sudoku level.",
            buttonLabel: !warmUpDone
                ? 'Start Warm-Up'
                : (trainingStarted ? 'Warm-Up Done' : 'Redo Warm-Up'),
            onPressed: (warmUpDone && trainingStarted)
                ? null
                : () => _go(const WarmUpScreen()),
          ),

          // Step 2: Sudoku Training (locked until warm-up is done)
          ActionCard(
            icon: Icons.grid_on,
            color: kTeal,
            locked: !warmUpDone,
            title: 'Sudoku Training',
            description: 'Exercise your arm while solving Sudoku puzzles.',
            buttonLabel: warmUpDone ? 'Start Training' : 'Finish Warm-Up First',
            onPressed: warmUpDone
                ? () => _go(const SudokuScreen())
                : () => _hint('Please finish your warm-up first.'),
          ),

          // Step 3: Cool-Down (same route as the warm-up, then compare)
          ActionCard(
            icon: Icons.touch_app,
            color: kBlue,
            locked: !(warmUpDone && trainingStarted),
            title: 'Cool-Down',
            description:
                'Repeat the same moves to compare how your arm moves after training.',
            buttonLabel: (warmUpDone && trainingStarted)
                ? 'Start Cool-Down'
                : 'Finish Training First',
            onPressed: (warmUpDone && trainingStarted)
                ? () => _go(const WarmUpScreen(coolDown: true))
                : () => _hint('Do some Sudoku training before your cool-down.'),
          ),

          ActionCard(
            icon: Icons.bar_chart_rounded,
            color: kGreen,
            title: 'My Progress',
            description: 'View your training history and progress.',
            buttonLabel: 'View Progress',
            onPressed: () => _go(const ProgressScreen()),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              "Move at your own pace and follow your therapist's guidance.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool locked;

  const ActionCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final shade = locked ? Colors.grey : color;
    return Card(
      color: Colors.white,
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(locked ? Icons.lock_outline : icon, size: 44, color: shade),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w600, color: kInk)),
            const SizedBox(height: 8),
            Text(description,
                style: const TextStyle(fontSize: 17, color: kInk)),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: shade,
                minimumSize: const Size.fromHeight(58),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(buttonLabel,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 6. WARM-UP / COOL-DOWN (baseline tile-movement test)
//
// The same screen is used for both. The board starts EMPTY. The prompts are:
//   1st prompt : "Pick a tile and place it at (r,c)"      (tile comes from off-board)
//   next ones  : "Move the tile from (a,b) to (r,c)"
// For every prompt the app measures:
//   - reaction time : instruction appears -> patient picks up the tile
//   - movement time : tile picked up      -> tile placed on the target
// and counts wrong placements.
//
// The 1st prompt starts off-board, so its distance is unknown. It is saved
// but LEFT OUT of the movement-time and speed averages.
//
// WARM-UP   : makes a new random route, and sets today's Sudoku level.
// COOL-DOWN : repeats the SAME route, then compares with the warm-up.
//
// Later, the taps are replaced by ESP32 sensor events - the timing logic
// stays the same.
// ===========================================================================
enum WarmUpPhase { idle, waitingLift, carrying, done }

/// Cell index 0-8 -> "(row,col)" using 1-3 numbering, e.g. 8 -> "(3,3)".
String cellLabel(int index) => '(${index ~/ 3 + 1},${index % 3 + 1})';

class MoveResult {
  final double reaction; // seconds
  final double movement; // seconds
  final double distance; // in grid squares (0 for the first prompt)
  final int mistakes;
  final bool isFirst; // first prompt = placed from off-board
  MoveResult(
      this.reaction, this.movement, this.distance, this.mistakes, this.isFirst);
}

class WarmUpScreen extends StatefulWidget {
  /// false = warm-up (new random route), true = cool-down (same route).
  final bool coolDown;
  const WarmUpScreen({super.key, this.coolDown = false});

  @override
  State<WarmUpScreen> createState() => _WarmUpScreenState();
}

class _WarmUpScreenState extends State<WarmUpScreen> {
  final Stopwatch _total = Stopwatch(); // whole test
  final Stopwatch _lap = Stopwatch(); // current phase (reaction or movement)
  Timer? _ticker;

  List<int> _path = []; // target cells (0-8) in order
  WarmUpPhase _phase = WarmUpPhase.idle;
  int _move = 0; // which prompt we are on (0 = first)
  int? _tileAt; // where the tile is on the board (null = not placed yet)
  int _mistakesThisMove = 0;
  double _reactionTime = 0; // reaction time of the current prompt
  final List<MoveResult> _results = [];
  late String _message =
      'Pick a tile and move it as instructed.\nPress Start $_name to begin.';

  WarmUpSummary? _summary;
  Difficulty? _level; // warm-up only

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

  // Patient picks up the tile (button for the 1st prompt, tap on the tile after).
  void _lift() {
    if (_phase != WarmUpPhase.waitingLift) return;
    setState(() {
      _reactionTime = _lapSeconds; // reaction time measured
      _lap
        ..reset()
        ..start(); // start timing the movement
      _phase = WarmUpPhase.carrying;
      _message = 'Now place it at ${cellLabel(_path[_move])}.';
    });
  }

  // Patient taps a square on the board.
  void _tapCell(int i) {
    if (_phase != WarmUpPhase.waitingLift && _phase != WarmUpPhase.carrying) {
      return;
    }
    final target = _path[_move];
    final int? from = _move == 0 ? null : _path[_move - 1];

    // 1) Waiting for the patient to pick up the tile.
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

    // 2) Tile is picked up and being carried.
    if (from != null && i == from) return; // tapped the start square - ignore
    if (i != target) {
      // Wrong square: count a mistake, keep the clock running.
      setState(() {
        _mistakesThisMove++;
        _message = 'Not there - place it at ${cellLabel(target)}.';
      });
      return;
    }

    // Correct square: save this prompt.
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
          ..start(); // start timing the next reaction
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

    // Movement time + speed leave out the first prompt (starts off-board).
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

  // ---------------------------------------------------------------- UI ----

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
    // 1st prompt: there is no tile on the board yet, so use a button.
    // (With the real hardware, the ESP32 detects the tile being lifted.)
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
          // Instruction (fixed height so the board does not jump around)
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

          // The board takes all remaining space, as a square.
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
            'Simulation Mode: pick-up and placement are simulated with taps. '
            'No ESP32 sensors connected yet.',
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
        // FittedBox shrinks the content if the cell is small.
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

  // "faster" / "slower" etc. Treats tiny differences as "about the same".
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

// ===========================================================================
// 7. SUDOKU (my simple placeholder - will be replaced by your group mate's)
// For now it only DISPLAYS today's level. The level will change the puzzle
// once the group mate's generator (easy / medium / hard) is plugged in.
// ===========================================================================
class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  static const String _puzzle =
      '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
  static const String _solution =
      '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

  late List<int> board;
  late List<bool> given;
  int? selected;
  final Stopwatch sw = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    trainingStarted = true; // unlocks the cool-down
    _reset();
  }

  void _reset() {
    board = _puzzle.split('').map(int.parse).toList();
    given = board.map((v) => v != 0).toList();
    selected = null;
    sw
      ..reset()
      ..start();
  }

  bool _isPeer(int a, int b) {
    final ra = a ~/ 9, ca = a % 9, rb = b ~/ 9, cb = b % 9;
    return ra == rb ||
        ca == cb ||
        (ra ~/ 3 == rb ~/ 3 && ca ~/ 3 == cb ~/ 3);
  }

  void _enter(int value) {
    final s = selected;
    if (s == null || given[s]) return;
    setState(() => board[s] = value);
    if (board.join() == _solution) _onSolved();
  }

  void _onSolved() {
    sw.stop();
    final secs = sw.elapsedMilliseconds / 1000;
    history.add(SessionRecord('Sudoku', DateTime.now(), secs,
        'Puzzle solved (${currentDifficulty?.label ?? 'no'} level)'));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Well done!'),
        content: Text('You solved the puzzle in ${fmtSeconds(secs)}.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(_reset);
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
  }

  Widget _cell(int i) {
    final r = i ~/ 9, c = i % 9;
    final v = board[i];
    final isSel = selected == i;
    final isPeer = selected != null && !isSel && _isPeer(selected!, i);
    final wrong = v != 0 && !given[i] && v != int.parse(_solution[i]);

    Color bg = Colors.white;
    if (isPeer) bg = const Color(0xFFE0F1F3);
    if (isSel) bg = const Color(0xFFB2DFE4);

    const dark = Color(0xFF37474F);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selected = i),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              left: BorderSide(width: c % 3 == 0 ? 2.5 : 0.5, color: dark),
              top: BorderSide(width: r % 3 == 0 ? 2.5 : 0.5, color: dark),
              right: BorderSide(width: c == 8 ? 2.5 : 0.0, color: dark),
              bottom: BorderSide(width: r == 8 ? 2.5 : 0.0, color: dark),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            v == 0 ? '' : '$v',
            style: TextStyle(
              fontSize: 24,
              fontWeight: given[i] ? FontWeight.w800 : FontWeight.w500,
              color: wrong ? Colors.red : (given[i] ? kInk : kTeal),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku Training')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFDFF1F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "Today's level: ${currentDifficulty?.label ?? 'Not set'}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: kTeal),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Tap a square, then tap a number.',
                style: TextStyle(fontSize: 17, color: kInk)),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: Column(
                children: List.generate(
                  9,
                  (r) => Expanded(
                    child: Row(
                        children: List.generate(9, (c) => _cell(r * 9 + c))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var n = 1; n <= 9; n++)
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: FilledButton(
                      onPressed: () => _enter(n),
                      style: FilledButton.styleFrom(
                          backgroundColor: kTeal,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      child: Text('$n',
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w700)),
                    ),
                  ),
                SizedBox(
                  width: 64,
                  height: 64,
                  child: OutlinedButton(
                    onPressed: () => _enter(0),
                    style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    child: const Icon(Icons.backspace_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 8. PROGRESS
// ===========================================================================
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
