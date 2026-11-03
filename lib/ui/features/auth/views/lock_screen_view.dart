import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/zero_knowledge_disclaimer_sheet.dart';

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
  final TextEditingController _passwordHintController = TextEditingController();
  bool _obscurePassword = true;
  bool _isConfiguringDualSlot = false;
  bool _disclaimerCheckboxChecked = false;

  @override
  void initState() {
    super.initState();
    _isConfiguringDualSlot = !widget.viewModel.isVaultInitialized;
    _disclaimerCheckboxChecked = widget.viewModel.hasAcknowledgedDisclaimer;
    widget.viewModel.initializeSecurityCheck().then((_) {
      if (mounted && widget.viewModel.hasAcknowledgedDisclaimer) {
        setState(() => _disclaimerCheckboxChecked = true);
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _duressController.dispose();
    _passwordHintController.dispose();
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
    final strings = AppLanguageScope.stringsOf(context);
    if (!_disclaimerCheckboxChecked &&
        !widget.viewModel.hasAcknowledgedDisclaimer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.disclaimerCheckboxLabel),
          backgroundColor: AppTheme.crimsonAlert,
        ),
      );
      return;
    }

    final success = await widget.viewModel.setupDualSlotVault(
      mainPassword: _passwordController.text,
      secondaryPassword: _duressController.text,
      passwordHint: _passwordHintController.text,
    );
    if (success && mounted) {
      await widget.viewModel.acknowledgeDisclaimer();
      _passwordController.clear();
      _duressController.clear();
      _passwordHintController.clear();
      widget.onVaultUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLanguageScope.stringsOf(context);

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
                      Row(
                        children: [
                          Expanded(
                            child: _buildZeroNetworkTrustHeader(
                              posture.isCompromised,
                              strings,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: strings.theme,
                            icon: Icon(
                              AppTheme.isDarkMode(context)
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                              color: AppTheme.emeraldSecure,
                            ),
                            onPressed: () => showThemeSelectionDialog(
                              context,
                              AppThemeScope.of(context),
                            ),
                          ),
                          IconButton(
                            tooltip: strings.language,
                            icon: const Icon(
                              Icons.language_rounded,
                              color: AppTheme.emeraldSecure,
                            ),
                            onPressed: () => showLanguageSelectionDialog(
                              context,
                              AppLanguageScope.of(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.surfaceCardOf(context),
                            border: Border.all(
                              color: AppTheme.emeraldSecure
                                  .withValues(alpha: 0.45),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.emeraldSecure
                                    .withValues(alpha: 0.16),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.enhanced_encryption_rounded,
                            size: 36,
                            color: AppTheme.emeraldSecure,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'SuperXSecret',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.zeroKnowledgeSecurity,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (posture.isCompromised)
                        _buildCompromisedDeviceBanner(),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: AppTheme.borderHighlightOf(context),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isConfiguringDualSlot
                                              ? Icons.tune_rounded
                                              : Icons.lock_person_rounded,
                                          size: 18,
                                          color: AppTheme.emeraldSecure,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            _isConfiguringDualSlot
                                                ? strings.setupDualSlot
                                                : strings.unlockVault,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: AppTheme.textPrimaryOf(context),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!widget.viewModel.isVaultInitialized)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.emeraldSecure,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () =>
                                          ZeroKnowledgeDisclaimerSheet.show(
                                        context,
                                        onAcknowledged: () {
                                          setState(() =>
                                              _disclaimerCheckboxChecked = true);
                                          widget.viewModel
                                              .acknowledgeDisclaimer();
                                        },
                                      ),
                                      icon: const Icon(
                                        Icons.shield_outlined,
                                        size: 15,
                                      ),
                                      label: Text(
                                        strings.disclaimerViewNotice,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  else
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.cyberCyan,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isConfiguringDualSlot =
                                              !_isConfiguringDualSlot;
                                        });
                                      },
                                      icon: Icon(
                                        _isConfiguringDualSlot
                                            ? Icons.login_rounded
                                            : Icons.layers_rounded,
                                        size: 15,
                                      ),
                                      label: Text(
                                        _isConfiguringDualSlot
                                            ? strings.unlock
                                            : strings.setupDualSlot,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
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
                                      ? strings.masterPasswordLabel
                                      : strings.masterPasswordHint,
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
                              _buildEntropyBar(entropy, strings),
                              if (_isConfiguringDualSlot) ...[
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _duressController,
                                  obscureText: _obscurePassword,
                                  enableIMEPersonalizedLearning: false,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: InputDecoration(
                                    labelText: strings.secondaryPasswordLabel,
                                    prefixIcon:
                                        const Icon(Icons.shield_outlined),
                                    helperText:
                                        strings.secondaryPasswordHelper,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _passwordHintController,
                                  enableIMEPersonalizedLearning: false,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: InputDecoration(
                                    labelText:
                                        strings.passwordHintOptional,
                                    prefixIcon:
                                        const Icon(Icons.lightbulb_outline),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Material(
                                  color: AppTheme.isDarkMode(context)
                                      ? const Color(0xFF111722)
                                      : const Color(0xFFF1F5F9),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: _disclaimerCheckboxChecked
                                          ? AppTheme.emeraldSecure
                                              .withValues(alpha: 0.5)
                                          : AppTheme.borderHighlightOf(context),
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                      value: _disclaimerCheckboxChecked,
                                      onChanged: (val) {
                                        setState(() =>
                                            _disclaimerCheckboxChecked =
                                                val ?? false);
                                        if (val == true) {
                                          widget.viewModel
                                              .acknowledgeDisclaimer();
                                        }
                                      },
                                      activeColor: AppTheme.emeraldSecure,
                                      checkColor: Colors.black,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                      title: Text(
                                        strings.disclaimerCheckboxLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimaryOf(context),
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              if (widget.viewModel.errorMessage != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.crimsonAlert
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppTheme.crimsonAlert
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        size: 18,
                                        color: AppTheme.crimsonAlert,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.viewModel.errorMessage!,
                                          style: const TextStyle(
                                            color: AppTheme.crimsonAlert,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.emeraldSecure,
                                  foregroundColor: const Color(0xFF04130D),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: widget.viewModel.isLoading
                                    ? null
                                    : (_isConfiguringDualSlot
                                        ? _submitDualSlotSetup
                                        : _submitUnlock),
                                icon: const Icon(Icons.lock_open_rounded),
                                label: Text(
                                  widget.viewModel.isLoading
                                      ? strings.unlocking
                                      : (_isConfiguringDualSlot
                                          ? strings.save
                                          : strings.unlock),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildZeroNetworkTrustHeader(
    bool isCompromised,
    AppStrings strings,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.emeraldSecure.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.emeraldSecure.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: AppTheme.emeraldSecure,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              strings.verifiedOffline,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
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

  Widget _buildEntropyBar(double bits, AppStrings strings) {
    final progress = (bits / 100.0).clamp(0.0, 1.0);
    final Color barColor;
    final String label;
    if (bits < 45) {
      barColor = AppTheme.crimsonAlert;
      label = '${strings.entropyWeak} (${bits.toStringAsFixed(0)} bits)';
    } else if (bits < 75) {
      barColor = AppTheme.amberWarning;
      label = '${strings.entropyGood} (${bits.toStringAsFixed(0)} bits)';
    } else {
      barColor = AppTheme.emeraldSecure;
      label = '${strings.entropyStrong} (${bits.toStringAsFixed(0)} bits)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${strings.entropyLabel}:',
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
}
