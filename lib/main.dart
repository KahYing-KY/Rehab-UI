import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://placeholder.supabase.co',
    publishableKey: 'placeholder-key',
  );

  runApp(const RehabSudokuApp());
}

// ===========================================================================
// 1. COLORS
// ===========================================================================
const kTeal = Color(0xFF187D8A);
const kBlue = Color(0xFF5374B5);
const kGreen = Color(0xFF4A9A77);
const kBg = Color(0xFFF4F8FB);
const kInk = Color(0xFF1A1F22);

// ===========================================================================
// 2. WARM-UP SETTINGS
// ===========================================================================
const int kMoves = 8; // number of pick-and-place tasks in warm-up / cool-down
const double kHardMaxSeconds = 2.0;
const double kMediumMaxSeconds = 4.0;
const int kMistakeLimit = 3;

// ===========================================================================
// 3. SHARED STATE & ENUMS
// ===========================================================================
enum Difficulty { easy, medium, hard }

extension DifficultyLabel on Difficulty {
  String get label => name[0].toUpperCase() + name.substring(1);
}

Difficulty levelFor(double avgMoveSeconds, int mistakes) {
  Difficulty d;
  if (avgMoveSeconds <= kHardMaxSeconds) {
    d = Difficulty.hard;
  } else if (avgMoveSeconds <= kMediumMaxSeconds) {
    d = Difficulty.medium;
  } else {
    d = Difficulty.easy;
  }
  if (mistakes >= kMistakeLimit && d != Difficulty.easy) {
    d = (d == Difficulty.hard) ? Difficulty.medium : Difficulty.easy;
  }
  return d;
}

bool warmUpDone = false;
bool trainingStarted = false;
Difficulty? currentDifficulty;
List<WarmUpTask>? sessionTasks;

/// One pick-and-place task. from == null means "take the tile from the bank".
/// Cells are numbered 0..8 (row-major).
class WarmUpTask {
  final String tileId;
  final int? from;
  final int to;
  const WarmUpTask(this.tileId, this.from, this.to);
}

class WarmUpSummary {
  final double avgMovement;
  final double avgReaction;
  final double avgSpeed;
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

void resetSession() {
  warmUpDone = false;
  trainingStarted = false;
  currentDifficulty = null;
  sessionTasks = null;
  warmUpSummary = null;
  coolDownSummary = null;
}

double cellDistance(int a, int b) {
  final dr = (a ~/ 3) - (b ~/ 3);
  final dc = (a % 3) - (b % 3);
  return sqrt((dr * dr + dc * dc).toDouble());
}

/// Reach Quest style planner: tiles A and B are introduced from the bank,
/// every other task moves a tile that is already on the board.
/// Every destination is unique, so a destination is always empty.
List<WarmUpTask> generateTasks() {
  final rng = Random();
  final positions = List<int>.generate(9, (i) => i)..shuffle(rng);
  final board = <int, String>{};
  final tasks = <WarmUpTask>[];

  for (var i = 0; i < kMoves; i++) {
    final dest = positions[i];
    String tile;
    int? src;

    if (i == 0) {
      tile = 'A';
      src = null;
    } else if (i == 2) {
      tile = 'B';
      src = null;
    } else {
      final occupied = board.keys.toList();
      src = occupied[rng.nextInt(occupied.length)];
      tile = board[src]!;
    }

    tasks.add(WarmUpTask(tile, src, dest));
    if (src != null) board.remove(src);
    board[dest] = tile;
  }
  return tasks;
}

String fmtSeconds(double s) => '${s.toStringAsFixed(1)} s';

// ===========================================================================
// 4. APP ROOT
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