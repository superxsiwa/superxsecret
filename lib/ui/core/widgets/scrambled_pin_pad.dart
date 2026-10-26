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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.emeraldSecure.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppTheme.emeraldSecure.withValues(alpha: 0.35),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shuffle_rounded,
                size: 14,
                color: AppTheme.emeraldSecure,
              ),
              SizedBox(width: 6),
              Text(
                'CSPRNG Auto-Scrambled Keypad • Anti-Spyware',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.emeraldSecure,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.15,
          children: [
            for (var i = 0; i < 9; i++)
              _buildDigitButton(_digits[i].toString()),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppTheme.obsidianDeep,
                foregroundColor: AppTheme.cyberCyan,
                side: BorderSide(
                  color: AppTheme.cyberCyan.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _scrambleDigits();
                widget.onReshuffle();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Shuffle', style: TextStyle(fontSize: 11.5)),
            ),
            _buildDigitButton(_digits[9].toString()),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppTheme.obsidianDeep,
                foregroundColor: AppTheme.amberWarning,
                side: BorderSide(
                  color: AppTheme.amberWarning.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.borderHighlight),
        ),
      ),
      onPressed: () => widget.onDigitPressed(digit),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

