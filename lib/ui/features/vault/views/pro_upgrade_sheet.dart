import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/controllers/license_controller.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

/// Modal BottomSheet presenting Pro Tier benefits and offline License Key activation.
class ProUpgradeSheet extends StatefulWidget {
  const ProUpgradeSheet({
    super.key,
    required this.licenseController,
    this.currentItemCount = 0,
  });

  final LicenseController licenseController;
  final int currentItemCount;

  static Future<void> show(
    BuildContext context, {
    required LicenseController licenseController,
    int currentItemCount = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ProUpgradeSheet(
        licenseController: licenseController,
        currentItemCount: currentItemCount,
      ),
    );
  }

  @override
  State<ProUpgradeSheet> createState() => _ProUpgradeSheetState();
}

class _ProUpgradeSheetState extends State<ProUpgradeSheet> {
  final TextEditingController _keyController = TextEditingController();
  bool _isActivating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _submitActivation() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      _isActivating = true;
      _errorMessage = null;
    });

    final success = await widget.licenseController.activateLicense(key);

    if (!mounted) return;

    if (success) {
      final isThai = AppLanguageScope.of(context).isThai(context);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isThai
                ? 'เปิดใช้งาน SuperXSecret Pro สำเร็จแล้ว!'
                : 'SuperXSecret Pro activated successfully!',
          ),
          backgroundColor: AppTheme.emeraldSecure,
        ),
      );
    } else {
      final isThai = AppLanguageScope.of(context).isThai(context);
      setState(() {
        _isActivating = false;
        _errorMessage = isThai
            ? 'รหัส License ไม่ถูกต้อง หรือรูปแบบไม่สมบูรณ์'
            : 'Invalid or malformed License Key.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = AppLanguageScope.of(context).isThai(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isPro = widget.licenseController.isPro;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.emeraldSecure, AppTheme.cyberCyan],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 22,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isPro
                          ? (isThai
                              ? 'สถานะ SuperXSecret Pro'
                              : 'SuperXSecret Pro Active')
                          : (isThai
                              ? 'ปลดล็อก SuperXSecret Pro'
                              : 'Upgrade to SuperXSecret Pro'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (isPro) ...[
              // Active Pro Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldSecure.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.emeraldSecure.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: AppTheme.emeraldSecure,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isThai
                              ? 'ใบอนุญาต Pro สมบูรณ์แบบ (Lifetime)'
                              : 'Pro License Verified (Lifetime)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.emeraldSecure,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${isThai ? "เจ้าของสิทธิ์:" : "Licensed to:"} ${widget.licenseController.licenseOwner ?? "User"}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isThai ? "แพ็กเกจ:" : "Plan:"} ${widget.licenseController.licensePlan?.toUpperCase() ?? "LIFETIME"} • 100% Offline Verified',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.crimsonAlert,
                  side: BorderSide(
                    color: AppTheme.crimsonAlert.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  await widget.licenseController.deactivateLicense();
                  if (context.mounted) {
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.link_off_rounded, size: 16),
                label: Text(
                  isThai ? 'ยกเลิกการเปิดใช้งานในเครื่องนี้' : 'Deactivate License',
                ),
              ),
            ] else ...[
              // Free Tier status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevatedOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.borderSubtleOf(context),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isThai ? 'การใช้งาน Free Tier ปัจจุบัน:' : 'Current Free Usage:',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                    Text(
                      '${widget.currentItemCount} / ${LicenseController.maxFreeItems} ${isThai ? "รายการ" : "items"}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: widget.currentItemCount >=
                                LicenseController.maxFreeItems
                            ? AppTheme.amberWarning
                            : AppTheme.cyberCyan,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Pro Features Highlights
              _buildFeatureRow(
                context,
                icon: Icons.all_inclusive_rounded,
                title: isThai
                    ? 'บันทึกข้อมูลไม่จำกัดจำนวน (Unlimited Items)'
                    : 'Unlimited Vault Records',
                desc: isThai
                    ? 'บันทึกรหัสผ่าน บัตรเครดิต และโน้ตลับได้ไม่จำกัด'
                    : 'No limits on secrets, topics, and categories',
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                context,
                icon: Icons.shield_moon_rounded,
                title: isThai
                    ? 'ระบบคลังคู่ ป้องกันการถูกบังคับ (Dual-Vault)'
                    : 'Plausible Deniability Dual-Vault',
                desc: isThai
                    ? 'แยกคลังข้อมูลจริง และคลังลวงอย่างสมบูรณ์แบบ'
                    : 'Full support for Secondary/Decoy duress protection',
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                context,
                icon: Icons.vpn_key_rounded,
                title: isThai
                    ? 'เข้ารหัสขั้นสูง 5 อัลกอริทึม (Multi-Cipher)'
                    : '5 Military-Grade Encryption Suites',
                desc: isThai
                    ? 'AES-256-GCM, ChaCha20, XChaCha20, CBC+HMAC, Dual-Layer'
                    : 'High-entropy zero-knowledge cryptographic algorithms',
              ),
              const SizedBox(height: 18),

              // License Key Input Field
              Text(
                isThai
                    ? 'มีรหัส License Key หรือรหัสสั่งซื้อแล้ว?'
                    : 'Already have a License Key?',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.cyberCyan,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _keyController,
                maxLines: 2,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'SXS-eyJh...',
                  hintStyle: TextStyle(
                    color: AppTheme.textMutedOf(context),
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(Icons.key_rounded, size: 18),
                  suffixIcon: IconButton(
                    tooltip: isThai ? 'วางจาก Clipboard' : 'Paste from clipboard',
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _keyController.text = data!.text!.trim();
                      }
                    },
                  ),
                  isDense: true,
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.crimsonAlert,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Activate Button
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emeraldSecure,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isActivating ? null : _submitActivation,
                icon: _isActivating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  isThai ? 'เปิดใช้งาน License (Offline Verify)' : 'Activate License',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.emeraldSecure.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.emeraldSecure),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
