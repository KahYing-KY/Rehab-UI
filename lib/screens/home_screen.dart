import 'package:flutter/material.dart';
import '../main.dart';
import 'warmup_screen.dart';
import 'sudoku_screen.dart';
import 'progress_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _go(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) {
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: ListView(
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
          ),
        ),
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