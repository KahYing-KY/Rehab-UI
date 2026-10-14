import 'dart:math';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

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
// 2. WARM-UP SETTINGS
// ===========================================================================
const int kMoves = 6;
const double kMinTotalDistance = 9.0;
const double kMaxTotalDistance = 11.0;
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
List<int>? sessionPath;

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
  sessionPath = null;
  warmUpSummary = null;
  coolDownSummary = null;
}

double cellDistance(int a, int b) {
  final dr = (a ~/ 3) - (b ~/ 3);
  final dc = (a % 3) - (b % 3);
  return sqrt((dr * dr + dc * dc).toDouble());
}

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
  return last;
}

class SessionRecord {
  final String type;
  final DateTime date;
  final double seconds;
  final String detail;
  SessionRecord(this.type, this.date, this.seconds, this.detail);
}

final List<SessionRecord> history = [];

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