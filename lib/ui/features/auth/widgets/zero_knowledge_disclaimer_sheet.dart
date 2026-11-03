import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

/// Modal bottom sheet / dialog educating users on SuperXSecret's
/// 100% Offline Zero-Knowledge security architecture before initial vault setup.
class ZeroKnowledgeDisclaimerSheet extends StatefulWidget {
  const ZeroKnowledgeDisclaimerSheet({
    super.key,
    required this.onAcknowledged,
    this.initialChecked = false,
  });

  final VoidCallback onAcknowledged;
  final bool initialChecked;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onAcknowledged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ZeroKnowledgeDisclaimerSheet(
        onAcknowledged: () {
          Navigator.of(ctx).pop();
          onAcknowledged();
        },
      ),
    );
  }

  @override
  State<ZeroKnowledgeDisclaimerSheet> createState() =>
      _ZeroKnowledgeDisclaimerSheetState();
}

class _ZeroKnowledgeDisclaimerSheetState
    extends State<ZeroKnowledgeDisclaimerSheet> {
  late bool _acknowledged;

  @override
  void initState() {
    super.initState();
    _acknowledged = widget.initialChecked;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLanguageScope.stringsOf(context);
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCardOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: AppTheme.emeraldSecure.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMutedOf(context).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.emeraldSecure.withValues(alpha: 0.14),
                      border: Border.all(
                        color: AppTheme.emeraldSecure.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.emeraldSecure,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.firstRunDisclaimerTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          strings.firstRunDisclaimerSubtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.emeraldSecure,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildPillarTile(
                context,
                icon: Icons.wifi_off_rounded,
                iconColor: AppTheme.emeraldSecure,
                title: strings.disclaimerZeroCloudTitle,
                desc: strings.disclaimerZeroCloudDesc,
              ),
              const SizedBox(height: 10),
              _buildPillarTile(
                context,
                icon: Icons.key_off_rounded,
                iconColor: AppTheme.crimsonAlert,
                title: strings.disclaimerNoRecoveryTitle,
                desc: strings.disclaimerNoRecoveryDesc,
              ),
              const SizedBox(height: 10),
              _buildPillarTile(
                context,
                icon: Icons.save_rounded,
                iconColor: AppTheme.cyberCyan,
                title: strings.disclaimerBackupRequiredTitle,
                desc: strings.disclaimerBackupRequiredDesc,
              ),
              const SizedBox(height: 10),
              _buildPillarTile(
                context,
                icon: Icons.masks_rounded,
                iconColor: Colors.deepPurpleAccent,
                title: strings.disclaimerDualSlotTitle,
                desc: strings.disclaimerDualSlotDesc,
              ),
              const SizedBox(height: 18),
              Material(
                color: isDark
                    ? const Color(0xFF131822)
                    : const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _acknowledged
                        ? AppTheme.emeraldSecure.withValues(alpha: 0.5)
                        : AppTheme.borderHighlightOf(context),
                  ),
                ),
                child: CheckboxListTile(
                  value: _acknowledged,
                  onChanged: (val) =>
                      setState(() => _acknowledged = val ?? false),
                  activeColor: AppTheme.emeraldSecure,
                  checkColor: Colors.black,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  title: Text(
                    strings.disclaimerCheckboxLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldSecure,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppTheme.emeraldSecure
                      .withValues(alpha: 0.25),
                  disabledForegroundColor: AppTheme.textMutedOf(context),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _acknowledged ? widget.onAcknowledged : null,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  strings.disclaimerProceedBtn,
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
    );
  }

  Widget _buildPillarTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F141E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderHighlightOf(context).withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.14),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondaryOf(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
