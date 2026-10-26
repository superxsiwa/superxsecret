import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../view_models/auth_view_model.dart';

class LockScreenView extends StatefulWidget {
  const LockScreenView({
    super.key,
    required this.viewModel,
    required this.onVaultUnlocked,
  });

  final AuthViewModel viewModel;
  final VoidCallback onVaultUnlocked;

  @override
  State<LockScreenView> createState() => _LockScreenViewState();
}

class _LockScreenViewState extends State<LockScreenView> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _duressController = TextEditingController();
  bool _obscurePassword = true;
  bool _isConfiguringDualSlot = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.initializeSecurityCheck();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _duressController.dispose();
    super.dispose();
  }

  Future<void> _submitUnlock() async {
    final success = await widget.viewModel.unlockWithPassword(
      _passwordController.text,
    );
    if (success && mounted) {
      _passwordController.clear();
      widget.onVaultUnlocked();
    }
  }

  Future<void> _submitDualSlotSetup() async {
    final success = await widget.viewModel.setupDualSlotVault(
      mainPassword: _passwordController.text,
      secondaryPassword: _duressController.text,
    );
    if (success && mounted) {
      _passwordController.clear();
      _duressController.clear();
      widget.onVaultUnlocked();
    }
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final posture = widget.viewModel.securityPosture;
        final entropy = widget.viewModel.currentEntropyBits;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildZeroNetworkTrustHeader(posture.isCompromised),
                      const SizedBox(height: 28),
                      const Icon(
                        Icons.enhanced_encryption_rounded,
                        size: 56,
                        color: AppTheme.emeraldSecure,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'SuperXSecret',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '100% Offline • Zero-Knowledge • Dual-Vault',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (posture.isCompromised) _buildCompromisedDeviceBanner(),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _isConfiguringDualSlot
                                        ? 'Set Passwords'
                                        : 'Unlock Vault',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isConfiguringDualSlot =
                                            !_isConfiguringDualSlot;
                                      });
                                    },
                                    child: Text(
                                      _isConfiguringDualSlot
                                          ? 'Unlock'
                                          : 'Set Passwords',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                enableIMEPersonalizedLearning: false,
                                autocorrect: false,
                                enableSuggestions: false,
                                onChanged: widget
                                    .viewModel.updatePasswordInputForEntropy,
                                onSubmitted: (_) => _isConfiguringDualSlot
                                    ? null
                                    : _submitUnlock(),
                                decoration: InputDecoration(
                                  labelText: _isConfiguringDualSlot
                                      ? 'Main Password'
                                      : 'Password',
                                  prefixIcon: const Icon(Icons.key_rounded),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildEntropyBar(entropy),
                              if (_isConfiguringDualSlot) ...[
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _duressController,
                                  obscureText: _obscurePassword,
                                  enableIMEPersonalizedLearning: false,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Secondary Password',
                                    prefixIcon: Icon(Icons.shield_outlined),
                                    helperText:
                                        'Opens a separate Secondary Vault',
                                  ),
                                ),
                              ],
                              if (widget.viewModel.errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.crimsonAlert
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.crimsonAlert
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    widget.viewModel.errorMessage!,
                                    style: const TextStyle(
                                      color: AppTheme.crimsonAlert,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.emeraldSecure,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                ),
                                onPressed: widget.viewModel.isLoading
                                    ? null
                                    : (_isConfiguringDualSlot
                                        ? _submitDualSlotSetup
                                        : _submitUnlock),
                                icon: const Icon(Icons.lock_open_rounded),
                                label: Text(
                                  _isConfiguringDualSlot
                                      ? 'Save Passwords'
                                      : 'Unlock',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildQuickTestCredentialsCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildZeroNetworkTrustHeader(bool isCompromised) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.emeraldSecure.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.emeraldSecure.withValues(alpha: 0.35),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: AppTheme.emeraldSecure,
          ),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'VERIFIED 0 INTERNET PERMISSIONS • SQLCIPHER 4 + RUST FFI',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppTheme.emeraldSecure,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompromisedDeviceBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.amberWarning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.amberWarning),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.amberWarning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Security Alert: Root, Jailbreak, or Debugger detected on this device.',
              style: TextStyle(fontSize: 12, color: AppTheme.amberWarning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntropyBar(double bits) {
    final progress = (bits / 100.0).clamp(0.0, 1.0);
    final Color barColor;
    final String label;
    if (bits < 45) {
      barColor = AppTheme.crimsonAlert;
      label = 'Weak (${bits.toStringAsFixed(0)} bits)';
    } else if (bits < 75) {
      barColor = AppTheme.amberWarning;
      label = 'Good (${bits.toStringAsFixed(0)} bits)';
    } else {
      barColor = AppTheme.emeraldSecure;
      label = 'Strong (${bits.toStringAsFixed(0)} bits)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Strength:',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTestCredentialsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Demo:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.cyberCyan,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.verified_user_rounded, size: 16),
                label: const Text(
                  'Main Vault (SuperSecret#2026)',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: () {
                  _passwordController.text = 'SuperSecret#2026';
                  widget.viewModel
                      .updatePasswordInputForEntropy('SuperSecret#2026');
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.layers_outlined, size: 16),
                label: const Text(
                  'Secondary Vault (Decoy1234)',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: () {
                  _passwordController.text = 'Decoy1234';
                  widget.viewModel.updatePasswordInputForEntropy('Decoy1234');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}


