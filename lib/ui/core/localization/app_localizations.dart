import 'package:flutter/material.dart';

enum AppLanguage {
  english,
  thai,
  system,
}

class AppLanguageController extends ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.system;

  AppLanguage get currentLanguage => _currentLanguage;

  void setLanguage(AppLanguage language) {
    if (_currentLanguage != language) {
      _currentLanguage = language;
      notifyListeners();
    }
  }

  bool isThai(BuildContext context) {
    if (_currentLanguage == AppLanguage.thai) return true;
    if (_currentLanguage == AppLanguage.english) return false;
    final locale = View.of(context).platformDispatcher.locale;
    return locale.languageCode.toLowerCase() == 'th';
  }

  AppStrings strings(BuildContext context) {
    return isThai(context) ? AppStrings.thai : AppStrings.english;
  }
}

class AppLanguageScope extends InheritedWidget {
  const AppLanguageScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final AppLanguageController controller;
  static final AppLanguageController _defaultController =
      AppLanguageController();

  static AppLanguageController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    return scope?.controller ?? _defaultController;
  }

  static AppStrings stringsOf(BuildContext context) {
    return of(context).strings(context);
  }

  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) =>
      controller != oldWidget.controller;
}

class AppStrings {
  const AppStrings({
    required this.appName,
    required this.language,
    required this.englishLabel,
    required this.thaiLabel,
    required this.systemLanguageLabel,
    required this.selectLanguage,
    required this.cancel,
    required this.save,
    required this.close,
    required this.unlock,
    required this.copy,
    required this.copied,
    required this.clear,
    required this.delete,
    required this.verifiedOffline,
    required this.zeroKnowledgeSecurity,
    required this.aes256Argon2id,
    required this.masterPasswordLabel,
    required this.masterPasswordHint,
    required this.decoyPasswordHelper,
    required this.secondaryPasswordLabel,
    required this.secondaryPasswordHelper,
    required this.passwordHintLabel,
    required this.passwordHintOptional,
    required this.unlockVault,
    required this.unlocking,
    required this.scrambledPinPad,
    required this.scrambledPinPadDesc,
    required this.tapDigitsBelow,
    required this.reshuffle,
    required this.setupDualSlot,
    required this.switchUnlock,
    required this.entropyWeak,
    required this.entropyGood,
    required this.entropyStrong,
    required this.entropyLabel,
    required this.searchTopic,
    required this.newTopicBtn,
    required this.noTopicsFound,
    required this.importSxsi,
    required this.backupSxs,
    required this.pinPad,
    required this.lockVault,
    required this.secretText,
    required this.autoHide,
    required this.view,
    required this.opening,
    required this.share,
    required this.deleteTopic,
    required this.itemLockTooltip,
    required this.addExtraLock,
    required this.changeItemPassword,
    required this.removeItemExtraLock,
    required this.deleteItemMenu,
    required this.deleteConfirmTitle,
    required this.deleteConfirmContent,
    required this.deletedSnackbar,
    required this.newTopicTitle,
    required this.topicFieldLabel,
    required this.secretTextFieldLabel,
    required this.extraLockSwitch,
    required this.extraLockSub,
    required this.itemPasswordLabel,
    required this.confirmPasswordLabel,
    required this.extraLockWarning,
    required this.encodingData,
    required this.decodingData,
    required this.reEncryptingItem,
    required this.encodingSxsiContainer,
    required this.secondsLeft,
    required this.enterItemPasswordTitle,
    required this.unlockToContinue,
    required this.enterPasswordTitle,
    required this.updateToCurrentPassword,
    required this.shareSxsiTitle,
    required this.shareSxsiDesc,
    required this.filePasswordLabel,
    required this.createSxsi,
    required this.importSxsiTitle,
    required this.sxsiContentLabel,
    required this.importBtn,
    required this.backupSxsTitle,
    required this.backupSxsDesc,
    required this.verifyVaultPasswordLabel,
    required this.backupFilePasswordLabel,
    required this.restoreSxsLabel,
    required this.exportSxs,
    required this.restoreSxs,
  });

  final String appName;
  final String language;
  final String englishLabel;
  final String thaiLabel;
  final String systemLanguageLabel;
  final String selectLanguage;
  final String cancel;
  final String save;
  final String close;
  final String unlock;
  final String copy;
  final String copied;
  final String clear;
  final String delete;

  // Lock Screen
  final String verifiedOffline;
  final String zeroKnowledgeSecurity;
  final String aes256Argon2id;
  final String masterPasswordLabel;
  final String masterPasswordHint;
  final String decoyPasswordHelper;
  final String secondaryPasswordLabel;
  final String secondaryPasswordHelper;
  final String passwordHintLabel;
  final String passwordHintOptional;
  final String unlockVault;
  final String unlocking;
  final String scrambledPinPad;
  final String scrambledPinPadDesc;
  final String tapDigitsBelow;
  final String reshuffle;
  final String setupDualSlot;
  final String switchUnlock;
  final String entropyWeak;
  final String entropyGood;
  final String entropyStrong;
  final String entropyLabel;

  // Dashboard
  final String searchTopic;
  final String newTopicBtn;
  final String noTopicsFound;
  final String importSxsi;
  final String backupSxs;
  final String pinPad;
  final String lockVault;
  final String secretText;
  final String Function(String sec) autoHide;
  final String view;
  final String opening;
  final String share;
  final String deleteTopic;
  final String itemLockTooltip;
  final String addExtraLock;
  final String changeItemPassword;
  final String removeItemExtraLock;
  final String deleteItemMenu;
  final String deleteConfirmTitle;
  final String Function(String topic) deleteConfirmContent;
  final String Function(String topic) deletedSnackbar;

  // Dialogs
  final String newTopicTitle;
  final String topicFieldLabel;
  final String secretTextFieldLabel;
  final String extraLockSwitch;
  final String extraLockSub;
  final String itemPasswordLabel;
  final String confirmPasswordLabel;
  final String extraLockWarning;
  final String encodingData;
  final String decodingData;
  final String reEncryptingItem;
  final String encodingSxsiContainer;
  final String Function(String sec) secondsLeft;
  final String enterItemPasswordTitle;
  final String Function(String topic) unlockToContinue;
  final String enterPasswordTitle;
  final String updateToCurrentPassword;
  final String Function(String topic) shareSxsiTitle;
  final String shareSxsiDesc;
  final String filePasswordLabel;
  final String createSxsi;
  final String importSxsiTitle;
  final String sxsiContentLabel;
  final String importBtn;
  final String backupSxsTitle;
  final String backupSxsDesc;
  final String verifyVaultPasswordLabel;
  final String backupFilePasswordLabel;
  final String restoreSxsLabel;
  final String exportSxs;
  final String restoreSxs;

  static final AppStrings english = AppStrings(
    appName: 'SuperXSecret',
    language: 'Language',
    englishLabel: 'English',
    thaiLabel: 'ไทย (Thai)',
    systemLanguageLabel: 'System language',
    selectLanguage: 'Select Language',
    cancel: 'Cancel',
    save: 'Save',
    close: 'Close',
    unlock: 'Unlock',
    copy: 'Copy',
    copied: 'Copied to clipboard',
    clear: 'Clear',
    delete: 'Delete',
    verifiedOffline:
        'VERIFIED 0 INTERNET PERMISSIONS • SQLCIPHER 4 + RUST FFI',
    zeroKnowledgeSecurity: 'Zero-Knowledge Security',
    aes256Argon2id: 'AES-256-GCM • Argon2id KDF • In-Memory Zeroization',
    masterPasswordLabel: 'Master Password',
    masterPasswordHint: 'Enter Master Password',
    decoyPasswordHelper: 'Or enter Decoy PIN...',
    secondaryPasswordLabel: 'Secondary Password',
    secondaryPasswordHelper: 'Opens a separate Secondary Vault',
    passwordHintLabel: 'Password Hint',
    passwordHintOptional: 'Password Hint (Optional)',
    unlockVault: 'Unlock Vault',
    unlocking: 'Unlocking...',
    scrambledPinPad: 'Scrambled PIN Pad',
    scrambledPinPadDesc:
        'Randomized key layout prevents shoulder surfing & smudge analysis',
    tapDigitsBelow: 'Tap digits below',
    reshuffle: 'Reshuffle',
    setupDualSlot: 'Setup Dual-Slot Vault',
    switchUnlock: 'Back to Unlock',
    entropyWeak: 'Weak',
    entropyGood: 'Good',
    entropyStrong: 'Strong',
    entropyLabel: 'Password strength',
    searchTopic: 'Search topic...',
    newTopicBtn: 'New',
    noTopicsFound: 'No topics found',
    importSxsi: 'Import (.sxsi)',
    backupSxs: 'Backup (.sxs)',
    pinPad: 'PIN',
    lockVault: 'Lock',
    secretText: 'Secret Text',
    autoHide: (sec) => 'Auto-hide in ${sec}s',
    view: 'View',
    opening: 'Opening...',
    share: 'Share',
    deleteTopic: 'Delete',
    itemLockTooltip: 'Item lock',
    addExtraLock: 'Add Extra Lock',
    changeItemPassword: 'Change Item Password',
    removeItemExtraLock: 'Remove Extra Lock',
    deleteItemMenu: 'Delete Item',
    deleteConfirmTitle: 'Delete Item',
    deleteConfirmContent: (topic) =>
        'Are you sure you want to permanently delete "$topic"? This action cannot be undone.',
    deletedSnackbar: (topic) => 'Deleted "$topic"',
    newTopicTitle: 'New Topic',
    topicFieldLabel: 'Topic',
    secretTextFieldLabel: 'Secret Text',
    extraLockSwitch: '🔒 Extra Lock (Separate Password)',
    extraLockSub: 'Require a separate password to reveal this item.',
    itemPasswordLabel: 'Item Password',
    confirmPasswordLabel: 'Confirm Password',
    extraLockWarning:
        'If you forget this password, the item cannot be recovered.',
    encodingData: 'Encoding data...',
    decodingData: 'Decoding data...',
    reEncryptingItem: 'Re-encrypting item...',
    encodingSxsiContainer: 'Encoding .sxsi container...',
    secondsLeft: (sec) => '${sec}s left',
    enterItemPasswordTitle: 'Enter Item Password',
    unlockToContinue: (topic) => 'Unlock "$topic" to continue.',
    enterPasswordTitle: 'Enter Password',
    updateToCurrentPassword: 'Update to Current Password',
    shareSxsiTitle: (topic) => 'Share "$topic" (.sxsi)',
    shareSxsiDesc:
        'Encrypts this single topic with a File Password ("SXSI" header + Argon2id + AES-256-GCM).',
    filePasswordLabel: 'File Password',
    createSxsi: 'Create .sxsi',
    importSxsiTitle: 'Import File (.sxsi)',
    sxsiContentLabel: '.sxsi File Content',
    importBtn: 'Import',
    backupSxsTitle: 'Backup (.sxs)',
    backupSxsDesc:
        'Full Vault Backup ("SXSV" 64B Header + Argon2id + AES-256-GCM)',
    verifyVaultPasswordLabel: 'Verify Vault Password',
    backupFilePasswordLabel: 'Backup File Password',
    restoreSxsLabel: 'Restore .sxs (Base64 URL)',
    exportSxs: 'Export .sxs',
    restoreSxs: 'Restore .sxs',
  );

  static final AppStrings thai = AppStrings(
    appName: 'SuperXSecret',
    language: 'ภาษา',
    englishLabel: 'English',
    thaiLabel: 'ไทย (Thai)',
    systemLanguageLabel: 'ภาษาตามระบบ',
    selectLanguage: 'เลือกภาษา (Select Language)',
    cancel: 'ยกเลิก',
    save: 'บันทึก',
    close: 'ปิด',
    unlock: 'ปลดล็อก',
    copy: 'คัดลอก',
    copied: 'คัดลอกลงคลิปบอร์ดแล้ว',
    clear: 'ล้าง',
    delete: 'ลบ',
    verifiedOffline:
        'ปลอดภัย 100% ไม่ใช้อินเทอร์เน็ต • SQLCIPHER 4 + RUST FFI',
    zeroKnowledgeSecurity: 'ความปลอดภัย Zero-Knowledge',
    aes256Argon2id: 'AES-256-GCM • Argon2id KDF • ล้างหน่วยความจำทันที',
    masterPasswordLabel: 'รหัสผ่านหลัก (Master Password)',
    masterPasswordHint: 'กรอกรหัสผ่านหลัก',
    decoyPasswordHelper: 'หรือกรอกรหัสสำรอง (Decoy)...',
    secondaryPasswordLabel: 'รหัสผ่านห้องนิรภัยสำรอง (Slot B)',
    secondaryPasswordHelper: 'เปิดห้องนิรภัยสำรองที่แยกต่างหาก',
    passwordHintLabel: 'คำใบ้รหัสผ่าน',
    passwordHintOptional: 'คำใบ้รหัสผ่าน (ไม่บังคับ)',
    unlockVault: 'ปลดล็อกห้องนิรภัย',
    unlocking: 'กำลังปลดล็อก...',
    scrambledPinPad: 'แป้นตัวเลขสุ่มตำแหน่ง',
    scrambledPinPadDesc:
        'สุ่มตำแหน่งแป้นตัวเลขทุกครั้ง ป้องกันการแอบมองและวิเคราะห์รอยนิ้วมือ',
    tapDigitsBelow: 'แตะตัวเลขด้านล่าง',
    reshuffle: 'สุ่มตำแหน่งใหม่',
    setupDualSlot: 'ตั้งค่าห้องนิรภัย 2 ชั้น',
    switchUnlock: 'กลับไปหน้าปลดล็อก',
    entropyWeak: 'ระดับง่าย',
    entropyGood: 'ระดับปานกลาง',
    entropyStrong: 'ระดับแข็งแกร่ง',
    entropyLabel: 'ความแข็งแกร่งของรหัสผ่าน',
    searchTopic: 'ค้นหารายการ...',
    newTopicBtn: 'เพิ่มใหม่',
    noTopicsFound: 'ไม่พบรายการที่ค้นหา',
    importSxsi: 'นำเข้า (.sxsi)',
    backupSxs: 'สำรอง (.sxs)',
    pinPad: 'แป้นสุ่ม',
    lockVault: 'ล็อก',
    secretText: 'ข้อความความลับ',
    autoHide: (sec) => 'ซ่อนอัตโนมัติใน $sec วิ',
    view: 'เปิดดู',
    opening: 'กำลังเปิด...',
    share: 'แชร์',
    deleteTopic: 'ลบ',
    itemLockTooltip: 'การล็อกรายการ',
    addExtraLock: 'เพิ่มรหัสล็อกชั้นที่สอง',
    changeItemPassword: 'เปลี่ยนรหัสผ่านเฉพาะรายการ',
    removeItemExtraLock: 'ยกเลิกรหัสล็อกชั้นที่สอง',
    deleteItemMenu: 'ลบรายการ',
    deleteConfirmTitle: 'ยืนยันการลบรายการ',
    deleteConfirmContent: (topic) =>
        'คุณแน่ใจหรือไม่ว่าต้องการลบ "$topic" ถาวร? การกระทำนี้ไม่สามารถย้อนคืนได้',
    deletedSnackbar: (topic) => 'ลบ "$topic" เรียบร้อยแล้ว',
    newTopicTitle: 'สร้างรายการใหม่',
    topicFieldLabel: 'หัวข้อ (Topic)',
    secretTextFieldLabel: 'ข้อความความลับ (Secret Text)',
    extraLockSwitch: '🔒 รหัสล็อกชั้นที่สอง (Extra Lock)',
    extraLockSub: 'ต้องใช้รหัสผ่านเฉพาะรายการนี้ในการเปิดดูข้อมูล',
    itemPasswordLabel: 'รหัสผ่านเฉพาะรายการ',
    confirmPasswordLabel: 'ยืนยันรหัสผ่าน',
    extraLockWarning:
        'หากลืมรหัสผ่านนี้ ข้อมูลรายการนี้จะไม่สามารถกู้คืนได้ทุกกรณี',
    encodingData: 'กำลังเข้ารหัสข้อมูล...',
    decodingData: 'กำลังถอดรหัสข้อมูล...',
    reEncryptingItem: 'กำลังเข้ารหัสข้อมูลใหม่...',
    encodingSxsiContainer: 'กำลังสร้างไฟล์ .sxsi...',
    secondsLeft: (sec) => 'เหลือ $sec วิ',
    enterItemPasswordTitle: 'กรอกรหัสผ่านเฉพาะรายการ',
    unlockToContinue: (topic) => 'ปลดล็อก "$topic" เพื่อดำเนินการต่อ',
    enterPasswordTitle: 'กรอกรหัสผ่าน',
    updateToCurrentPassword: 'อัปเดตเป็นรหัสผ่านปัจจุบัน',
    shareSxsiTitle: (topic) => 'แชร์ "$topic" (.sxsi)',
    shareSxsiDesc:
        'เข้ารหัสรายการนี้เดี่ยวๆ ด้วยรหัสผ่านไฟล์ ("SXSI" + Argon2id + AES-256-GCM)',
    filePasswordLabel: 'รหัสผ่านไฟล์ (File Password)',
    createSxsi: 'สร้างไฟล์ .sxsi',
    importSxsiTitle: 'นำเข้าไฟล์ (.sxsi)',
    sxsiContentLabel: 'เนื้อหาไฟล์ .sxsi (Base64)',
    importBtn: 'นำเข้า',
    backupSxsTitle: 'สำรองข้อมูล (.sxs)',
    backupSxsDesc:
        'สำรองข้อมูลทั้งห้องนิรภัย ("SXSV" 64B + Argon2id + AES-256-GCM)',
    verifyVaultPasswordLabel: 'ยืนยันรหัสผ่านห้องนิรภัยหลัก',
    backupFilePasswordLabel: 'รหัสผ่านไฟล์สำรอง (Backup Password)',
    restoreSxsLabel: 'กู้คืนข้อมูล .sxs (Base64 URL)',
    exportSxs: 'ส่งออก .sxs',
    restoreSxs: 'กู้คืน .sxs',
  );
}

void showLanguageSelectionDialog(
  BuildContext context,
  AppLanguageController controller,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final strings = controller.strings(context);
      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.language_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text(strings.selectLanguage),
          ],
        ),
        content: RadioGroup<AppLanguage>(
          groupValue: controller.currentLanguage,
          onChanged: (lang) {
            if (lang != null) controller.setLanguage(lang);
            Navigator.of(ctx).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RadioListTile<AppLanguage>(
                value: AppLanguage.english,
                title: Text('English'),
                subtitle: Text('English (US)'),
              ),
              const RadioListTile<AppLanguage>(
                value: AppLanguage.thai,
                title: Text('ไทย (Thai)'),
                subtitle: Text('ภาษาไทย'),
              ),
              RadioListTile<AppLanguage>(
                value: AppLanguage.system,
                title: Text(strings.systemLanguageLabel),
                subtitle: Text(
                  View.of(context).platformDispatcher.locale.languageCode ==
                          'th'
                      ? 'ภาษาตามระบบ (ไทย)'
                      : 'System language (English)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.cancel),
          ),
        ],
      );
    },
  );
}
