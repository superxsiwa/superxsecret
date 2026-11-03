import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english,
  thai,
  system,
}

class AppLanguageController extends ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.system;
  static const _prefKey = 'superxsecret_pref_language';

  AppLanguage get currentLanguage => _currentLanguage;

  Future<void> loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        if (saved == 'thai') {
          _currentLanguage = AppLanguage.thai;
        } else if (saved == 'english') {
          _currentLanguage = AppLanguage.english;
        } else {
          _currentLanguage = AppLanguage.system;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void setLanguage(AppLanguage language) {
    if (_currentLanguage != language) {
      _currentLanguage = language;
      notifyListeners();
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_prefKey, language.name);
      }).catchError((_) {});
    }
  }

  bool isThai(BuildContext context) {
    if (_currentLanguage == AppLanguage.thai) return true;
    if (_currentLanguage == AppLanguage.english) return false;
    try {
      final locale = Localizations.maybeLocaleOf(context) ??
          View.maybeOf(context)?.platformDispatcher.locale ??
          WidgetsBinding.instance.platformDispatcher.locale;
      return locale.languageCode.toLowerCase() == 'th';
    } catch (_) {
      return WidgetsBinding.instance.platformDispatcher.locale.languageCode
              .toLowerCase() ==
          'th';
    }
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
    required this.theme,
    required this.selectTheme,
    required this.lightTheme,
    required this.lightThemeDesc,
    required this.darkTheme,
    required this.darkThemeDesc,
    required this.systemTheme,
    required this.systemThemeDesc,
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
    required this.encryptionMethod,
    required this.cipherAes256Gcm,
    required this.cipherChaCha20Poly1305,
    required this.cipherXChaCha20Poly1305,
    required this.cipherAes256CbcHmacSha512,
    required this.cipherDual,
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
    required this.filePasswordHelper,
    required this.generateRandomPassword,
    required this.downloadFileBtn,
    required this.downloadSuccess,
    required this.pickFileBtn,
    required this.downloadSxsBtn,
    required this.importSuccessWithCipher,
    required this.copyPasswordTooltip,
    required this.passwordCopied,
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
    required this.tabText,
    required this.tabImage,
    required this.tabAudio,
    required this.tabVideo,
    required this.tabFile,
    required this.selectFile,
    required this.selectImage,
    required this.selectAudio,
    required this.selectVideo,
    required this.changeFile,
    required this.fileSelectedInfo,
    required this.downloadDecryptedFile,
    required this.downloadDecryptedImage,
    required this.downloadDecryptedAudio,
    required this.downloadDecryptedVideo,
    required this.noItemsInCategory,
    required this.categoryLabel,
    required this.optionalSecretNote,
    required this.firstRunDisclaimerTitle,
    required this.firstRunDisclaimerSubtitle,
    required this.disclaimerZeroCloudTitle,
    required this.disclaimerZeroCloudDesc,
    required this.disclaimerNoRecoveryTitle,
    required this.disclaimerNoRecoveryDesc,
    required this.disclaimerBackupRequiredTitle,
    required this.disclaimerBackupRequiredDesc,
    required this.disclaimerDualSlotTitle,
    required this.disclaimerDualSlotDesc,
    required this.disclaimerCheckboxLabel,
    required this.disclaimerProceedBtn,
    required this.disclaimerViewNotice,
    required this.emptyVaultTitle,
    required this.emptyVaultSubtitle,
    required this.loadDemoDataBtn,
    required this.loadDemoDataConfirmTitle,
    required this.loadDemoDataConfirmContent,
    required this.demoDataLoadedSnackbar,
    required this.confirmMasterPasswordLabel,
    required this.passwordsDoNotMatch,
    required this.emergencyKitAdvice,
    required this.noBackdoorWarning,
  });

  final String appName;
  final String language;
  final String englishLabel;
  final String thaiLabel;
  final String systemLanguageLabel;
  final String selectLanguage;
  final String theme;
  final String selectTheme;
  final String lightTheme;
  final String lightThemeDesc;
  final String darkTheme;
  final String darkThemeDesc;
  final String systemTheme;
  final String systemThemeDesc;
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
  final String encryptionMethod;
  final String cipherAes256Gcm;
  final String cipherChaCha20Poly1305;
  final String cipherXChaCha20Poly1305;
  final String cipherAes256CbcHmacSha512;
  final String cipherDual;
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
  final String filePasswordHelper;
  final String generateRandomPassword;
  final String downloadFileBtn;
  final String Function(String fileName) downloadSuccess;
  final String pickFileBtn;
  final String downloadSxsBtn;
  final String Function(String topic, String cipher) importSuccessWithCipher;
  final String copyPasswordTooltip;
  final String passwordCopied;
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
  final String tabText;
  final String tabImage;
  final String tabAudio;
  final String tabVideo;
  final String tabFile;
  final String selectFile;
  final String selectImage;
  final String selectAudio;
  final String selectVideo;
  final String changeFile;
  final String Function(String name, String size) fileSelectedInfo;
  final String downloadDecryptedFile;
  final String downloadDecryptedImage;
  final String downloadDecryptedAudio;
  final String downloadDecryptedVideo;
  final String Function(String category) noItemsInCategory;
  final String categoryLabel;
  final String optionalSecretNote;

  // Zero-Knowledge First-Run Onboarding & Clean Vault
  final String firstRunDisclaimerTitle;
  final String firstRunDisclaimerSubtitle;
  final String disclaimerZeroCloudTitle;
  final String disclaimerZeroCloudDesc;
  final String disclaimerNoRecoveryTitle;
  final String disclaimerNoRecoveryDesc;
  final String disclaimerBackupRequiredTitle;
  final String disclaimerBackupRequiredDesc;
  final String disclaimerDualSlotTitle;
  final String disclaimerDualSlotDesc;
  final String disclaimerCheckboxLabel;
  final String disclaimerProceedBtn;
  final String disclaimerViewNotice;
  final String emptyVaultTitle;
  final String emptyVaultSubtitle;
  final String loadDemoDataBtn;
  final String loadDemoDataConfirmTitle;
  final String loadDemoDataConfirmContent;
  final String demoDataLoadedSnackbar;
  final String confirmMasterPasswordLabel;
  final String passwordsDoNotMatch;
  final String emergencyKitAdvice;
  final String noBackdoorWarning;

  static final AppStrings english = AppStrings(
    appName: 'SuperXSecret',
    language: 'Language',
    englishLabel: 'English',
    thaiLabel: 'ไทย (Thai)',
    systemLanguageLabel: 'System language',
    selectLanguage: 'Select Language',
    theme: 'Theme',
    selectTheme: 'Select Theme',
    lightTheme: 'Day (Light)',
    lightThemeDesc: 'Crisp, high-contrast light vault',
    darkTheme: 'Night (Dark)',
    darkThemeDesc: 'OLED obsidian dark vault',
    systemTheme: 'System Default',
    systemThemeDesc: 'Matches device appearance',
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
    searchTopic: 'Search name...',
    newTopicBtn: 'New',
    noTopicsFound: 'No items found',
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
    newTopicTitle: 'New',
    topicFieldLabel: 'Name',
    secretTextFieldLabel: 'Secret Text',
    encryptionMethod: 'Encryption Method',
    cipherAes256Gcm: 'AES-256-GCM (NIST Standard)',
    cipherChaCha20Poly1305: 'ChaCha20-Poly1305 (High-Speed)',
    cipherXChaCha20Poly1305: 'XChaCha20-Poly1305 (Extended Nonce)',
    cipherAes256CbcHmacSha512: 'AES-256-CBC + HMAC-SHA512',
    cipherDual: 'Dual-Cipher (AES-256 + XChaCha20)',
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
        'Set a password to lock this shared file. The recipient will need this password to import it.',
    filePasswordLabel: 'File Password (set for recipient)',
    filePasswordHelper: 'Create a password for this file',
    generateRandomPassword: 'Random Password',
    downloadFileBtn: 'Download .sxsi File',
    downloadSuccess: (name) => 'File "$name" downloaded successfully.',
    pickFileBtn: 'Choose File (.sxsi)',
    downloadSxsBtn: 'Download .sxs Backup',
    importSuccessWithCipher: (topic, cipher) =>
        'Imported "$topic" successfully (Cipher: $cipher)',
    copyPasswordTooltip: 'Copy File Password',
    passwordCopied: 'File Password copied to clipboard',
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
    tabText: 'Text',
    tabImage: 'Images',
    tabAudio: 'Audio',
    tabVideo: 'Videos',
    tabFile: 'Files',
    selectFile: 'Select File',
    selectImage: 'Select Image',
    selectAudio: 'Select Audio',
    selectVideo: 'Select Video',
    changeFile: 'Change File',
    fileSelectedInfo: (name, size) => '$name ($size)',
    downloadDecryptedFile: 'Download File',
    downloadDecryptedImage: 'Download Image',
    downloadDecryptedAudio: 'Download Audio',
    downloadDecryptedVideo: 'Download Video',
    noItemsInCategory: (category) => 'No $category found',
    categoryLabel: 'Category',
    optionalSecretNote: 'Optional note or description',
    firstRunDisclaimerTitle: 'Zero-Knowledge Security Notice',
    firstRunDisclaimerSubtitle:
        '100% Offline, Zero Servers & No Cloud Recovery',
    disclaimerZeroCloudTitle: '100% Offline & Zero Network',
    disclaimerZeroCloudDesc:
        'Your secrets never leave this device. Zero servers, zero analytics, zero network permissions.',
    disclaimerNoRecoveryTitle: 'Zero Password Recovery',
    disclaimerNoRecoveryDesc:
        'If you forget your password, all vault data is lost forever. Even the creators and developers have ZERO backdoor access and cannot decrypt or recover your data under any circumstance.',
    disclaimerBackupRequiredTitle: 'Regular Offline Backups',
    disclaimerBackupRequiredDesc:
        'Export your encrypted .sxs backup to a secure USB drive or cold storage to protect against device loss.',
    disclaimerDualSlotTitle: 'Dual-Vault Plausible Deniability',
    disclaimerDualSlotDesc:
        'Set a Master Password for real data and a Secondary PIN to reveal a decoy vault if coerced.',
    disclaimerCheckboxLabel:
        'I understand this is a zero-knowledge offline vault: even the developers have no backdoor and cannot recover my data if the password is lost.',
    disclaimerProceedBtn: 'I Understand & Proceed',
    disclaimerViewNotice: 'Security Notice',
    emptyVaultTitle: 'Your Vault is Empty',
    emptyVaultSubtitle:
        'Tap "New" above to add your first password, secret note, or encrypted file.',
    loadDemoDataBtn: 'Load Demo Data',
    loadDemoDataConfirmTitle: 'Load Sample Demo Data?',
    loadDemoDataConfirmContent:
        'This will populate sample mock items (e.g. sample card, demo secret) so you can test all features safely.',
    demoDataLoadedSnackbar: 'Sample demo data loaded successfully',
    confirmMasterPasswordLabel: 'Confirm Master Password',
    passwordsDoNotMatch: 'Master password and confirmation password do not match',
    emergencyKitAdvice:
        'Critical: Write down your password and keep it in a secure offline physical location (Emergency Sheet).',
    noBackdoorWarning:
        'Zero Backdoor: Even the creators cannot decrypt or recover your vault.',
  );

  static final AppStrings thai = AppStrings(
    appName: 'SuperXSecret',
    language: 'ภาษา',
    englishLabel: 'English',
    thaiLabel: 'ไทย (Thai)',
    systemLanguageLabel: 'ภาษาตามระบบ',
    selectLanguage: 'เลือกภาษา (Select Language)',
    theme: 'ธีม',
    selectTheme: 'เลือกธีม (Select Theme)',
    lightTheme: 'กลางวัน (Light)',
    lightThemeDesc: 'ธีมสว่าง คมชัด มองเห็นง่าย',
    darkTheme: 'กลางคืน (Dark)',
    darkThemeDesc: 'ธีมมืด ออบซิเดียน ถนอมสายตา ปลอดภัย',
    systemTheme: 'ตามระบบ (System)',
    systemThemeDesc: 'เปลี่ยนตามการตั้งค่าของอุปกรณ์',
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
    searchTopic: 'ค้นหาชื่อ...',
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
    newTopicTitle: 'สร้างใหม่ (New)',
    topicFieldLabel: 'ชื่อ (Name)',
    secretTextFieldLabel: 'ข้อความความลับ (Secret Text)',
    encryptionMethod: 'วิธีการเข้ารหัส (Cipher)',
    cipherAes256Gcm: 'AES-256-GCM (มาตรฐานหลักสากล)',
    cipherChaCha20Poly1305: 'ChaCha20-Poly1305 (ความเร็วสูง / Google)',
    cipherXChaCha20Poly1305: 'XChaCha20-Poly1305 (สุ่ม Nonce 192-bit ปลอดภัยสูง)',
    cipherAes256CbcHmacSha512: 'AES-256-CBC + SHA512 (ตรวจจับการปลอมแปลง 512-bit)',
    cipherDual: 'Dual-Cipher (เข้ารหัสซ้อน 2 ชั้น ป้องกันขั้นสูงสุด)',
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
        'กำหนดรหัสผ่านใหม่เพื่อล็อกไฟล์แชร์นี้ (ผู้รับจะต้องใช้รหัสผ่านนี้ในการเปิดนำเข้าไฟล์)',
    filePasswordLabel: 'รหัสผ่านไฟล์ (กำหนดเพื่อให้ผู้รับใช้เปิด)',
    filePasswordHelper: 'ตั้งรหัสผ่านใหม่เฉพาะสำหรับไฟล์นี้',
    generateRandomPassword: 'สุ่มรหัสผ่าน',
    downloadFileBtn: 'ดาวน์โหลดไฟล์ .sxsi',
    downloadSuccess: (name) => 'ดาวน์โหลดไฟล์ "$name" เรียบร้อยแล้ว',
    pickFileBtn: 'เลือกไฟล์ (.sxsi)',
    downloadSxsBtn: 'ดาวน์โหลดไฟล์สำรอง .sxs',
    importSuccessWithCipher: (topic, cipher) =>
        'นำเข้า "$topic" สำเร็จแล้ว (รูปแบบการเข้ารหัส: $cipher)',
    copyPasswordTooltip: 'คัดลอกรหัสผ่านไฟล์',
    passwordCopied: 'คัดลอกรหัสผ่านไฟล์เรียบร้อยแล้ว',
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
    tabText: 'ข้อความ',
    tabImage: 'รูปภาพ',
    tabAudio: 'ไฟล์เสียง',
    tabVideo: 'วิดีโอ',
    tabFile: 'ไฟล์ทั่วไป',
    selectFile: 'เลือกไฟล์',
    selectImage: 'เลือกรูปภาพ',
    selectAudio: 'เลือกไฟล์เสียง',
    selectVideo: 'เลือกไฟล์วิดีโอ',
    changeFile: 'เปลี่ยนไฟล์',
    fileSelectedInfo: (name, size) => '$name ($size)',
    downloadDecryptedFile: 'ดาวน์โหลดไฟล์',
    downloadDecryptedImage: 'ดาวน์โหลดรูปภาพ',
    downloadDecryptedAudio: 'ดาวน์โหลดไฟล์เสียง',
    downloadDecryptedVideo: 'ดาวน์โหลดวิดีโอ',
    noItemsInCategory: (category) => 'ยังไม่มีข้อมูลในหมวดหมู่ $category',
    categoryLabel: 'หมวดหมู่',
    optionalSecretNote: 'บันทึกหรือข้อความประกอบ (ไม่บังคับ)',
    firstRunDisclaimerTitle: 'ข้อกำหนดความปลอดภัย Zero-Knowledge',
    firstRunDisclaimerSubtitle:
        'ออฟไลน์ 100% ไร้เซิร์ฟเวอร์ และไม่มีการกู้คืนบนคลาวด์',
    disclaimerZeroCloudTitle: 'ออฟไลน์ 100% ปราศจากอินเทอร์เน็ต',
    disclaimerZeroCloudDesc:
        'ข้อมูลของคุณไม่เคยออกจากเครื่องนี้ ไม่มีเซิร์ฟเวอร์ ไม่มีการส่งข้อมูล หรือเก็บสถิติใดๆ ทั้งสิ้น',
    disclaimerNoRecoveryTitle: 'ไม่สามารถกู้คืนรหัสผ่านได้ทุกกรณี',
    disclaimerNoRecoveryDesc:
        'หากคุณลืมรหัสผ่าน ข้อมูลทั้งหมดจะสูญหายถาวรทันที แม้แต่ทีมผู้พัฒนาหรือซูเปอร์คอมพิวเตอร์ก็ไม่มีกุญแจสำรอง (No Backdoor) และไม่สามารถถอดรหัสให้คุณได้ในทุกกรณี',
    disclaimerBackupRequiredTitle: 'หมั่นสำรองข้อมูลแบบออฟไลน์',
    disclaimerBackupRequiredDesc:
        'ส่งออกไฟล์สำรอง .sxs ที่เข้ารหัสไว้ไปยังแฟลชไดรฟ์หรือ Cold Storage เพื่อความปลอดภัยหากอุปกรณ์สูญหาย',
    disclaimerDualSlotTitle: 'ระบบคลังคู่ ป้องกันการถูกบีบบังคับ',
    disclaimerDualSlotDesc:
        'คุณสามารถตั้งรหัสหลักสำหรับข้อมูลจริง และรหัสสำรองสำหรับเปิดคลังลวงเมื่อตกอยู่ในสถานการณ์ถูกคุกคาม',
    disclaimerCheckboxLabel:
        'ข้าพเจ้าเข้าใจและยอมรับว่านี่คือระบบ Zero-Knowledge: แม้แต่ผู้ผลิตก็ไม่มีกุญแจสำรอง และไม่สามารถช่วยกู้คืนข้อมูลได้หากลืมรหัสผ่าน',
    disclaimerProceedBtn: 'ข้าพเจ้าเข้าใจและพร้อมตั้งค่า',
    disclaimerViewNotice: 'ข้อกำหนดความปลอดภัย',
    emptyVaultTitle: 'คลังนิรภัยยังว่างอยู่',
    emptyVaultSubtitle:
        'กดปุ่ม "เพิ่มใหม่" ด้านบนเพื่อเริ่มบันทึกรหัสผ่านหรือความลับแรกของคุณ',
    loadDemoDataBtn: 'โหลดข้อมูลตัวอย่าง',
    loadDemoDataConfirmTitle: 'ต้องการโหลดข้อมูลตัวอย่างหรือไม่?',
    loadDemoDataConfirmContent:
        'ระบบจะเพิ่มรายการตัวอย่าง (เช่น บัตรทดลอง, รหัสผ่านตัวอย่าง) ลงในคลัง เพื่อให้คุณทดลองใช้งานฟังก์ชันต่างๆ ได้อย่างครบถ้วน',
    demoDataLoadedSnackbar: 'โหลดข้อมูลตัวอย่างสำเร็จ',
    confirmMasterPasswordLabel: 'ยืนยันรหัสผ่านหลัก (Confirm Master Password)',
    passwordsDoNotMatch: 'รหัสผ่านหลักและรหัสผ่านยืนยันไม่ตรงกัน',
    emergencyKitAdvice:
        'คำเตือนสำคัญ: โปรดจดรหัสผ่านไว้ในสมุดหรือพื้นที่ปลอดภัยภายนอก (Emergency Sheet) ทันที',
    noBackdoorWarning:
        'ไม่มี Backdoor: แม้แต่ผู้ผลิตก็ไม่สามารถถอดรหัสหรือกู้คืนข้อมูลให้ท่านได้',
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
