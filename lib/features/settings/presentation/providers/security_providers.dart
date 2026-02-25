import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

class BackupReminderController extends AsyncNotifier<bool> {
  static const _backupConfirmedKey = 'settings.backup_confirmed';

  @override
  Future<bool> build() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    return prefs.getBool(_backupConfirmedKey) ?? false;
  }

  Future<void> confirmBackup() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_backupConfirmedKey, true);
    state = const AsyncData(true);
  }

  Future<void> clearBackupConfirmation() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_backupConfirmedKey, false);
    state = const AsyncData(false);
  }
}

final backupReminderProvider =
    AsyncNotifierProvider<BackupReminderController, bool>(
      BackupReminderController.new,
    );
