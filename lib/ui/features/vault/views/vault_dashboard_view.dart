import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../domain/models/vault_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/scrambled_pin_pad.dart';
import '../view_models/vault_view_model.dart';

class VaultDashboardView extends StatefulWidget {
  const VaultDashboardView({
    super.key,
    required this.viewModel,
    required this.onLockRequested,
  });

  final VaultViewModel viewModel;
  final VoidCallback onLockRequested;

  @override
  State<VaultDashboardView> createState() => _VaultDashboardViewState();
}

class _VaultDashboardViewState extends State<VaultDashboardView> {
  String? _openingItemUuid;

  @override
  void initState() {
    super.initState();
    widget.viewModel.loadVaultSummaries();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final items = widget.viewModel.filteredItems;
        final clipboardSecs = widget.viewModel.clipboardSecondsRemaining;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_rounded,
                  color: AppTheme.emeraldSecure,
                  size: 20,
                ),
                SizedBox(width: 6),
                Text(
                  'SuperXSecret',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Import (.sxsi)',
                icon: const Icon(Icons.file_download_outlined),
                onPressed: () => _showImportSxsiDialog(context),
              ),
              IconButton(
                tooltip: 'Backup (.sxs)',
                icon: const Icon(Icons.import_export_rounded),
                onPressed: () => _showSxsBackupDialog(context),
              ),
              IconButton(
                tooltip: 'PIN',
                icon: const Icon(Icons.dialpad_rounded),
                onPressed: () => _showScrambledKeypadDemoSheet(context),
              ),
              IconButton(
                tooltip: 'Lock',
                icon: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppTheme.amberWarning,
                ),
                onPressed: () {
                  widget.viewModel.hideAndZeroizeRevealedSecret();
                  widget.onLockRequested();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              if (clipboardSecs > 0)
                _buildClipboardAutoWipeBanner(clipboardSecs),
              if (widget.viewModel.activeRevealedSecret != null)
                _buildActiveJitRevealCard(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        enableIMEPersonalizedLearning: false,
                        autocorrect: false,
                        enableSuggestions: false,
                        onChanged: widget.viewModel.setSearchQuery,
                        decoration: const InputDecoration(
                          hintText: 'Search topic...',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.emeraldSecure,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => _showNewTopicDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'New',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text('No topics found'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final summary = items[index];
                          return _buildSummaryCard(context, summary);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClipboardAutoWipeBanner(int secondsLeft) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.amberWarning.withValues(alpha: 0.16),
      child: Row(
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 18,
            color: AppTheme.amberWarning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Copied "${widget.viewModel.copiedFieldLabel}" (auto-wipe in ${secondsLeft}s)',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.amberWarning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.viewModel.clearClipboardImmediately,
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, VaultTopicSummary item) {
    final isRevealed =
        widget.viewModel.activeRevealedSecret?.itemUuid == item.itemUuid;
    final isOpening = _openingItemUuid == item.itemUuid;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isRevealed
              ? AppTheme.emeraldSecure.withValues(alpha: 0.7)
              : AppTheme.borderSubtle,
          width: isRevealed ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldSecure.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.emeraldSecure.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.vpn_key_rounded,
                    color: AppTheme.emeraldSecure,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.topic,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (item.hasExtraLock) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: AppTheme.emeraldSecure,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '•••••••••••• • AES-256-GCM',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Options',
                  onSelected: (action) {
                    if (action == 'delete') {
                      _confirmDeleteItem(item);
                    } else {
                      _manageItemLock(item, action);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!item.hasExtraLock)
                      const PopupMenuItem(
                        value: 'add',
                        child: Text('Add Extra Lock'),
                      )
                    else ...[
                      const PopupMenuItem(
                        value: 'change',
                        child: Text('Change Item Password'),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove Extra Lock'),
                      ),
                    ],
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppTheme.crimsonAlert,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete Item',
                            style: TextStyle(color: AppTheme.crimsonAlert),
                          ),
                        ],
                      ),
                    ),
                  ],
                  icon: const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: AppTheme.emeraldSecure,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppTheme.crimsonAlert.withValues(alpha: 0.8),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDeleteItem(item),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _shareItem(item),
                  icon: const Icon(Icons.ios_share_rounded, size: 15),
                  label: const Text('Share', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        AppTheme.emeraldSecure.withValues(alpha: 0.16),
                    foregroundColor: AppTheme.emeraldSecure,
                  ),
                  onPressed:
                      _openingItemUuid == null ? () => _viewItem(item) : null,
                  icon: isOpening
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.visibility_rounded, size: 16),
                  label: Text(
                    isOpening ? 'Opening...' : 'View',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveJitRevealCard(BuildContext context) {
    final secret = widget.viewModel.activeRevealedSecret!;
    final secsLeft = widget.viewModel.revealSecondsRemaining;
    final progress = (secsLeft / 15.0).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.emeraldSecure, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emeraldSecure.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lock_clock_rounded,
                    color: AppTheme.emeraldSecure,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${secret.topic} • Auto-hide in ${secsLeft}s',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.emeraldSecure,
                    ),
                  ),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: widget.viewModel.hideAndZeroizeRevealedSecret,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.emeraldSecure,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildSecretRow('Secret Text', secret.secretText),
        ],
      ),
    );
  }

  Widget _buildSecretRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => widget.viewModel.copySecretWithAutoClear(
              label: label,
              secretValue: value,
            ),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showScrambledKeypadDemoSheet(BuildContext context) {
    var enteredPin = '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scrambled PIN Pad',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    enteredPin.isEmpty
                        ? 'Tap digits below'
                        : '• ' * enteredPin.length,
                    style: const TextStyle(
                      fontSize: 22,
                      letterSpacing: 4,
                      color: AppTheme.emeraldSecure,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ScrambledPinPad(
                    onDigitPressed: (d) {
                      if (enteredPin.length < 6) {
                        setModalState(() => enteredPin += d);
                      }
                    },
                    onBackspace: () {
                      if (enteredPin.isNotEmpty) {
                        setModalState(
                          () => enteredPin = enteredPin.substring(
                            0,
                            enteredPin.length - 1,
                          ),
                        );
                      }
                    },
                    onReshuffle: () => setModalState(() => enteredPin = ''),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showNewTopicDialog(BuildContext context) async {
    final topicCtrl = TextEditingController();
    final secretCtrl = TextEditingController();
    final hintCtrl = TextEditingController();
    final itemPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    var hasExtraLock = false;
    var passwordEntropyBits = 0.0;
    String? errorMsg;
    var isEncoding = false;
    var encodingPercent = 0.0;
    var countdownSeconds = 1.0;
    _EncodingProgressTracker? tracker;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New Topic'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: topicCtrl,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Topic',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: secretCtrl,
                      maxLines: 3,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Secret Text',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: hasExtraLock,
                      title: const Text('🔒 Extra Lock (Separate Password)'),
                      subtitle: const Text(
                        'Require a separate password to reveal this item.',
                      ),
                      onChanged: (value) => setDialogState(() {
                        hasExtraLock = value;
                        errorMsg = null;
                      }),
                    ),
                    if (hasExtraLock) ...[
                      TextField(
                        controller: itemPasswordCtrl,
                        obscureText: true,
                        enableIMEPersonalizedLearning: false,
                        autocorrect: false,
                        enableSuggestions: false,
                        onChanged: (value) => setDialogState(() {
                          passwordEntropyBits =
                              widget.viewModel.estimatePasswordEntropyBits(
                            value,
                          );
                        }),
                        decoration: const InputDecoration(
                          labelText: 'Item Password',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: confirmPasswordCtrl,
                        obscureText: true,
                        enableIMEPersonalizedLearning: false,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildItemPasswordStrength(passwordEntropyBits),
                      const SizedBox(height: 8),
                      const Text(
                        'If you forget this password, the item cannot be recovered.',
                        style: TextStyle(
                          color: AppTheme.amberWarning,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: hintCtrl,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: hasExtraLock
                            ? 'Password Hint'
                            : 'Password Hint (Optional)',
                      ),
                    ),
                    if (isEncoding) ...[
                      const SizedBox(height: 12),
                      _buildEncodingProgressWidget(
                        percent: encodingPercent,
                        countdownSeconds: countdownSeconds,
                      ),
                    ],
                    if (errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.crimsonAlert,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isEncoding ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isEncoding
                      ? null
                      : () async {
                          if (topicCtrl.text.trim().isEmpty ||
                              secretCtrl.text.trim().isEmpty) {
                            setDialogState(() {
                              errorMsg = 'Topic and Secret Text are required.';
                            });
                            return;
                          }
                          if (hasExtraLock &&
                              (itemPasswordCtrl.text.length < 6 ||
                                  itemPasswordCtrl.text !=
                                      confirmPasswordCtrl.text ||
                                  hintCtrl.text.trim().isEmpty)) {
                            setDialogState(() {
                              errorMsg = itemPasswordCtrl.text.length < 6
                                  ? 'Item Password must be at least 6 characters.'
                                  : itemPasswordCtrl.text !=
                                          confirmPasswordCtrl.text
                                      ? 'Item passwords do not match.'
                                      : 'Password Hint is required for Extra Lock.';
                            });
                            return;
                          }
                          setDialogState(() {
                            isEncoding = true;
                            errorMsg = null;
                            encodingPercent = 0.0;
                            countdownSeconds = hasExtraLock ? 1.6 : 1.0;
                          });

                          tracker = _EncodingProgressTracker(
                            estimatedDuration: Duration(
                              milliseconds: hasExtraLock ? 1600 : 1000,
                            ),
                            onUpdate: (pct, remaining) {
                              setDialogState(() {
                                encodingPercent = pct;
                                countdownSeconds = remaining;
                              });
                            },
                          )..start();

                          try {
                            await widget.viewModel.createTopic(
                              topic: topicCtrl.text,
                              secretText: secretCtrl.text,
                              hasExtraLock: hasExtraLock,
                              itemPassword:
                                  hasExtraLock ? itemPasswordCtrl.text : null,
                              passwordHint: hintCtrl.text,
                            );
                            tracker?.complete();
                            await Future<void>.delayed(
                              const Duration(milliseconds: 150),
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          } catch (e) {
                            tracker?.dispose();
                            setDialogState(() {
                              isEncoding = false;
                              errorMsg = e.toString();
                            });
                          }
                        },
                  child: isEncoding
                      ? Text('Encoding ${(encodingPercent * 100).toInt()}%...')
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    topicCtrl.dispose();
    secretCtrl.dispose();
    hintCtrl.dispose();
    itemPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
  }

  Widget _buildItemPasswordStrength(double bits) {
    final strength = (bits / 100).clamp(0.0, 1.0);
    final color = bits < 45
        ? AppTheme.crimsonAlert
        : bits < 75
            ? AppTheme.amberWarning
            : AppTheme.emeraldSecure;
    final label = bits < 45
        ? 'Weak'
        : bits < 75
            ? 'Good'
            : 'Strong';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Password strength: $label (${bits.toStringAsFixed(0)} bits)',
          style: TextStyle(color: color, fontSize: 12),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: strength,
          minHeight: 4,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildEncodingProgressWidget({
    required double percent,
    required double countdownSeconds,
    String title = 'Encoding data...',
  }) {
    final pctInt = (percent * 100).toInt().clamp(0, 100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.emeraldSecure.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.emeraldSecure.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.emeraldSecure,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$title $pctInt%',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.emeraldSecure,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldSecure.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${countdownSeconds.toStringAsFixed(1)}s left',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.emeraldSecure,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.emeraldSecure,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewItem(
    VaultTopicSummary item,
  ) async {
    if (_openingItemUuid != null) return;
    setState(() => _openingItemUuid = item.itemUuid);
    try {
      await widget.viewModel.revealSecretJit(item.itemUuid);
    } on ItemLockedException {
      if (!mounted) return;
      await _showEnterItemPasswordDialog(
        context,
        item,
        onUnlocked: (itemPassword) => widget.viewModel.revealSecretJit(
          item.itemUuid,
          itemPassword: itemPassword,
        ),
      );
    } on VaultItemPasswordException {
      if (!mounted) return;
      await _showEnterPasswordDialog(
        context,
        item,
        onUnlocked: (password) => _revealWithVaultPassword(item, password),
      );
    } catch (error) {
      if (mounted) _showActionError(context, error);
    } finally {
      if (mounted) setState(() => _openingItemUuid = null);
    }
  }

  Future<void> _revealWithVaultPassword(
    VaultTopicSummary item,
    String? vaultPassword,
  ) async {
    try {
      await widget.viewModel.revealSecretJit(
        item.itemUuid,
        overridePassword: vaultPassword,
      );
    } on ItemLockedException {
      if (!mounted) return;
      await _showEnterItemPasswordDialog(
        context,
        item,
        overridePassword: vaultPassword,
        onUnlocked: (itemPassword) => widget.viewModel.revealSecretJit(
          item.itemUuid,
          overridePassword: vaultPassword,
          itemPassword: itemPassword,
        ),
      );
    }
  }

  Future<void> _shareItem(
    VaultTopicSummary item,
  ) async {
    try {
      await widget.viewModel.verifyVaultPassword(item.itemUuid);
      if (item.hasExtraLock) {
        throw ItemLockedException(item.passwordHint);
      }
      if (mounted) {
        _showShareSxsiDialog(context, item);
      }
    } on ItemLockedException {
      if (!mounted) return;
      await _showEnterItemPasswordDialog(
        context,
        item,
        onUnlocked: (itemPassword) async {
          if (mounted) {
            _showShareSxsiDialog(
              context,
              item,
              itemPassword: itemPassword,
            );
          }
        },
      );
    } on VaultItemPasswordException {
      if (!mounted) return;
      await _showEnterPasswordDialog(
        context,
        item,
        onUnlocked: (password) => _shareWithVaultPassword(item, password),
      );
    } catch (error) {
      if (mounted) _showActionError(context, error);
    }
  }

  Future<void> _shareWithVaultPassword(
    VaultTopicSummary item,
    String? vaultPassword,
  ) async {
    try {
      await widget.viewModel.verifyVaultPassword(
        item.itemUuid,
        overridePassword: vaultPassword,
      );
      if (item.hasExtraLock) {
        throw ItemLockedException(item.passwordHint);
      }
      if (mounted) {
        _showShareSxsiDialog(
          context,
          item,
          overridePassword: vaultPassword,
        );
      }
    } on ItemLockedException {
      if (!mounted) return;
      await _showEnterItemPasswordDialog(
        context,
        item,
        overridePassword: vaultPassword,
        onUnlocked: (itemPassword) async {
          if (mounted) {
            _showShareSxsiDialog(
              context,
              item,
              itemPassword: itemPassword,
              overridePassword: vaultPassword,
            );
          }
        },
      );
    }
  }

  Future<void> _manageItemLock(
    VaultTopicSummary item,
    String action,
  ) async {
    if (action == 'add') {
      await _showItemLockSetupDialog(item);
      return;
    }
    await _showEnterItemPasswordDialog(
      context,
      item,
      onUnlocked: (currentPassword) async {
        try {
          if (action == 'change') {
            await _showItemLockSetupDialog(
              item,
              currentItemPassword: currentPassword,
            );
          } else {
            await widget.viewModel.removeItemExtraLock(
              itemUuid: item.itemUuid,
              itemPassword: currentPassword,
            );
          }
        } catch (error) {
          if (mounted) _showActionError(context, error);
        }
      },
    );
  }

  Future<void> _confirmDeleteItem(
    VaultTopicSummary item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
          'Are you sure you want to permanently delete "${item.topic}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.crimsonAlert,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.viewModel.deleteTopic(item.itemUuid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${item.topic}"'),
              backgroundColor: AppTheme.surfaceCard,
            ),
          );
        }
      } catch (e) {
        if (mounted) _showActionError(context, e);
      }
    }
  }

  Future<void> _showItemLockSetupDialog(
    VaultTopicSummary item, {
    String? currentItemPassword,
  }) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final hintCtrl = TextEditingController(text: item.passwordHint);
    String? errorMessage;
    var isEncoding = false;
    var encodingPercent = 0.0;
    var countdownSeconds = 1.5;
    _EncodingProgressTracker? tracker;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            currentItemPassword == null
                ? 'Add Extra Lock'
                : 'Change Item Password',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(labelText: 'Item Password'),
              ),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setDialogState(() {}),
                decoration:
                    const InputDecoration(labelText: 'Confirm Password'),
              ),
              const SizedBox(height: 8),
              _buildItemPasswordStrength(
                widget.viewModel.estimatePasswordEntropyBits(passwordCtrl.text),
              ),
              TextField(
                controller: hintCtrl,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Password Hint'),
              ),
              if (isEncoding) ...[
                const SizedBox(height: 12),
                _buildEncodingProgressWidget(
                  percent: encodingPercent,
                  countdownSeconds: countdownSeconds,
                  title: 'Re-encrypting item...',
                ),
              ],
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: AppTheme.crimsonAlert),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isEncoding ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isEncoding
                  ? null
                  : () async {
                      if (passwordCtrl.text.length < 6 ||
                          passwordCtrl.text != confirmCtrl.text ||
                          hintCtrl.text.trim().isEmpty) {
                        setDialogState(() {
                          errorMessage = passwordCtrl.text.length < 6
                              ? 'Item Password must be at least 6 characters.'
                              : passwordCtrl.text != confirmCtrl.text
                                  ? 'Item passwords do not match.'
                                  : 'Password Hint is required.';
                        });
                        return;
                      }
                      setDialogState(() {
                        isEncoding = true;
                        errorMessage = null;
                        encodingPercent = 0.0;
                        countdownSeconds = 1.5;
                      });

                      tracker = _EncodingProgressTracker(
                        estimatedDuration: const Duration(milliseconds: 1500),
                        onUpdate: (pct, remaining) {
                          setDialogState(() {
                            encodingPercent = pct;
                            countdownSeconds = remaining;
                          });
                        },
                      )..start();

                      try {
                        await widget.viewModel.setItemExtraLock(
                          itemUuid: item.itemUuid,
                          newItemPassword: passwordCtrl.text,
                          passwordHint: hintCtrl.text,
                          currentItemPassword: currentItemPassword,
                        );
                        tracker?.complete();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 150),
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (error) {
                        tracker?.dispose();
                        setDialogState(() {
                          isEncoding = false;
                          errorMessage = error.toString();
                        });
                      }
                    },
              child: isEncoding
                  ? Text('Encoding ${(encodingPercent * 100).toInt()}%...')
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    passwordCtrl.dispose();
    confirmCtrl.dispose();
    hintCtrl.dispose();
  }

  Future<void> _showEnterItemPasswordDialog(
    BuildContext context,
    VaultTopicSummary item, {
    String? overridePassword,
    required Future<void> Function(String itemPassword) onUnlocked,
  }) async {
    final passwordCtrl = TextEditingController();
    String? errorMessage;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enter Item Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Unlock "${item.topic}" to continue.'),
              if (item.passwordHint.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Hint: ${item.passwordHint}'),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Item Password'),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.crimsonAlert,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.viewModel.verifyItemPassword(
                    item.itemUuid,
                    overridePassword: overridePassword,
                    itemPassword: passwordCtrl.text,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                    await onUnlocked(passwordCtrl.text);
                  }
                } on ItemLockedException {
                  setDialogState(
                      () => errorMessage = 'Incorrect item password');
                } catch (error) {
                  setDialogState(() => errorMessage = error.toString());
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
    passwordCtrl.dispose();
  }

  Future<void> _showEnterPasswordDialog(
    BuildContext context,
    VaultTopicSummary item, {
    required Future<void> Function(String? itemPassword) onUnlocked,
  }) async {
    final passwordCtrl = TextEditingController();
    String? errorMessage;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enter Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Unlock "${item.topic}" to continue.'),
              if (!item.hasExtraLock && item.passwordHint.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Password Hint: ${item.passwordHint}'),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.crimsonAlert,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () async {
                try {
                  await widget.viewModel.updateItemPassword(
                    itemUuid: item.itemUuid,
                    currentItemPassword: passwordCtrl.text,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                    await onUnlocked(null);
                  }
                } on VaultItemPasswordException {
                  setDialogState(() => errorMessage = 'Incorrect password');
                } catch (error) {
                  setDialogState(() => errorMessage = error.toString());
                }
              },
              child: const Text('Update to Current Password'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.viewModel.verifyVaultPassword(
                    item.itemUuid,
                    overridePassword: passwordCtrl.text,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                    await onUnlocked(passwordCtrl.text);
                  }
                } on VaultItemPasswordException {
                  setDialogState(() => errorMessage = 'Incorrect password');
                } catch (error) {
                  setDialogState(() => errorMessage = error.toString());
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
    passwordCtrl.dispose();
  }

  void _showActionError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }

  void _showShareSxsiDialog(
    BuildContext context,
    VaultTopicSummary item, {
    String? itemPassword,
    String? overridePassword,
  }) {
    final filePwdCtrl = TextEditingController();
    String? sxsiPacket;
    String? errorMsg;
    var isEncoding = false;
    var encodingPercent = 0.0;
    var countdownSeconds = 1.0;
    _EncodingProgressTracker? tracker;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Share "${item.topic}" (.sxsi)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Encrypts this single topic with a File Password ("SXSI" header + Argon2id + AES-256-GCM).',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: filePwdCtrl,
                      obscureText: true,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'File Password',
                      ),
                    ),
                    if (isEncoding) ...[
                      const SizedBox(height: 12),
                      _buildEncodingProgressWidget(
                        percent: encodingPercent,
                        countdownSeconds: countdownSeconds,
                        title: 'Encoding .sxsi container...',
                      ),
                    ],
                    if (sxsiPacket != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        sxsiPacket!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          color: AppTheme.emeraldSecure,
                        ),
                      ),
                    ],
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.crimsonAlert,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
                if (sxsiPacket != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.viewModel.copySecretWithAutoClear(
                        label: '.sxsi File',
                        secretValue: sxsiPacket!,
                      );
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                  ),
                FilledButton(
                  onPressed: isEncoding
                      ? null
                      : () async {
                          if (filePwdCtrl.text.trim().isEmpty) {
                            setDialogState(() {
                              errorMsg = 'File Password is required.';
                            });
                            return;
                          }
                          setDialogState(() {
                            isEncoding = true;
                            errorMsg = null;
                            encodingPercent = 0.0;
                            countdownSeconds = 1.0;
                          });

                          tracker = _EncodingProgressTracker(
                            estimatedDuration:
                                const Duration(milliseconds: 1000),
                            onUpdate: (pct, remaining) {
                              setDialogState(() {
                                encodingPercent = pct;
                                countdownSeconds = remaining;
                              });
                            },
                          )..start();

                          try {
                            final packet =
                                await widget.viewModel.exportSingleItemSxsi(
                              itemUuid: item.itemUuid,
                              filePassword: filePwdCtrl.text,
                              itemPassword: itemPassword,
                              overridePassword: overridePassword,
                            );
                            tracker?.complete();
                            setDialogState(() {
                              isEncoding = false;
                              sxsiPacket = packet;
                              errorMsg = null;
                            });
                          } catch (e) {
                            tracker?.dispose();
                            setDialogState(() {
                              isEncoding = false;
                              errorMsg = e.toString();
                            });
                          }
                        },
                  child: isEncoding
                      ? Text('Encoding ${(encodingPercent * 100).toInt()}%...')
                      : const Text('Create .sxsi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showImportSxsiDialog(BuildContext context) {
    final packetCtrl = TextEditingController();
    final filePwdCtrl = TextEditingController();
    String? statusMsg;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Import File (.sxsi)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: packetCtrl,
                      maxLines: 3,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: '.sxsi File Content',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: filePwdCtrl,
                      obscureText: true,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'File Password',
                      ),
                    ),
                    if (statusMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        statusMsg!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.crimsonAlert,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await widget.viewModel.importSingleItemSxsi(
                        sxsiPacket: packetCtrl.text,
                        filePassword: filePwdCtrl.text,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } catch (e) {
                      setDialogState(() => statusMsg = e.toString());
                    }
                  },
                  child: const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSxsBackupDialog(BuildContext context) {
    final masterCtrl = TextEditingController(text: 'SuperSecret#2026');
    final backupPwdCtrl = TextEditingController(text: 'BackupVaultKey#2026');
    final restoreBytesCtrl = TextEditingController();
    String? exportStatus;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Backup (.sxs)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Full Vault Backup ("SXSV" 64B Header + Argon2id + AES-256-GCM)',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: masterCtrl,
                      obscureText: true,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Verify Vault Password',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: backupPwdCtrl,
                      obscureText: true,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Backup File Password',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: restoreBytesCtrl,
                      minLines: 2,
                      maxLines: 4,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Restore .sxs (Base64 URL)',
                      ),
                    ),
                    if (exportStatus != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        exportStatus!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppTheme.emeraldSecure,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      final bytes =
                          await widget.viewModel.exportSxsEncryptedFile(
                        masterPasswordVerification: masterCtrl.text,
                        backupFilePassword: backupPwdCtrl.text,
                      );
                      setDialogState(() {
                        exportStatus = base64Url.encode(bytes);
                      });
                    } catch (e) {
                      setDialogState(() {
                        exportStatus = e.toString();
                      });
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Export .sxs'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      final bytes = Uint8List.fromList(
                        base64Url.decode(
                          base64Url.normalize(restoreBytesCtrl.text.trim()),
                        ),
                      );
                      await widget.viewModel.restoreSxsEncryptedFile(
                        backupBytes: bytes,
                        backupFilePassword: backupPwdCtrl.text,
                      );
                      setDialogState(() {
                        exportStatus = 'Backup restored.';
                      });
                    } catch (error) {
                      setDialogState(() => exportStatus = error.toString());
                    }
                  },
                  child: const Text('Restore .sxs'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EncodingProgressTracker {
  _EncodingProgressTracker({
    required this.estimatedDuration,
    required this.onUpdate,
  });

  final Duration estimatedDuration;
  final void Function(double percent, double countdownSeconds) onUpdate;

  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();

  void start() {
    _stopwatch.reset();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      final elapsedMs = _stopwatch.elapsedMilliseconds;
      final totalMs = estimatedDuration.inMilliseconds;
      final progress = (elapsedMs / totalMs).clamp(0.0, 0.95);
      final remainingMs = (totalMs - elapsedMs).clamp(0, totalMs);
      onUpdate(progress, remainingMs / 1000.0);
    });
  }

  void complete() {
    _timer?.cancel();
    _stopwatch.stop();
    onUpdate(1.0, 0.0);
  }

  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
  }
}
