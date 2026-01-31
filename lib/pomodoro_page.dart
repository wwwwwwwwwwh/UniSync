import 'dart:async';
import 'package:flutter/material.dart';

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  static const int focusSecondsDefault = 25 * 60;
  static const int breakSecondsDefault = 5 * 60;

  bool isFocus = true; // true=Focus, false=Break
  bool running = false;

  int remaining = focusSecondsDefault;
  int focusCompleted = 0;

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    if (running) return;
    setState(() => running = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (remaining <= 1) {
        _timer?.cancel();
        _timer = null;

        // Finish the current phase
        if (isFocus) {
          focusCompleted += 1;
        }

        // Auto switch phase
        isFocus = !isFocus;
        remaining = isFocus ? focusSecondsDefault : breakSecondsDefault;
        running = false;

        setState(() {});
        _showDoneSnack();
        return;
      }

      setState(() => remaining -= 1);
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    setState(() => running = false);
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      running = false;
      remaining = isFocus ? focusSecondsDefault : breakSecondsDefault;
    });
  }

  void _skip() {
    _timer?.cancel();
    _timer = null;

    setState(() {
      running = false;
      if (isFocus) focusCompleted += 1;
      isFocus = !isFocus;
      remaining = isFocus ? focusSecondsDefault : breakSecondsDefault;
    });

    _showDoneSnack();
  }

  void _showDoneSnack() {
    final msg = isFocus
        ? 'Break finished — back to Focus 💪'
        : 'Focus completed — take a break ☕';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _mmss(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final title = isFocus ? 'Focus' : 'Break';
    final subtitle = isFocus ? '25 minutes deep work' : '5 minutes rest';

    return Scaffold(
      appBar: AppBar(title: const Text('Pomodoro Timer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(subtitle),
                          const SizedBox(height: 12),
                          Text(
                            _mmss(remaining),
                            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text('Focus done', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 6),
                        Text(
                          '$focusCompleted',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: running ? null : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: running ? _pause : null,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _skip,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Skip'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Card(
              child: ListTile(
                title: const Text('Switch mode'),
                subtitle: Text(isFocus ? 'Currently: Focus' : 'Currently: Break'),
                trailing: const Icon(Icons.swap_horiz),
                onTap: () {
                  _timer?.cancel();
                  _timer = null;
                  setState(() {
                    running = false;
                    isFocus = !isFocus;
                    remaining = isFocus ? focusSecondsDefault : breakSecondsDefault;
                  });
                },
              ),
            ),

            const Spacer(),
            const Text('Tip: Use Focus mode for study, Break mode to rest your eyes.'),
          ],
        ),
      ),
    );
  }
}
