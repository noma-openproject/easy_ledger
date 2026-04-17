import 'dart:io';

import '../../core/export/backup_service.dart';
import '../../core/export/simple_ledger_exporter.dart';
import '../../core/storage/hive_storage.dart';

class SettingsDataService {
  final HiveStorage _hive;

  SettingsDataService(this._hive);

  Future<File> exportSimpleLedger({required int year, int? month}) {
    return SimpleLedgerExporter(_hive).exportAndShare(year: year, month: month);
  }

  Future<File> createBackup() => BackupService(_hive).createBackup();

  Future<BackupResult> restoreBackup(
    String path, {
    required BackupRestoreMode mode,
  }) {
    return BackupService(_hive).restoreFromZip(File(path), mode: mode);
  }

  Future<void> deleteAllData() => BackupService(_hive).deleteAllData();
}
