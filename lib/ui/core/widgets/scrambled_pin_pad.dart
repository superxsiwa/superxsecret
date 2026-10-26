import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// In-App Scrambled Numeric Keypad that randomizes digit positions `0-9`
/// using `math.Random.secure()` on every render to defeat touch-coordinate
/// logging malware when entering Credit Card PINs or quick unlock codes.
class ScrambledPinPad extends StatefulWidget {
  const ScrambledPinPad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspace,
    required this.onReshuffle,
  });

  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback onReshuffle;

  @override
  State<ScrambledPinPad> createState() => _ScrambledPinPadState();
}

class _ScrambledPinPadState extends State<ScrambledPinPad> {
  late List<int> _digits;

  @override
  void initState() {
    super.initState();
    _scrambleDigits();
  }

  void _scrambleDigits() {
    final rng = math.Random.secure();
    final list = List<int>.generate(10, (i) => i);
    for (var i = list.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    setState(() => _digits = list);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shuffle_rounded,
              size: 14,
              color: AppTheme.emeraldSecure,
            ),
            const SizedBox(width: 6),
            Text(
              'Auto-scrambled keypad (anti-spyware)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            for (var i = 0; i < 9; i++)
              _buildDigitButton(_digits[i].toString()),
            OutlinedButton.icon(
              onPressed: () {
                _scrambleDigits();
                widget.onReshuffle();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Shuffle', style: TextStyle(fontSize: 11)),
            ),
            _buildDigitButton(_digits[9].toString()),
            OutlinedButton(
              onPressed: widget.onBackspace,
              child: const Icon(Icons.backspace_outlined, size: 18),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDigitButton(String digit) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.surfaceElevated,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => widget.onDigitPressed(digit),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

