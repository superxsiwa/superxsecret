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
            title: Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: AppTheme.emeraldSecure,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'SuperXSecret',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldSecure.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.emeraldSecure.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'OFFLINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.emeraldSecure,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () => _showImportSxsiDialog(context),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Import File'),
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
                      Text(
                        item.topic,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: AppTheme.textPrimary,
                        ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    size: 14,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showShareSxsiDialog(context, item),
                  icon: const Icon(Icons.ios_share_rounded, size: 15),
                  label: const Text('Share', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        AppTheme.emeraldSecure.withValues(alpha: 0.16),
                    foregroundColor: AppTheme.emeraldSecure,
                  ),
                  onPressed: () =>
                      widget.viewModel.revealSecretJit(item.itemUuid),
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const Text(
                    'View',
                    style: TextStyle(
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

  void _showNewTopicDialog(BuildContext context) {
    final topicCtrl = TextEditingController();
    final secretCtrl = TextEditingController();
    String? errorMsg;

    showDialog<void>(
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
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await widget.viewModel.createTopic(
                        topic: topicCtrl.text,
                        secretText: secretCtrl.text,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } catch (e) {
                      setDialogState(() => errorMsg = e.toString());
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  void _showShareSxsiDialog(BuildContext context, VaultTopicSummary item) {
    final filePwdCtrl = TextEditingController();
    String? sxsiPacket;
    String? errorMsg;

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
                  onPressed: () async {
                    try {
                      final packet =
                          await widget.viewModel.exportSingleItemSxsi(
                        itemUuid: item.itemUuid,
                        filePassword: filePwdCtrl.text,
                      );
                      setDialogState(() {
                        sxsiPacket = packet;
                        errorMsg = null;
                      });
                    } catch (e) {
                      setDialogState(() => errorMsg = e.toString());
                    }
                  },
                  child: const Text('Create .sxsi'),
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
    String? exportStatus;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Backup (.sxs)'),
              content: Column(
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
                  if (exportStatus != null) ...[
                    const SizedBox(height: 12),
                    Text(
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      final bytes = await widget.viewModel
                          .exportSxsEncryptedFile(
                        masterPasswordVerification: masterCtrl.text,
                        backupFilePassword: backupPwdCtrl.text,
                      );
                      setDialogState(() {
                        exportStatus =
                            'Exported vault.sxs (${bytes.length} bytes, Magic: "SXSV")';
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
              ],
            );
          },
        );
      },
    );
  }
}


