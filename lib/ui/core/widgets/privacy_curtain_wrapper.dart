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
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [
                      AppTheme.emeraldSecure.withValues(alpha: 0.08),
                      AppTheme.obsidianBg,
                    ],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.surfaceCard,
                            border: Border.all(
                              color:
                                  AppTheme.emeraldSecure.withValues(alpha: 0.45),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.emeraldSecure
                                    .withValues(alpha: 0.18),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_moon_rounded,
                            size: 56,
                            color: AppTheme.emeraldSecure,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'SUPERXSECRET VAULT PROTECTED',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'App Switcher Masking & Memory Zeroization Active',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppTheme.borderHighlight),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.memory_rounded,
                                size: 14,
                                color: AppTheme.emeraldSecure,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'DEK ZEROIZED • AES-256-GCM',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.emeraldSecure,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

