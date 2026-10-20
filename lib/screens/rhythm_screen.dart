import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../main.dart';
import 'training_session.dart';
import 'training_history_service.dart';

class _Note {
  final int lane;
  double top = -0.3;
  _Note(this.lane);
}

enum _RPhase { idle, playing, over }

class RhythmGameScreen extends StatefulWidget {
  const RhythmGameScreen({super.key});

  @override
  State<RhythmGameScreen> createState() => _RhythmGameScreenState();
}

class _RhythmGameScreenState extends State<RhythmGameScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxTiles = 30;
  static const double _perfectPos = 0.85;
  static const double _noteH = 28;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final Random _random = Random();
  final Stopwatch _sw = Stopwatch();

  final List<_Note> _notes = [];
  _RPhase _phase = _RPhase.idle;

  double _speed = 0.45;
  double _spawnEvery = 1.5;
  double _spawnTimer = 0;

  int _score = 0, _combo = 0, _spawned = 0, _hit = 0;
  int _perfect = 0, _early = 0, _late = 0, _missed = 0;
  String _judgment = '';
  Color _judgmentColor = Colors.grey;
  final List<bool> _pressed = [false, false, false];

  Difficulty get _level => currentDifficulty ?? Difficulty.medium;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _startGame() {
    switch (_level) {
      case Difficulty.easy:
        _speed = 0.35;
        _spawnEvery = 1.8;
        break;
      case Difficulty.medium:
        _speed = 0.45;
        _spawnEvery = 1.5;
        break;
      case Difficulty.hard:
        _speed = 0.60;
        _spawnEvery = 1.2;
        break;
    }
    setState(() {
      _notes.clear();
      _spawnTimer = _spawnEvery; // first note spawns immediately
      _score = 0;
      _combo = 0;
      _spawned = 0;
      _hit = 0;
      _perfect = 0;
      _early = 0;
      _late = 0;
      _missed = 0;
      _judgment = '';
      _judgmentColor = Colors.grey;
      _phase = _RPhase.playing;
      _sw
        ..reset()
        ..start();
    });
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    if (_phase != _RPhase.playing) return;

    setState(() {
      _spawnTimer += dt;
      if (_spawnTimer >= _spawnEvery && _spawned < _maxTiles) {
        _spawnTimer = 0;
        _spawned++;
        _notes.add(_Note(_random.nextInt(3)));
      }

      for (final n in _notes) {
        n.top += dt * _speed;
      }

      for (var i = _notes.length - 1; i >= 0; i--) {
        if (_notes[i].top > 0.95) {
          _combo = 0;
          _missed++;
          _judgment = 'MISS';
          _judgmentColor = Colors.red;
          _notes.removeAt(i);
        }
      }

      if (_spawned >= _maxTiles && _notes.isEmpty) {
        _phase = _RPhase.over;
        _sw.stop();
        _saveSession();
      }
    });
  }

  void _saveSession() {
    TrainingHistoryService.instance.addSession(TrainingSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      activity: 'Rhythm Game',
      date: DateTime.now(),
      difficulty: _level.label,
      durationSeconds: (_sw.elapsedMilliseconds / 1000).round(),
      correctAttempts: _hit,
      incorrectAttempts: _maxTiles - _hit,
      completed: true,
      notes:
          'Score $_score | Perfect $_perfect, Early $_early, Late $_late, Missed $_missed',
    ));
  }

  void _tapLane(int lane) {
    if (_phase != _RPhase.playing) return;
    setState(() {
      int best = -1;
      double bestDiff = 99;
      for (var i = 0; i < _notes.length; i++) {
        final n = _notes[i];
        if (n.lane == lane && n.top >= 0.70 && n.top <= 0.95) {
          final d = (n.top - _perfectPos).abs();
          if (d < bestDiff) {
            bestDiff = d;
            best = i;
          }
        }
      }
      if (best == -1) return;

      final note = _notes[best];
      final diff = note.top - _perfectPos;
      final mult = max(1, min(_combo, 10));
      if (diff.abs() <= 0.03) {
        _judgment = 'PERFECT';
        _judgmentColor = Colors.green;
        _score += 100 * mult;
        _perfect++;
      } else if (diff < 0) {
        _judgment = 'EARLY';
        _judgmentColor = Colors.orange;
        _score += 50 * mult;
        _early++;
      } else {
        _judgment = 'LATE';
        _judgmentColor = Colors.blue;
        _score += 50 * mult;
        _late++;
      }
      _combo++;
      _hit++;
      _notes.removeAt(best);
    });
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rhythm Game')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: switch (_phase) {
                _RPhase.idle => _intro(),
                _RPhase.playing => _play(),
                _RPhase.over => _summary(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note_rounded, size: 80, color: kTeal),
          const SizedBox(height: 12),
          const Text('Rhythm Game',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
            '30 notes will fall down three lanes.\nTap the matching lane button when a note reaches the line.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17),
          ),
          const SizedBox(height: 10),
          Text('Speed level: ${_level.label}',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, color: kTeal)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _startGame,
            style: FilledButton.styleFrom(
                backgroundColor: kTeal,
                minimumSize: const Size(220, 56)),
            child: const Text('Start',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  Widget _play() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Score: $_score',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Tile: $_spawned/$_maxTiles',
                style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600)),
            Text('Combo: x$_combo',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange)),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(flex: 3, child: _track()),
                const SizedBox(width: 10),
                SizedBox(width: 80, child: _sidePanel()),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: List.generate(3, _laneButton),
              ),
            ),
            const SizedBox(width: 90),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Tap the lane button when a note reaches the line!',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _track() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(builder: (context, c) {
          final h = c.maxHeight;
          final laneW = c.maxWidth / 3;
          return Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                    2, (_) => Container(width: 1, color: Colors.grey[300])),
              ),
              ..._notes.map((n) => Positioned(
                    left: n.lane * laneW + 6,
                    top: n.top * (h - _noteH),
                    child: Container(
                      width: laneW - 12,
                      height: _noteH,
                      decoration: BoxDecoration(
                        color: kTeal,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 2,
                              offset: Offset(0, 1))
                        ],
                      ),
                    ),
                  )),
              Positioned(
                top: _perfectPos * (h - _noteH) + _noteH / 2,
                left: 0,
                right: 0,
                child: Container(
                    height: 2, color: kTeal.withValues(alpha: 0.8)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _laneButton(int i) {
    final pressed = _pressed[i];
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTapDown: (_) {
            setState(() => _pressed[i] = true);
            _tapLane(i);
          },
          onTapUp: (_) => setState(() => _pressed[i] = false),
          onTapCancel: () => setState(() => _pressed[i] = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            height: 64,
            decoration: BoxDecoration(
              color: pressed ? const Color(0xFF0F525A) : kTeal,
              borderRadius: BorderRadius.circular(12),
              border: pressed ? Border.all(color: Colors.white, width: 2) : null,
              boxShadow: [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: pressed ? 1 : 3,
                    offset: const Offset(0, 2))
              ],
            ),
            alignment: Alignment.center,
            child: Text('L${i + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ),
        ),
      ),
    );
  }

  Widget _sidePanel() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('STATUS',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _judgmentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _judgmentColor, width: 1.5),
            ),
            child: Text(
              _judgment.isEmpty ? '-' : _judgment,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _judgment.isEmpty ? Colors.grey : _judgmentColor),
            ),
          ),
          const SizedBox(height: 16),
          _legend('PERF', Colors.green, 'PERFECT'),
          const SizedBox(height: 6),
          _legend('EARLY', Colors.orange, 'EARLY'),
          const SizedBox(height: 6),
          _legend('LATE', Colors.blue, 'LATE'),
          const SizedBox(height: 6),
          _legend('MISS', Colors.red, 'MISS'),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color, String judgment) {
    final active = _judgment == judgment;
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: Colors.black54)),
      ],
    );
  }

  Widget _summary() {
    final accuracy = _hit / _maxTiles * 100;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
            const SizedBox(height: 8),
            const Text('Performance Summary',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  _row('Final score', '$_score'),
                  const Divider(height: 18),
                  _row('Tiles hit', '$_hit / $_maxTiles'),
                  const Divider(height: 18),
                  _row('Accuracy', '${accuracy.toStringAsFixed(1)}%'),
                  const Divider(height: 18),
                  _row('Perfect / Early / Late',
                      '$_perfect / $_early / $_late'),
                  const Divider(height: 18),
                  _row('Missed', '$_missed'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('Saved to My Progress',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.replay),
              label: const Text('Play Again',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: FilledButton.styleFrom(
                  backgroundColor: kTeal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                fontWeight: FontWeight.w500)),
        Text(value,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}