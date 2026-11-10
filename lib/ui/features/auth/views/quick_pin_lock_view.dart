import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/controllers/auto_lock_controller.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/scrambled_pin_pad.dart';

/// Full-screen Quick PIN Unlock View shown when the vault is soft-locked
/// due to inactivity or temporary screen-off.
class QuickPinLockView extends StatefulWidget {
  const QuickPinLockView({
    super.key,
    required this.autoLockController,
    required this.onHardLogoutRequested,
  });

  final AutoLockController autoLockController;
  final VoidCallback onHardLogoutRequested;

  @override
  State<QuickPinLockView> createState() => _QuickPinLockViewState();
}

class _QuickPinLockViewState extends State<QuickPinLockView> {
  String _enteredPin = '';
  bool _obscurePin = true;
  bool _isVerifying = false;
  String? _errorMessage;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdownCheck();
  }

  void _startCountdownCheck() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      widget.autoLockController.checkSoftLockExpiry(
        onHardLogout: widget.onHardLogoutRequested,
      );
      setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  int _calculateRemainingSeconds() {
    final softLockedTime = widget.autoLockController.softLockedTime;
    final timeoutMinutes = widget.autoLockController.screenOffTimeoutMinutes > 0
        ? widget.autoLockController.screenOffTimeoutMinutes
        : widget.autoLockController.inactivityTimeoutMinutes;
    if (softLockedTime == null || timeoutMinutes <= 0) return 0;
    final totalSeconds = timeoutMinutes * 60;
    final elapsed = DateTime.now().difference(softLockedTime).inSeconds;
    final remaining = totalSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _handleDigitPressed(String digit) async {
    if (_isVerifying || _enteredPin.length >= 12) return;
    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });

    // Auto-verify if minimum PIN length (at least 4 digits) is reached
    // or allow user to press unlock button
  }

  void _handleBackspace() {
    if (_isVerifying || _enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  void _handleReshuffle() {
    if (_isVerifying) return;
    setState(() {
      _enteredPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _submitPin() async {
    if (_isVerifying || _enteredPin.isEmpty) return;
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final success = await widget.autoLockController.verifyAndUnlockWithPin(
      _enteredPin,
      onHardLogout: widget.onHardLogoutRequested,
    );

    if (!mounted) return;

    if (!success) {
      final attempts = widget.autoLockController.pinAttemptsRemaining;
      final isThai = AppLanguageScope.of(context).isThai(context);
      setState(() {
        _isVerifying = false;
        _enteredPin = '';
        _errorMessage = isThai
            ? 'รหัส PIN ไม่ถูกต้อง (เหลือโอกาสอีก $attempts ครั้ง)'
            : 'Incorrect PIN ($attempts attempts remaining)';
      });
    } else {
      setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLanguageScope.stringsOf(context);
    final isThai = AppLanguageScope.of(context).isThai(context);
    final remainingSeconds = _calculateRemainingSeconds();
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final formattedTime =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppTheme.obsidianBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Shield / Lock Icon
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surfaceCard,
                    border: Border.all(
                      color: AppTheme.emeraldSecure.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.emeraldSecure.withValues(alpha: 0.15),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.dialpad_rounded,
                    size: 40,
                    color: AppTheme.emeraldSecure,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isThai ? 'ปลดล็อกด่วนด้วย PIN' : 'Quick PIN Unlock',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isThai
                      ? 'กดรหัส PIN เพื่อกลับเข้าใช้งาน Vault'
                      : 'Enter your PIN on the CSPRNG keypad to resume',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Auto-Logout Countdown indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.amberWarning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.amberWarning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 15,
                        color: AppTheme.amberWarning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isThai
                            ? 'ตัด Logout อัตโนมัติใน: $formattedTime'
                            : 'Auto-logout in: $formattedTime',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.amberWarning,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Display of entered digits
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevatedOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _errorMessage != null
                          ? AppTheme.crimsonAlert
                          : AppTheme.borderHighlightOf(context),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _enteredPin.isEmpty
                              ? strings.tapDigitsBelow
                              : (_obscurePin
                                  ? '• ' * _enteredPin.length
                                  : _enteredPin),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: _enteredPin.isEmpty ? 13 : 24,
                            letterSpacing: _enteredPin.isEmpty ? 0 : 6,
                            fontWeight: FontWeight.w800,
                            color: _errorMessage != null
                                ? AppTheme.crimsonAlert
                                : AppTheme.emeraldSecure,
                            fontFamily:
                                _enteredPin.isEmpty ? null : 'monospace',
                          ),
                        ),
                      ),
                      if (_enteredPin.isNotEmpty)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            _obscurePin
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                          onPressed: () =>
                              setState(() => _obscurePin = !_obscurePin),
                        ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.crimsonAlert,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 16),

                // Scrambled Numeric Keypad
                ScrambledPinPad(
                  onDigitPressed: _handleDigitPressed,
                  onBackspace: _handleBackspace,
                  onReshuffle: _handleReshuffle,
                ),

                const SizedBox(height: 18),

                // Submit PIN Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.emeraldSecure,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _enteredPin.isEmpty || _isVerifying
                        ? null
                        : _submitPin,
                    icon: _isVerifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.lock_open_rounded, size: 20),
                    label: Text(
                      isThai ? 'ปลดล็อก' : 'Unlock',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Hard Logout Button (immediately zeroize & wipe)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondaryOf(context),
                  ),
                  onPressed: widget.onHardLogoutRequested,
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: Text(
                    isThai
                        ? 'ออกจากระบบทันที (Master Password)'
                        : 'Logout with Master Password',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
