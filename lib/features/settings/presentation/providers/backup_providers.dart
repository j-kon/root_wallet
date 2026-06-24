import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/backup_encryption_service.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

class BackupState {
  const BackupState({
    required this.isProcessing,
    this.lastBackupTime,
    this.errorMessage,
    this.successMessage,
  });

  final bool isProcessing;
  final DateTime? lastBackupTime;
  final String? errorMessage;
  final String? successMessage;

  BackupState copyWith({
    bool? isProcessing,
    DateTime? lastBackupTime,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return BackupState(
      isProcessing: isProcessing ?? this.isProcessing,
      lastBackupTime: lastBackupTime ?? this.lastBackupTime,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class BackupController extends StateNotifier<BackupState> {
  BackupController(this.ref) : super(const BackupState(isProcessing: false)) {
    _init();
  }

  final Ref ref;
  static const _lastBackupKey = 'settings.last_backup_time';

  Future<void> _init() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final timeStr = prefs.getString(_lastBackupKey);
    if (timeStr != null) {
      state = state.copyWith(lastBackupTime: DateTime.tryParse(timeStr));
    }
  }

  Future<String?> _getMnemonic() async {
    final bdkService = ref.read(bdkWalletServiceProvider);
    final secureStorage = ref.read(secureStorageProvider);
    final key = bdkService.isDecoyActive
        ? WalletStorageKeys.decoyMnemonic
        : WalletStorageKeys.mnemonic;
    return secureStorage.read(key: key);
  }

  Future<void> backupToFile() async {
    state = state.copyWith(isProcessing: true, clearError: true, clearSuccess: true);
    try {
      final mnemonic = await _getMnemonic();
      if (mnemonic == null) {
        throw Exception('Mnemonic is not initialized.');
      }

      final labelsSnapshot = ref.read(walletLabelsControllerProvider).valueOrNull ?? const WalletLabelsSnapshot();
      final plainText = jsonEncode(labelsSnapshot.toJson());

      final encrypted = BackupEncryptionService.encrypt(plainText: plainText, mnemonic: mnemonic);

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/backup.enc');
      await file.writeAsString(encrypted);

      final prefs = await ref.read(sharedPreferencesProvider.future);
      final now = DateTime.now();
      await prefs.setString(_lastBackupKey, now.toIso8601String());

      state = state.copyWith(
        isProcessing: false,
        lastBackupTime: now,
        successMessage: 'Metadata backup file saved successfully.',
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: 'Backup failed: $e');
    }
  }

  Future<bool> restoreFromFile() async {
    state = state.copyWith(isProcessing: true, clearError: true, clearSuccess: true);
    try {
      final mnemonic = await _getMnemonic();
      if (mnemonic == null) {
        throw Exception('Mnemonic is not initialized.');
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/backup.enc');
      if (!await file.exists()) {
        throw Exception('No backup file found.');
      }

      final encrypted = await file.readAsString();

      final plainText = BackupEncryptionService.decrypt(encryptedCombinedBase64: encrypted, mnemonic: mnemonic);
      final Map<String, dynamic> decoded = jsonDecode(plainText);

      final store = await ref.read(walletLabelStoreProvider.future);
      final newSnapshot = WalletLabelsSnapshot.fromJson(decoded.cast<String, Object?>());
      await store.write(newSnapshot);
      ref.invalidate(walletLabelsControllerProvider);

      state = state.copyWith(
        isProcessing: false,
        successMessage: 'Metadata restored successfully from backup file.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: 'Restore failed: $e');
      return false;
    }
  }

  Future<String?> exportToBase64() async {
    state = state.copyWith(isProcessing: true, clearError: true, clearSuccess: true);
    try {
      final mnemonic = await _getMnemonic();
      if (mnemonic == null) {
        throw Exception('Mnemonic is not initialized.');
      }

      final labelsSnapshot = ref.read(walletLabelsControllerProvider).valueOrNull ?? const WalletLabelsSnapshot();
      final plainText = jsonEncode(labelsSnapshot.toJson());

      final encrypted = BackupEncryptionService.encrypt(plainText: plainText, mnemonic: mnemonic);
      state = state.copyWith(
        isProcessing: false,
        successMessage: 'Export generated successfully. Copied payload to clipboard.',
      );
      return encrypted;
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: 'Export failed: $e');
      return null;
    }
  }

  Future<bool> importFromBase64(String encryptedBase64) async {
    state = state.copyWith(isProcessing: true, clearError: true, clearSuccess: true);
    try {
      final mnemonic = await _getMnemonic();
      if (mnemonic == null) {
        throw Exception('Mnemonic is not initialized.');
      }

      final plainText = BackupEncryptionService.decrypt(
        encryptedCombinedBase64: encryptedBase64,
        mnemonic: mnemonic,
      );
      final Map<String, dynamic> decoded = jsonDecode(plainText);

      final store = await ref.read(walletLabelStoreProvider.future);
      final newSnapshot = WalletLabelsSnapshot.fromJson(decoded.cast<String, Object?>());
      await store.write(newSnapshot);
      ref.invalidate(walletLabelsControllerProvider);

      state = state.copyWith(
        isProcessing: false,
        successMessage: 'Metadata imported and restored successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: 'Import failed: $e');
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final backupControllerProvider = StateNotifierProvider<BackupController, BackupState>((ref) {
  return BackupController(ref);
});
