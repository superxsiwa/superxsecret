import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../domain/models/vault_models.dart';
import '../../../core/controllers/auto_lock_controller.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/controllers/license_controller.dart';
import '../../../core/utils/platform_file_helper.dart';
import '../../../core/widgets/scrambled_pin_pad.dart';
import '../view_models/vault_view_model.dart';
import 'pro_upgrade_sheet.dart';

class VaultDashboardView extends StatefulWidget {
  const VaultDashboardView({
    super.key,
    required this.viewModel,
    required this.onLockRequested,
    this.autoLockController,
    this.licenseController,
  });

  final VaultViewModel viewModel;
  final VoidCallback onLockRequested;
  final AutoLockController? autoLockController;
  final LicenseController? licenseController;

  @override
  State<VaultDashboardView> createState() => _VaultDashboardViewState();
}

class _VaultDashboardViewState extends State<VaultDashboardView>
    with SingleTickerProviderStateMixin {
  String? _openingItemUuid;
  double _openingPercent = 0.0;
  double _openingCountdownSeconds = 0.0;
  _EncodingProgressTracker? _openingTracker;
  late final TabController _tabController;
  VaultItemCategory _selectedCategory = VaultItemCategory.text;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: VaultItemCategory.values.length,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {
          _selectedCategory = VaultItemCategory.values[_tabController.index];
        });
      }
    });
    widget.viewModel.loadVaultSummaries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _openingTracker?.dispose();
    super.dispose();
  }

  static IconData _categoryIcon(VaultItemCategory category) {
    switch (category) {
      case VaultItemCategory.text:
        return Icons.notes_rounded;
      case VaultItemCategory.image:
        return Icons.image_rounded;
      case VaultItemCategory.audio:
        return Icons.audiotrack_rounded;
      case VaultItemCategory.video:
        return Icons.videocam_rounded;
      case VaultItemCategory.file:
        return Icons.insert_drive_file_rounded;
    }
  }

  static String _categoryName(VaultItemCategory category, AppStrings strings) {
    switch (category) {
      case VaultItemCategory.text:
        return strings.tabText;
      case VaultItemCategory.image:
        return strings.tabImage;
      case VaultItemCategory.audio:
        return strings.tabAudio;
      case VaultItemCategory.video:
        return strings.tabVideo;
      case VaultItemCategory.file:
        return strings.tabFile;
    }
  }

  static String _pickFileButtonLabel(VaultItemCategory category, AppStrings strings) {
    switch (category) {
      case VaultItemCategory.image:
        return strings.selectImage;
      case VaultItemCategory.audio:
        return strings.selectAudio;
      case VaultItemCategory.video:
        return strings.selectVideo;
      default:
        return strings.selectFile;
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLanguageScope.stringsOf(context);

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final items = widget.viewModel.filteredItems;
        final clipboardSecs = widget.viewModel.clipboardSecondsRemaining;
        final categoryItems =
            items.where((i) => i.category == _selectedCategory).toList();

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 52,
            titleSpacing: 16,
            title: const Row(
              children: [
                Icon(
                  Icons.shield_rounded,
                  color: AppTheme.emeraldSecure,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'SuperXSecret',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(96),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionToolbar(context, strings),
                  TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    indicatorColor: AppTheme.emeraldSecure,
                    labelColor: AppTheme.emeraldSecure,
                    unselectedLabelColor: AppTheme.textSecondaryOf(context),
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.notes_rounded, size: 20),
                        text:
                            '(${items.where((i) => i.category == VaultItemCategory.text).length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.image_outlined, size: 20),
                        text:
                            '(${items.where((i) => i.category == VaultItemCategory.image).length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.audiotrack_outlined, size: 20),
                        text:
                            '(${items.where((i) => i.category == VaultItemCategory.audio).length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.videocam_outlined, size: 20),
                        text:
                            '(${items.where((i) => i.category == VaultItemCategory.video).length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.insert_drive_file_outlined, size: 20),
                        text:
                            '(${items.where((i) => i.category == VaultItemCategory.file).length})',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          body: Column(
            children: [
              if (clipboardSecs > 0)
                _buildClipboardAutoWipeBanner(context, clipboardSecs),
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
                        decoration: InputDecoration(
                          hintText: strings.searchTopic,
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.emeraldSecure,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                      ),
                      tooltip: strings.newTopicBtn,
                      onPressed: () => _showNewTopicDialog(
                        context,
                        initialCategory: _selectedCategory,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 22),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: categoryItems.isEmpty
                    ? (items.isEmpty
                        ? _buildEmptyVaultState(context, strings)
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _categoryIcon(_selectedCategory),
                                    size: 48,
                                    color: AppTheme.textMutedOf(context)
                                        .withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    strings.noItemsInCategory(
                                      _categoryName(_selectedCategory, strings),
                                    ),
                                    style: TextStyle(
                                      color: AppTheme.textMutedOf(context),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: categoryItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final summary = categoryItems[index];
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

  Widget _buildEmptyVaultState(BuildContext context, AppStrings strings) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.emeraldSecure.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppTheme.emeraldSecure.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 36,
                color: AppTheme.emeraldSecure,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              strings.emptyVaultTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.emptyVaultSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondaryOf(context),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionToolbar(BuildContext context, AppStrings strings) {
    return Container(
      height: 46,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCardOf(context).withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderHighlightOf(context).withValues(alpha: 0.4),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: strings.theme,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                AppTheme.isDarkMode(context)
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                size: 20,
              ),
              onPressed: () => showThemeSelectionDialog(
                context,
                AppThemeScope.of(context),
              ),
            ),
            IconButton(
              tooltip: strings.language,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.language_rounded, size: 20),
              onPressed: () => showLanguageSelectionDialog(
                context,
                AppLanguageScope.of(context),
              ),
            ),
            if (widget.licenseController != null)
              ListenableBuilder(
                listenable: widget.licenseController!,
                builder: (context, _) {
                  final isPro = widget.licenseController!.isPro;
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => ProUpgradeSheet.show(
                      context,
                      licenseController: widget.licenseController!,
                      currentItemCount: widget.viewModel.filteredItems.length,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isPro
                            ? AppTheme.emeraldSecure.withValues(alpha: 0.15)
                            : AppTheme.cyberCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isPro
                              ? AppTheme.emeraldSecure.withValues(alpha: 0.4)
                              : AppTheme.cyberCyan.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPro
                                ? Icons.verified_rounded
                                : Icons.workspace_premium_rounded,
                            size: 14,
                            color: isPro
                                ? AppTheme.emeraldSecure
                                : AppTheme.cyberCyan,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPro ? 'PRO' : 'UPGRADE',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isPro
                                  ? AppTheme.emeraldSecure
                                  : AppTheme.cyberCyan,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            IconButton(
              tooltip: strings.importSxsi,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.file_download_outlined, size: 20),
              onPressed: () => _showImportSxsiDialog(context),
            ),
            IconButton(
              tooltip: strings.backupSxs,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.import_export_rounded, size: 20),
              onPressed: () => _showSxsBackupDialog(context),
            ),
            IconButton(
              tooltip: strings.pinAndAutoLockSettings,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.dialpad_rounded, size: 20),
              onPressed: () => _showPinAndAutoLockSettingsSheet(context),
            ),
            IconButton(
              tooltip: strings.lockVault,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.lock_outline_rounded,
                color: AppTheme.amberWarning,
                size: 20,
              ),
              onPressed: () {
                widget.viewModel.hideAndZeroizeRevealedSecret();
                widget.onLockRequested();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClipboardAutoWipeBanner(
      BuildContext context, int secondsLeft) {
    final strings = AppLanguageScope.stringsOf(context);
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
              '${strings.copied}: "${widget.viewModel.copiedFieldLabel}" (${strings.secondsLeft(secondsLeft.toString())})',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.amberWarning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.viewModel.clearClipboardImmediately,
            child: Text(strings.clear, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, VaultTopicSummary item) {
    final strings = AppLanguageScope.stringsOf(context);
    final isRevealed =
        widget.viewModel.activeRevealedSecret?.itemUuid == item.itemUuid;
    final isOpening = _openingItemUuid == item.itemUuid;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isRevealed
              ? AppTheme.emeraldSecure.withValues(alpha: 0.7)
              : AppTheme.borderSubtleOf(context),
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
                  child: Icon(
                    _categoryIcon(item.category),
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
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                color: AppTheme.textPrimaryOf(context),
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
                        item.fileName != null
                            ? '${item.fileName} (${_formatBytes(item.fileSizeBytes ?? 0)}) • ${item.cipherType.badgeLabel}'
                            : '•••••••••••• • ${item.cipherType.badgeLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: strings.itemLockTooltip,
                  onSelected: (action) {
                    if (action == 'delete') {
                      _confirmDeleteItem(item);
                    } else {
                      _manageItemLock(item, action);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!item.hasExtraLock)
                      PopupMenuItem(
                        value: 'add',
                        child: Text(strings.addExtraLock),
                      )
                    else ...[
                      PopupMenuItem(
                        value: 'change',
                        child: Text(strings.changeItemPassword),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(strings.removeItemExtraLock),
                      ),
                    ],
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppTheme.crimsonAlert,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            strings.deleteItemMenu,
                            style: const TextStyle(color: AppTheme.crimsonAlert),
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
            if (isOpening) ...[
              const SizedBox(height: 12),
              _buildEncodingProgressWidget(
                context,
                percent: _openingPercent,
                countdownSeconds: _openingCountdownSeconds,
                title: strings.decodingData,
              ),
            ],
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: AppTheme.borderSubtleOf(context),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  tooltip: strings.delete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppTheme.crimsonAlert.withValues(alpha: 0.8),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDeleteItem(item),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _shareItem(item),
                  icon: const Icon(Icons.ios_share_rounded, size: 15),
                  label: Text(strings.share, style: const TextStyle(fontSize: 12)),
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
                      ? const SizedBox.shrink()
                      : const Icon(Icons.visibility_rounded, size: 16),
                  label: Text(
                    isOpening
                        ? (_openingPercent == 0.0
                            ? strings.opening
                            : '${strings.opening} ${(_openingPercent * 100).toInt()}%')
                        : strings.view,
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
    final strings = AppLanguageScope.stringsOf(context);
    final secret = widget.viewModel.activeRevealedSecret!;
    final secsLeft = widget.viewModel.revealSecondsRemaining;
    final progress = (secsLeft / 15.0).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevatedOf(context),
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
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _categoryIcon(secret.category),
                      color: AppTheme.emeraldSecure,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${secret.topic} • ${strings.autoHide(secsLeft.toString())}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.emeraldSecure,
                        ),
                      ),
                    ),
                  ],
                ),
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
              backgroundColor: AppTheme.borderSubtleOf(context),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.emeraldSecure,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildRevealedContent(context, secret),
        ],
      ),
    );
  }

  Widget _buildRevealedContent(
    BuildContext context,
    DecodedTopicSecret secret,
  ) {
    final strings = AppLanguageScope.stringsOf(context);

    if (secret.category == VaultItemCategory.image &&
        secret.rawBytes != null &&
        secret.rawBytes!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 260),
              color: Colors.black38,
              alignment: Alignment.center,
              child: Image.memory(
                secret.rawBytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${secret.fileName ?? "image.png"} (${_formatBytes(secret.fileSizeBytes ?? secret.rawBytes!.length)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  PlatformFileHelper.downloadFile(
                    fileName: secret.fileName ?? '${secret.topic}.png',
                    bytes: secret.rawBytes!,
                    mimeType: secret.mimeType ?? 'image/png',
                  );
                },
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(strings.downloadDecryptedImage),
              ),
            ],
          ),
          if (secret.secretText.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSecretRow(
              context,
              strings.optionalSecretNote,
              secret.secretText,
            ),
          ],
        ],
      );
    }

    if (secret.category == VaultItemCategory.audio &&
        secret.rawBytes != null &&
        secret.rawBytes!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtleOf(context)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.audiotrack_rounded,
                  color: AppTheme.emeraldSecure,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        secret.fileName ?? '${secret.topic}.mp3',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _formatBytes(
                          secret.fileSizeBytes ?? secret.rawBytes!.length,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    PlatformFileHelper.downloadFile(
                      fileName: secret.fileName ?? '${secret.topic}.mp3',
                      bytes: secret.rawBytes!,
                      mimeType: secret.mimeType ?? 'audio/mpeg',
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text(strings.downloadDecryptedAudio),
                ),
              ],
            ),
          ),
          if (secret.secretText.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSecretRow(
              context,
              strings.optionalSecretNote,
              secret.secretText,
            ),
          ],
        ],
      );
    }

    if (secret.category == VaultItemCategory.video &&
        secret.rawBytes != null &&
        secret.rawBytes!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtleOf(context)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.videocam_rounded,
                  color: AppTheme.emeraldSecure,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        secret.fileName ?? '${secret.topic}.mp4',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _formatBytes(
                          secret.fileSizeBytes ?? secret.rawBytes!.length,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    PlatformFileHelper.downloadFile(
                      fileName: secret.fileName ?? '${secret.topic}.mp4',
                      bytes: secret.rawBytes!,
                      mimeType: secret.mimeType ?? 'video/mp4',
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text(strings.downloadDecryptedVideo),
                ),
              ],
            ),
          ),
          if (secret.secretText.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSecretRow(
              context,
              strings.optionalSecretNote,
              secret.secretText,
            ),
          ],
        ],
      );
    }

    if (secret.category == VaultItemCategory.file &&
        secret.rawBytes != null &&
        secret.rawBytes!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtleOf(context)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insert_drive_file_rounded,
                  color: AppTheme.emeraldSecure,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        secret.fileName ?? '${secret.topic}.bin',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _formatBytes(
                          secret.fileSizeBytes ?? secret.rawBytes!.length,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    PlatformFileHelper.downloadFile(
                      fileName: secret.fileName ?? '${secret.topic}.bin',
                      bytes: secret.rawBytes!,
                      mimeType: secret.mimeType ?? 'application/octet-stream',
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text(strings.downloadDecryptedFile),
                ),
              ],
            ),
          ),
          if (secret.secretText.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSecretRow(
              context,
              strings.optionalSecretNote,
              secret.secretText,
            ),
          ],
        ],
      );
    }

    return _buildSecretRow(context, strings.secretText, secret.secretText);
  }

  Widget _buildSecretRow(BuildContext context, String label, String value) {
    final strings = AppLanguageScope.stringsOf(context);
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
                    color: AppTheme.textSecondaryOf(context),
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
            label: Text(strings.copy, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showPinAndAutoLockSettingsSheet(BuildContext context) {
    final autoLock = widget.autoLockController ??
        (context.findAncestorWidgetOfExactType<AutoLockScope>()?.controller);
    if (autoLock == null) return;

    final strings = AppLanguageScope.stringsOf(context);
    final isThai = AppLanguageScope.of(context).isThai(context);

    var settingPinMode = false;
    var enteredPin = '';
    var obscurePin = true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return ListenableBuilder(
              listenable: autoLock,
              builder: (context, _) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emeraldSecure
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.dialpad_rounded,
                                    size: 20,
                                    color: AppTheme.emeraldSecure,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  strings.pinAndAutoLockSettings,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (!settingPinMode) ...[
                          // Section 1: Inactivity Timeout options
                          Text(
                            strings.inactivityTimeoutLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.cyberCyan,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.inactivityTimeoutDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final m in [1, 2, 3, 5, 0])
                                ChoiceChip(
                                  label: Text(
                                    m == 1
                                        ? strings.timeout1Min
                                        : m == 2
                                            ? strings.timeout2Min
                                            : m == 3
                                                ? strings.timeout3Min
                                                : m == 5
                                                    ? strings.timeout5Min
                                                    : strings.timeoutOff,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          autoLock.inactivityTimeoutMinutes == m
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                      color:
                                          autoLock.inactivityTimeoutMinutes == m
                                              ? Colors.black
                                              : AppTheme.textPrimaryOf(context),
                                    ),
                                  ),
                                  selected:
                                      autoLock.inactivityTimeoutMinutes == m,
                                  selectedColor: AppTheme.emeraldSecure,
                                  backgroundColor:
                                      AppTheme.surfaceElevatedOf(context),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color:
                                          autoLock.inactivityTimeoutMinutes == m
                                              ? AppTheme.emeraldSecure
                                              : AppTheme.borderSubtleOf(context),
                                    ),
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      autoLock.setInactivityTimeoutMinutes(
                                        m,
                                        onHardLogout: widget.onLockRequested,
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Section 2: Screen Off Timeout options
                          Text(
                            strings.screenOffTimeoutLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.cyberCyan,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.screenOffTimeoutDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final m in [0, 1, 2, 3, 5])
                                ChoiceChip(
                                  label: Text(
                                    m == 0
                                        ? strings.timeoutImmediate
                                        : m == 1
                                            ? strings.timeout1Min
                                            : m == 2
                                                ? strings.timeout2Min
                                                : m == 3
                                                    ? strings.timeout3Min
                                                    : strings.timeout5Min,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          autoLock.screenOffTimeoutMinutes == m
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                      color:
                                          autoLock.screenOffTimeoutMinutes == m
                                              ? Colors.black
                                              : AppTheme.textPrimaryOf(context),
                                    ),
                                  ),
                                  selected:
                                      autoLock.screenOffTimeoutMinutes == m,
                                  selectedColor: AppTheme.emeraldSecure,
                                  backgroundColor:
                                      AppTheme.surfaceElevatedOf(context),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color:
                                          autoLock.screenOffTimeoutMinutes == m
                                              ? AppTheme.emeraldSecure
                                              : AppTheme.borderSubtleOf(context),
                                    ),
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      autoLock.setScreenOffTimeoutMinutes(m);
                                    }
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Section 2: Quick PIN Status & Controls
                          Text(
                            strings.quickPinTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.cyberCyan,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevatedOf(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: autoLock.isPinConfigured
                                    ? AppTheme.emeraldSecure
                                        .withValues(alpha: 0.35)
                                    : AppTheme.borderSubtleOf(context),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  autoLock.isPinConfigured
                                      ? Icons.check_circle_rounded
                                      : Icons.lock_open_rounded,
                                  color: autoLock.isPinConfigured
                                      ? AppTheme.emeraldSecure
                                      : AppTheme.textSecondaryOf(context),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        autoLock.isPinConfigured
                                            ? strings.quickPinActive
                                            : strings.quickPinNotSet,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: autoLock.isPinConfigured
                                              ? AppTheme.emeraldSecure
                                              : AppTheme.textPrimaryOf(context),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        autoLock.isPinConfigured
                                            ? (isThai
                                                ? 'ใช้ปลดล็อกอย่างรวดเร็วเมื่อพักหน้าจอ'
                                                : 'Used to quickly resume when paused')
                                            : (isThai
                                                ? 'ตั้งค่าเพื่อไม่ต้องพิมพ์ Master Password ทุกครั้ง'
                                                : 'Set up to avoid typing Master Password repeatedly'),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppTheme.textSecondaryOf(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (!autoLock.isPinConfigured)
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.emeraldSecure,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        settingPinMode = true;
                                        enteredPin = '';
                                      });
                                    },
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: Text(strings.setPinBtn),
                                  ),
                                )
                              else ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        settingPinMode = true;
                                        enteredPin = '';
                                      });
                                    },
                                    icon: const Icon(Icons.edit_rounded, size: 16),
                                    label: Text(strings.changePinBtn),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.crimsonAlert,
                                  ),
                                  onPressed: () async {
                                    await autoLock.removeQuickPin();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content:
                                              Text(strings.pinRemovedSnackbar),
                                          backgroundColor:
                                              AppTheme.amberWarning,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 16),
                                  label: Text(strings.removePinBtn),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Security Notice
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.emeraldSecure
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.emeraldSecure
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  color: AppTheme.emeraldSecure,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    strings.autoLockInfoNotice,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: AppTheme.textSecondaryOf(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Sub-view: Setting/Changing PIN with ScrambledPinPad
                          Text(
                            strings.enterPinPrompt,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.cyberCyan,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevatedOf(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.borderSubtleOf(context),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    enteredPin.isEmpty
                                        ? strings.tapDigitsBelow
                                        : (obscurePin
                                            ? '• ' * enteredPin.length
                                            : enteredPin),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: enteredPin.isEmpty ? 13 : 22,
                                      letterSpacing: enteredPin.isEmpty ? 0 : 4,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.emeraldSecure,
                                      fontFamily: enteredPin.isEmpty
                                          ? null
                                          : 'monospace',
                                    ),
                                  ),
                                ),
                                if (enteredPin.isNotEmpty)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      obscurePin
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: AppTheme.textSecondaryOf(context),
                                    ),
                                    onPressed: () => setModalState(
                                      () => obscurePin = !obscurePin,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ScrambledPinPad(
                            onDigitPressed: (d) {
                              if (enteredPin.length < 12) {
                                setModalState(() => enteredPin += d);
                              }
                            },
                            onBackspace: () {
                              if (enteredPin.isNotEmpty) {
                                setModalState(
                                  () => enteredPin = enteredPin.substring(
                                      0, enteredPin.length - 1),
                                );
                              }
                            },
                            onReshuffle: () {
                              setModalState(() => enteredPin = '');
                            },
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setModalState(() {
                                      settingPinMode = false;
                                      enteredPin = '';
                                    });
                                  },
                                  child: Text(strings.cancel),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.emeraldSecure,
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: enteredPin.length < 4
                                      ? null
                                      : () async {
                                          await autoLock.setQuickPin(enteredPin);
                                          setModalState(() {
                                            settingPinMode = false;
                                            enteredPin = '';
                                          });
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    strings.pinSavedSnackbar),
                                                backgroundColor:
                                                    AppTheme.emeraldSecure,
                                              ),
                                            );
                                          }
                                        },
                                  child: Text(strings.setPinBtn),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showScrambledKeypadDemoSheet(
    BuildContext context, {
    ValueChanged<String>? onPinSaved,
  }) {
    final strings = AppLanguageScope.stringsOf(context);
    final isThai = AppLanguageScope.of(context).isThai(context);
    final topicCtrl = TextEditingController(
      text: isThai ? 'รหัส PIN' : 'PIN Code',
    );
    var enteredPin = '';
    var obscurePin = true;
    var isSaving = false;
    var encodingPercent = 0.0;
    var countdownSeconds = 1.0;
    _EncodingProgressTracker? tracker;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.scrambledPinPad,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (onPinSaved == null) ...[
                      TextField(
                        controller: topicCtrl,
                        enabled: !isSaving,
                        enableIMEPersonalizedLearning: false,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: strings.topicFieldLabel,
                          prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevatedOf(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.borderSubtleOf(context),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              enteredPin.isEmpty
                                  ? strings.tapDigitsBelow
                                  : (obscurePin
                                      ? '• ' * enteredPin.length
                                      : enteredPin),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: enteredPin.isEmpty ? 13 : 22,
                                letterSpacing: enteredPin.isEmpty ? 0 : 4,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.emeraldSecure,
                                fontFamily: enteredPin.isEmpty ? null : 'monospace',
                              ),
                            ),
                          ),
                          if (enteredPin.isNotEmpty)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: obscurePin ? 'Show' : 'Hide',
                              icon: Icon(
                                obscurePin
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () => setModalState(
                                        () => obscurePin = !obscurePin,
                                      ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ScrambledPinPad(
                      onDigitPressed: (d) {
                        if (!isSaving && enteredPin.length < 12) {
                          setModalState(() => enteredPin += d);
                        }
                      },
                      onBackspace: () {
                        if (!isSaving && enteredPin.isNotEmpty) {
                          setModalState(
                            () => enteredPin = enteredPin.substring(
                              0,
                              enteredPin.length - 1,
                            ),
                          );
                        }
                      },
                      onReshuffle: () {
                        if (!isSaving) {
                          setModalState(() => enteredPin = '');
                        }
                      },
                    ),
                    if (isSaving) ...[
                      const SizedBox(height: 14),
                      _buildEncodingProgressWidget(
                        context,
                        percent: encodingPercent,
                        countdownSeconds: countdownSeconds,
                        title: strings.encodingData,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                            child: Text(strings.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: enteredPin.isEmpty || isSaving
                                ? null
                                : () async {
                                    final isTest = WidgetsBinding
                                        .instance.runtimeType
                                        .toString()
                                        .contains('Test');
                                    const estimatedMs = kIsWeb ? 1500 : 800;

                                    setModalState(() {
                                      isSaving = true;
                                      encodingPercent = 0.0;
                                      countdownSeconds = estimatedMs / 1000.0;
                                    });

                                    tracker = _EncodingProgressTracker(
                                      estimatedDuration: const Duration(
                                        milliseconds: estimatedMs,
                                      ),
                                      onUpdate: (pct, remaining) {
                                        setModalState(() {
                                          encodingPercent = pct;
                                          countdownSeconds = remaining;
                                        });
                                      },
                                    )..start();

                                    if (onPinSaved != null) {
                                      if (!isTest) {
                                        await Future<void>.delayed(
                                          const Duration(milliseconds: estimatedMs),
                                        );
                                      }
                                      tracker?.complete();
                                      if (!isTest) {
                                        await Future<void>.delayed(
                                          const Duration(milliseconds: 150),
                                        );
                                      }
                                      onPinSaved(enteredPin);
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                      return;
                                    }

                                    final topic = topicCtrl.text.trim().isEmpty
                                        ? (isThai ? 'รหัส PIN' : 'PIN Code')
                                        : topicCtrl.text.trim();

                                    final saveFuture = widget.viewModel.createTopic(
                                      topic: topic,
                                      secretText: enteredPin,
                                      category: VaultItemCategory.text,
                                    );

                                    if (isTest) {
                                      await saveFuture;
                                    } else {
                                      await Future.wait([
                                        saveFuture,
                                        Future<void>.delayed(
                                          const Duration(milliseconds: estimatedMs),
                                        ),
                                      ]);
                                    }

                                    tracker?.complete();
                                    if (!isTest) {
                                      await Future<void>.delayed(
                                        const Duration(milliseconds: 150),
                                      );
                                    }

                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isThai
                                                ? 'บันทึก "$topic" เรียบร้อยแล้ว'
                                                : 'Saved "$topic" successfully',
                                          ),
                                          backgroundColor: AppTheme.emeraldSecure,
                                        ),
                                      );
                                    }
                                  },
                            icon: isSaving
                                ? const SizedBox.shrink()
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(
                              isSaving
                                  ? (encodingPercent == 0.0
                                      ? strings.encodingData
                                      : '${strings.encodingData} ${(encodingPercent * 100).toInt()}%')
                                  : strings.save,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      tracker?.dispose();
      topicCtrl.dispose();
    });
  }

  static String _cipherTypeName(VaultCipherType cipher, AppStrings strings) {
    switch (cipher) {
      case VaultCipherType.aes256Gcm:
        return strings.cipherAes256Gcm;
      case VaultCipherType.chacha20Poly1305:
        return strings.cipherChaCha20Poly1305;
      case VaultCipherType.xchacha20Poly1305:
        return strings.cipherXChaCha20Poly1305;
      case VaultCipherType.aes256CbcHmacSha512:
        return strings.cipherAes256CbcHmacSha512;
      case VaultCipherType.dualCipher:
        return strings.cipherDual;
    }
  }

  Future<void> _showNewTopicDialog(
    BuildContext context, {
    VaultItemCategory initialCategory = VaultItemCategory.text,
  }) async {
    final license = widget.licenseController ??
        (context.findAncestorWidgetOfExactType<LicenseScope>()?.controller);
    if (license != null &&
        !license.isPro &&
        widget.viewModel.filteredItems.length >=
            LicenseController.maxFreeItems) {
      await ProUpgradeSheet.show(
        context,
        licenseController: license,
        currentItemCount: widget.viewModel.filteredItems.length,
      );
      return;
    }

    // Free Tier check for initial category selection:
    if (license != null &&
        !license.isPro &&
        initialCategory != VaultItemCategory.text) {
      await ProUpgradeSheet.show(
        context,
        licenseController: license,
        currentItemCount: widget.viewModel.filteredItems.length,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => _NewTopicDialog(
        viewModel: widget.viewModel,
        initialCategory: initialCategory,
        licenseController: license,
        onCategorySaved: (cat) {
          if (mounted && _tabController.index != cat.index) {
            _tabController.animateTo(cat.index);
          }
        },
        showPinPad: (ctx, {onPinSaved}) =>
            _showScrambledKeypadDemoSheet(ctx, onPinSaved: onPinSaved),
      ),
    );
  }

  static Widget _buildItemPasswordStrength(BuildContext context, double bits) {
    final strings = AppLanguageScope.stringsOf(context);
    final strength = (bits / 100).clamp(0.0, 1.0);
    final color = bits < 45
        ? AppTheme.crimsonAlert
        : bits < 75
            ? AppTheme.amberWarning
            : AppTheme.emeraldSecure;
    final label = bits < 45
        ? strings.entropyWeak
        : bits < 75
            ? strings.entropyGood
            : strings.entropyStrong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${strings.entropyLabel}: $label (${bits.toStringAsFixed(0)} bits)',
          style: TextStyle(color: color, fontSize: 12),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: strength,
          minHeight: 4,
          backgroundColor: AppTheme.borderSubtleOf(context),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  static Widget _buildEncodingProgressWidget(
    BuildContext context, {
    required double percent,
    required double countdownSeconds,
    String? title,
  }) {
    final strings = AppLanguageScope.stringsOf(context);
    final progressTitle = title ?? strings.encodingData;
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
              Expanded(
                child: Row(
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
                    Flexible(
                      child: Text(
                        '$progressTitle $pctInt%',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.emeraldSecure,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldSecure.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  strings.secondsLeft(countdownSeconds.toStringAsFixed(1)),
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
              backgroundColor: AppTheme.borderSubtleOf(context),
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
    const estimatedMs = kIsWeb ? 1500 : 800;
    setState(() {
      _openingItemUuid = item.itemUuid;
      _openingPercent = 0.0;
      _openingCountdownSeconds = estimatedMs / 1000.0;
    });

    _openingTracker = _EncodingProgressTracker(
      estimatedDuration: const Duration(milliseconds: estimatedMs),
      onUpdate: (pct, remaining) {
        if (mounted && _openingItemUuid == item.itemUuid) {
          setState(() {
            _openingPercent = pct;
            _openingCountdownSeconds = remaining;
          });
        }
      },
    )..start();

    try {
      final isTest =
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
      final decryptFuture =
          widget.viewModel.decryptSecretPayload(item.itemUuid);
      final DecodedTopicSecret secret;
      if (isTest) {
        secret = await decryptFuture;
      } else {
        final results = await Future.wait([
          decryptFuture,
          Future<void>.delayed(const Duration(milliseconds: estimatedMs)),
        ]);
        secret = results[0] as DecodedTopicSecret;
      }
      _openingTracker?.complete();
      if (!isTest) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      if (mounted) {
        widget.viewModel.setActiveRevealedSecret(secret);
      }
    } on ItemLockedException {
      _openingTracker?.dispose();
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
      _openingTracker?.dispose();
      if (!mounted) return;
      await _showEnterPasswordDialog(
        context,
        item,
        onUnlocked: (password) => _revealWithVaultPassword(item, password),
      );
    } catch (error) {
      _openingTracker?.dispose();
      if (mounted) _showActionError(context, error);
    } finally {
      _openingTracker?.dispose();
      if (mounted) {
        setState(() {
          _openingItemUuid = null;
          _openingPercent = 0.0;
          _openingCountdownSeconds = 0.0;
        });
      }
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
    final strings = AppLanguageScope.stringsOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteConfirmTitle),
        content: Text(strings.deleteConfirmContent(item.topic)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.crimsonAlert,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.delete),
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
              content: Text(strings.deletedSnackbar(item.topic)),
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
    final strings = AppLanguageScope.stringsOf(context);
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
                ? strings.addExtraLock
                : strings.changeItemPassword,
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
                decoration: InputDecoration(labelText: strings.itemPasswordLabel),
              ),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setDialogState(() {}),
                decoration:
                    InputDecoration(labelText: strings.confirmPasswordLabel),
              ),
              const SizedBox(height: 8),
              _buildItemPasswordStrength(
                context,
                widget.viewModel.estimatePasswordEntropyBits(passwordCtrl.text),
              ),
              TextField(
                controller: hintCtrl,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: strings.passwordHintLabel),
              ),
              if (isEncoding) ...[
                const SizedBox(height: 12),
                _buildEncodingProgressWidget(
                  context,
                  percent: encodingPercent,
                  countdownSeconds: countdownSeconds,
                  title: strings.reEncryptingItem,
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
              child: Text(strings.cancel),
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
                              ? strings.itemPasswordMinLength
                              : passwordCtrl.text != confirmCtrl.text
                                  ? strings.itemPasswordsDoNotMatch
                                  : strings.passwordHintRequired;
                        });
                        return;
                      }
                      const estimatedMs = kIsWeb ? 2800 : 1200;
                      setDialogState(() {
                        isEncoding = true;
                        errorMessage = null;
                        encodingPercent = 0.0;
                        countdownSeconds = estimatedMs / 1000.0;
                      });

                      tracker = _EncodingProgressTracker(
                        estimatedDuration:
                            const Duration(milliseconds: estimatedMs),
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
                  ? Text('${strings.encodingData} ${(encodingPercent * 100).toInt()}%...')
                  : Text(strings.save),
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
    final strings = AppLanguageScope.stringsOf(context);
    final passwordCtrl = TextEditingController();
    String? errorMessage;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(strings.enterItemPasswordTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(strings.unlockToContinue(item.topic)),
              if (item.passwordHint.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('${strings.passwordHintLabel}: ${item.passwordHint}'),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: strings.itemPasswordLabel),
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
              child: Text(strings.cancel),
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
                      () => errorMessage = strings.incorrectItemPassword);
                } catch (error) {
                  setDialogState(() => errorMessage = error.toString());
                }
              },
              child: Text(strings.unlock),
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
    final strings = AppLanguageScope.stringsOf(context);
    final passwordCtrl = TextEditingController();
    String? errorMessage;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(strings.enterPasswordTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(strings.unlockToContinue(item.topic)),
              if (!item.hasExtraLock && item.passwordHint.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('${strings.passwordHintLabel}: ${item.passwordHint}'),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: strings.masterPasswordLabel),
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
              child: Text(strings.cancel),
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
                  setDialogState(() => errorMessage = strings.incorrectPassword);
                } catch (error) {
                  setDialogState(() => errorMessage = error.toString());
                }
              },
              child: Text(strings.updateToCurrentPassword),
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
                  setDialogState(() => errorMessage = strings.incorrectPassword);
                } catch (error) {
                  setDialogState(() => errorMessage = error.toString());
                }
              },
              child: Text(strings.unlock),
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
    final strings = AppLanguageScope.stringsOf(context);
    final filePwdCtrl = TextEditingController();
    var obscureFilePassword = false;
    String? sxsiPacket;
    String? errorMsg;
    String? downloadSuccessMsg;
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
              title: Text(strings.shareSxsiTitle(item.topic)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.shareSxsiDesc,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: filePwdCtrl,
                      obscureText: obscureFilePassword,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: strings.filePasswordLabel,
                        helperText: strings.filePasswordHelper,
                        helperMaxLines: 2,
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.auto_awesome, size: 20),
                              tooltip: strings.generateRandomPassword,
                              onPressed: () {
                                final pwd = widget.viewModel
                                    .generateRandomPassword(length: 16);
                                setDialogState(() {
                                  filePwdCtrl.text = pwd;
                                });
                              },
                            ),
                            if (filePwdCtrl.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                tooltip: strings.copyPasswordTooltip,
                                onPressed: () {
                                  widget.viewModel.copySecretWithAutoClear(
                                    label: 'File Password',
                                    secretValue: filePwdCtrl.text,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(strings.passwordCopied),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            IconButton(
                              icon: Icon(
                                obscureFilePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  obscureFilePassword = !obscureFilePassword;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (isEncoding) ...[
                      const SizedBox(height: 12),
                      _buildEncodingProgressWidget(
                        context,
                        percent: encodingPercent,
                        countdownSeconds: countdownSeconds,
                        title: strings.encodingSxsiContainer,
                      ),
                    ],
                    if (downloadSuccessMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldSecure.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.emeraldSecure.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppTheme.emeraldSecure,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                downloadSuccessMsg!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.emeraldSecure,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                  child: Text(strings.close),
                ),
                if (sxsiPacket != null) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      final safeTopic = item.topic
                          .replaceAll(RegExp(r'[^\w\s-]'), '_')
                          .trim();
                      final fileName =
                          '${safeTopic.isEmpty ? "secret" : safeTopic}.sxsi';
                      PlatformFileHelper.downloadFile(
                        fileName: fileName,
                        bytes: utf8.encode(sxsiPacket!),
                        mimeType: 'application/octet-stream',
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(strings.downloadFileBtn),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.viewModel.copySecretWithAutoClear(
                        label: '.sxsi File',
                        secretValue: sxsiPacket!,
                      );
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(strings.copy),
                  ),
                ],
                FilledButton(
                  onPressed: isEncoding
                      ? null
                      : () async {
                          if (filePwdCtrl.text.trim().isEmpty) {
                            setDialogState(() {
                              errorMsg = strings.filePasswordLabel;
                            });
                            return;
                          }
                          const estimatedMs = kIsWeb ? 1500 : 700;
                          setDialogState(() {
                            isEncoding = true;
                            errorMsg = null;
                            downloadSuccessMsg = null;
                            encodingPercent = 0.0;
                            countdownSeconds = estimatedMs / 1000.0;
                          });

                          tracker = _EncodingProgressTracker(
                            estimatedDuration:
                                const Duration(milliseconds: estimatedMs),
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

                            // Automatically trigger download of the .sxsi file
                            final safeTopic = item.topic
                                .replaceAll(RegExp(r'[^\w\s-]'), '_')
                                .trim();
                            final fileName =
                                '${safeTopic.isEmpty ? "secret" : safeTopic}.sxsi';
                            PlatformFileHelper.downloadFile(
                              fileName: fileName,
                              bytes: utf8.encode(packet),
                              mimeType: 'application/octet-stream',
                            );

                            setDialogState(() {
                              isEncoding = false;
                              sxsiPacket = packet;
                              errorMsg = null;
                              downloadSuccessMsg =
                                  strings.downloadSuccess(fileName);
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
                      ? Text('${strings.encodingData} ${(encodingPercent * 100).toInt()}%...')
                      : Text(strings.createSxsi),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      tracker?.dispose();
      filePwdCtrl.dispose();
    });
  }

  void _showImportSxsiDialog(BuildContext context) {
    final strings = AppLanguageScope.stringsOf(context);
    final packetCtrl = TextEditingController();
    final filePwdCtrl = TextEditingController();
    String? statusMsg;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(strings.importSxsiTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final fileContent =
                              await PlatformFileHelper.pickFileText(
                            allowedExtensions: ['sxsi', 'txt'],
                          );
                          if (fileContent != null && fileContent.isNotEmpty) {
                            setDialogState(() {
                              packetCtrl.text = fileContent.trim();
                              statusMsg = null;
                            });
                          }
                        } catch (e) {
                          setDialogState(() => statusMsg = e.toString());
                        }
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: Text(strings.pickFileBtn),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: packetCtrl,
                      maxLines: 3,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: strings.sxsiContentLabel,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: filePwdCtrl,
                      obscureText: true,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: strings.filePasswordLabel,
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
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final imported =
                          await widget.viewModel.importSingleItemSxsi(
                        sxsiPacket: packetCtrl.text,
                        filePassword: filePwdCtrl.text,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.emeraldSecure,
                            content: Text(
                              strings.importSuccessWithCipher(
                                imported.topic,
                                imported.cipherType.badgeLabel,
                              ),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => statusMsg = e.toString());
                    }
                  },
                  child: Text(strings.importBtn),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      packetCtrl.dispose();
      filePwdCtrl.dispose();
    });
  }

  void _showSxsBackupDialog(BuildContext context) {
    final strings = AppLanguageScope.stringsOf(context);
    final masterCtrl = TextEditingController();
    final backupPwdCtrl = TextEditingController();
    final restoreBytesCtrl = TextEditingController();
    String? exportStatus;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(strings.backupSxsTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.backupSxsDesc,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: masterCtrl,
                      obscureText: true,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: strings.verifyVaultPasswordLabel,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: backupPwdCtrl,
                      obscureText: true,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: strings.backupFilePasswordLabel,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final bytes = await PlatformFileHelper.pickFileBytes(
                            allowedExtensions: ['sxs', 'bin'],
                          );
                          if (bytes != null && bytes.isNotEmpty) {
                            setDialogState(() {
                              restoreBytesCtrl.text = base64Url.encode(bytes);
                            });
                          }
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: Text(strings.pickFileBtn),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: restoreBytesCtrl,
                      minLines: 2,
                      maxLines: 4,
                      enableIMEPersonalizedLearning: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: strings.restoreSxsLabel,
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
                  child: Text(strings.close),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      final bytes =
                          await widget.viewModel.exportSxsEncryptedFile(
                        masterPasswordVerification: masterCtrl.text,
                        backupFilePassword: backupPwdCtrl.text,
                      );
                      PlatformFileHelper.downloadFile(
                        fileName: 'superxsecret_vault_backup.sxs',
                        bytes: bytes,
                        mimeType: 'application/octet-stream',
                      );
                      setDialogState(() {
                        exportStatus = strings.downloadSuccess(
                          'superxsecret_vault_backup.sxs',
                        );
                      });
                    } catch (e) {
                      setDialogState(() {
                        exportStatus = e.toString();
                      });
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(strings.exportSxs),
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
                        exportStatus = strings.backupRestoredSuccess;
                      });
                    } catch (error) {
                      setDialogState(() => exportStatus = error.toString());
                    }
                  },
                  child: Text(strings.restoreSxs),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      masterCtrl.dispose();
      backupPwdCtrl.dispose();
      restoreBytesCtrl.dispose();
    });
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
      double progress;
      double remainingSeconds;
      if (elapsedMs < totalMs) {
        progress = (elapsedMs / totalMs) * 0.90;
        remainingSeconds = (totalMs - elapsedMs) / 1000.0;
      } else {
        final overtimeMs = elapsedMs - totalMs;
        final extra = 0.08 * (1.0 - math.exp(-overtimeMs / 1200.0));
        progress = (0.90 + extra).clamp(0.90, 0.98);
        remainingSeconds =
            (0.3 * math.exp(-overtimeMs / 1200.0)).clamp(0.05, 0.4);
      }
      onUpdate(progress, remainingSeconds);
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

class _NewTopicDialog extends StatefulWidget {
  final VaultViewModel viewModel;
  final VaultItemCategory initialCategory;
  final LicenseController? licenseController;
  final void Function(VaultItemCategory category) onCategorySaved;
  final void Function(BuildContext context, {void Function(String pin)? onPinSaved}) showPinPad;

  const _NewTopicDialog({
    required this.viewModel,
    required this.initialCategory,
    this.licenseController,
    required this.onCategorySaved,
    required this.showPinPad,
  });

  @override
  State<_NewTopicDialog> createState() => _NewTopicDialogState();
}

class _NewTopicDialogState extends State<_NewTopicDialog> {
  late final TextEditingController _topicCtrl;
  late final TextEditingController _secretCtrl;
  late final TextEditingController _hintCtrl;
  late final TextEditingController _itemPasswordCtrl;
  late final TextEditingController _confirmPasswordCtrl;

  late VaultItemCategory _selectedCategory;
  PickedFileData? _pickedFile;
  var _selectedCipher = VaultCipherType.aes256Gcm;
  var _hasExtraLock = false;
  var _passwordEntropyBits = 0.0;
  String? _errorMsg;
  var _isEncoding = false;
  var _encodingPercent = 0.0;
  var _countdownSeconds = 1.0;
  _EncodingProgressTracker? _tracker;

  @override
  void initState() {
    super.initState();
    _topicCtrl = TextEditingController();
    _secretCtrl = TextEditingController();
    _hintCtrl = TextEditingController();
    _itemPasswordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _tracker?.dispose();
    _topicCtrl.dispose();
    _secretCtrl.dispose();
    _hintCtrl.dispose();
    _itemPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLanguageScope.stringsOf(context);

    return AlertDialog(
      title: Text(strings.newTopicTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<VaultItemCategory>(
              initialValue: _selectedCategory,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: strings.categoryLabel,
                isDense: true,
              ),
              items: VaultItemCategory.values.map((cat) {
                final isProOnly = widget.licenseController != null &&
                    !widget.licenseController!.isPro &&
                    cat != VaultItemCategory.text;
                return DropdownMenuItem<VaultItemCategory>(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(
                        _VaultDashboardViewState._categoryIcon(cat),
                        size: 18,
                        color: isProOnly ? AppTheme.textMutedOf(context) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _VaultDashboardViewState._categoryName(cat, strings),
                        style: TextStyle(
                          color: isProOnly ? AppTheme.textMutedOf(context) : null,
                        ),
                      ),
                      if (isProOnly) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.cyberCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.cyberCyan,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  final isPro = widget.licenseController?.isPro ?? false;
                  if (!isPro && val != VaultItemCategory.text) {
                    if (widget.licenseController != null) {
                      ProUpgradeSheet.show(
                        context,
                        licenseController: widget.licenseController!,
                        currentItemCount: widget.viewModel.filteredItems.length,
                      );
                    }
                    return;
                  }
                  setState(() {
                    _selectedCategory = val;
                    _errorMsg = null;
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _topicCtrl,
              enableIMEPersonalizedLearning: false,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: strings.topicFieldLabel,
              ),
            ),
            const SizedBox(height: 10),
            if (_selectedCategory == VaultItemCategory.text)
              TextField(
                controller: _secretCtrl,
                maxLines: 3,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: strings.secretTextFieldLabel,
                  suffixIcon: IconButton(
                    tooltip: strings.pinPad,
                    icon: const Icon(Icons.dialpad_rounded, size: 20),
                    onPressed: () {
                      widget.showPinPad(
                        context,
                        onPinSaved: (pin) {
                          if (mounted) {
                            setState(() {
                              _secretCtrl.text = pin;
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: () async {
                  final String? mimeFilter;
                  switch (_selectedCategory) {
                    case VaultItemCategory.image:
                      mimeFilter = 'image/*';
                      break;
                    case VaultItemCategory.audio:
                      mimeFilter = 'audio/*';
                      break;
                    case VaultItemCategory.video:
                      mimeFilter = 'video/*';
                      break;
                    default:
                      mimeFilter = null;
                  }
                  final file = await PlatformFileHelper.pickAnyFile(
                    mimeTypeFilter: mimeFilter,
                  );
                  if (file != null && mounted) {
                    setState(() {
                      _pickedFile = file;
                      if (_topicCtrl.text.trim().isEmpty) {
                        final dotIndex = file.name.lastIndexOf('.');
                        _topicCtrl.text = dotIndex > 0
                            ? file.name.substring(0, dotIndex)
                            : file.name;
                      }
                      _errorMsg = null;
                    });
                  }
                },
                icon: Icon(
                  _pickedFile == null
                      ? Icons.upload_file_rounded
                      : Icons.check_circle_rounded,
                  color: _pickedFile == null
                      ? null
                      : AppTheme.emeraldSecure,
                ),
                label: Text(
                  _pickedFile == null
                      ? _VaultDashboardViewState._pickFileButtonLabel(_selectedCategory, strings)
                      : strings.fileSelectedInfo(
                          _pickedFile!.name,
                          _VaultDashboardViewState._formatBytes(_pickedFile!.size),
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _secretCtrl,
                maxLines: 2,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: strings.optionalSecretNote,
                ),
              ),
            ],
            const SizedBox(height: 10),
            DropdownButtonFormField<VaultCipherType>(
              initialValue: _selectedCipher,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: strings.encryptionMethod,
                isDense: true,
              ),
              items: VaultCipherType.values.map((cipher) {
                return DropdownMenuItem<VaultCipherType>(
                  value: cipher,
                  child: Text(
                    _VaultDashboardViewState._cipherTypeName(cipher, strings),
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCipher = val);
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasExtraLock,
              title: Text(strings.extraLockSwitch),
              subtitle: Text(strings.extraLockSub),
              onChanged: (value) => setState(() {
                _hasExtraLock = value;
                _errorMsg = null;
              }),
            ),
            if (_hasExtraLock) ...[
              TextField(
                controller: _itemPasswordCtrl,
                obscureText: true,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (value) => setState(() {
                  _passwordEntropyBits =
                      widget.viewModel.estimatePasswordEntropyBits(value);
                }),
                decoration: InputDecoration(
                  labelText: strings.itemPasswordLabel,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordCtrl,
                obscureText: true,
                enableIMEPersonalizedLearning: false,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: strings.confirmPasswordLabel,
                ),
              ),
              const SizedBox(height: 8),
              _VaultDashboardViewState._buildItemPasswordStrength(context, _passwordEntropyBits),
              const SizedBox(height: 8),
              Text(
                strings.extraLockWarning,
                style: const TextStyle(
                  color: AppTheme.amberWarning,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _hintCtrl,
              enableIMEPersonalizedLearning: false,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: _hasExtraLock
                    ? strings.passwordHintLabel
                    : strings.passwordHintOptional,
              ),
            ),
            if (_isEncoding) ...[
              const SizedBox(height: 12),
              _VaultDashboardViewState._buildEncodingProgressWidget(
                context,
                percent: _encodingPercent,
                countdownSeconds: _countdownSeconds,
                title: strings.encodingData,
              ),
            ],
            if (_errorMsg != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMsg!,
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
          onPressed: _isEncoding ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _isEncoding ? null : _submitSave,
          child: _isEncoding
              ? Text('${strings.encodingData} ${(_encodingPercent * 100).toInt()}%...')
              : Text(strings.save),
        ),
      ],
    );
  }

  Future<void> _submitSave() async {
    final strings = AppLanguageScope.stringsOf(context);
    final isPro = widget.licenseController?.isPro ?? false;
    if (!isPro && _selectedCategory != VaultItemCategory.text) {
      if (widget.licenseController != null) {
        await ProUpgradeSheet.show(
          context,
          licenseController: widget.licenseController!,
          currentItemCount: widget.viewModel.filteredItems.length,
        );
      }
      return;
    }

    if (_topicCtrl.text.trim().isEmpty) {
      setState(() {
        _errorMsg = strings.topicNameRequired;
      });
      return;
    }
    if (_selectedCategory == VaultItemCategory.text &&
        _secretCtrl.text.trim().isEmpty) {
      setState(() {
        _errorMsg = strings.topicNameAndSecretRequired;
      });
      return;
    }
    if (_selectedCategory != VaultItemCategory.text &&
        _pickedFile == null) {
      setState(() {
        _errorMsg = _VaultDashboardViewState._pickFileButtonLabel(
          _selectedCategory,
          strings,
        );
      });
      return;
    }
    if (_hasExtraLock &&
        (_itemPasswordCtrl.text.length < 6 ||
            _itemPasswordCtrl.text != _confirmPasswordCtrl.text ||
            _hintCtrl.text.trim().isEmpty)) {
      setState(() {
        _errorMsg = _itemPasswordCtrl.text.length < 6
            ? strings.itemPasswordMinLength
            : _itemPasswordCtrl.text != _confirmPasswordCtrl.text
                ? strings.itemPasswordsDoNotMatch
                : strings.passwordHintRequired;
      });
      return;
    }

    final estimatedMs = kIsWeb
        ? (_hasExtraLock ? 3200 : 2200)
        : (_hasExtraLock ? 1500 : 900);
    setState(() {
      _isEncoding = true;
      _errorMsg = null;
      _encodingPercent = 0.0;
      _countdownSeconds = estimatedMs / 1000.0;
    });

    _tracker = _EncodingProgressTracker(
      estimatedDuration: Duration(milliseconds: estimatedMs),
      onUpdate: (pct, remaining) {
        if (mounted) {
          setState(() {
            _encodingPercent = pct;
            _countdownSeconds = remaining;
          });
        }
      },
    )..start();

    try {
      await widget.viewModel.createTopic(
        topic: _topicCtrl.text,
        secretText: _secretCtrl.text,
        hasExtraLock: _hasExtraLock,
        itemPassword: _hasExtraLock ? _itemPasswordCtrl.text : null,
        passwordHint: _hintCtrl.text,
        cipherType: _selectedCipher,
        category: _selectedCategory,
        fileName: _pickedFile?.name,
        fileSizeBytes: _pickedFile?.size,
        mimeType: _pickedFile?.mimeType,
        rawBytes: _pickedFile?.bytes,
      );
      _tracker?.complete();
      await Future<void>.delayed(
        const Duration(milliseconds: 150),
      );
      if (mounted) {
        widget.onCategorySaved(_selectedCategory);
        Navigator.of(context).pop();
      }
    } catch (e) {
      _tracker?.dispose();
      if (mounted) {
        setState(() {
          _isEncoding = false;
          _errorMsg = e.toString();
        });
      }
    }
  }
}
