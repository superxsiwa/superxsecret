import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// App Switcher Privacy Curtain & Background Auto-Lock Wrapper.
///
/// Immediately covers the entire viewport with a Zero-Knowledge Privacy Shield
/// whenever the app transitions to `inactive`, `hidden`, or `paused`, and
/// triggers `onBackgroundAutoLock` to zeroize the active DEK in RAM.
class PrivacyCurtainWrapper extends StatefulWidget {
  const PrivacyCurtainWrapper({
    super.key,
    required this.child,
    required this.onBackgroundAutoLock,
  });

  final Widget child;
  final VoidCallback onBackgroundAutoLock;

  @override
  State<PrivacyCurtainWrapper> createState() => _PrivacyCurtainWrapperState();
}

class _PrivacyCurtainWrapperState extends State<PrivacyCurtainWrapper>
    with WidgetsBindingObserver {
  bool _isMasked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        setState(() => _isMasked = true);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        setState(() => _isMasked = true);
        widget.onBackgroundAutoLock();
      case AppLifecycleState.resumed:
        setState(() => _isMasked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isMasked)
          Positioned.fill(
            child: Material(
              color: AppTheme.obsidianBg,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.emeraldSecure.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppTheme.emeraldSecure.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_moon_rounded,
                        size: 56,
                        color: AppTheme.emeraldSecure,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SUPERXSECRET VAULT PROTECTED',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'App Switcher Masking & Memory Zeroization Active',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

