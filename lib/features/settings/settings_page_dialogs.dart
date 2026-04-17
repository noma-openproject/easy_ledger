part of 'settings_page.dart';

extension _SettingsBodyDialogs on _SettingsBodyState {
  Future<void> _promptLedgerExport(
    BuildContext context, {
    required bool monthly,
  }) async {
    final now = DateTime.now();
    final yearController = TextEditingController(text: now.year.toString());
    final monthController = TextEditingController(text: now.month.toString());
    try {
      final result = await showDialog<({int year, int? month})>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(monthly ? '월별 내보내기' : '연간 간편장부 내보내기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '연도',
                  border: OutlineInputBorder(),
                ),
              ),
              if (monthly) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: monthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '월',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final year = int.tryParse(yearController.text.trim());
                final month = monthly
                    ? int.tryParse(monthController.text.trim())
                    : null;
                if (year == null ||
                    year < 2000 ||
                    year > 2100 ||
                    (monthly && (month == null || month < 1 || month > 12))) {
                  return;
                }
                Navigator.of(
                  dialogContext,
                ).pop((year: year, month: monthly ? month : null));
              },
              child: const Text('내보내기'),
            ),
          ],
        ),
      );
      if (result == null || !context.mounted) return;
      await context.read<SettingsCubit>().exportSimpleLedger(
        year: result.year,
        month: result.month,
      );
    } finally {
      yearController.dispose();
      monthController.dispose();
    }
  }

  Future<void> _pickAndRestoreBackup(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty || !context.mounted) return;
    final path = picked.files.single.path;
    if (path == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('선택한 백업 파일 경로를 읽을 수 없습니다.')));
      return;
    }
    final mode = await showDialog<BackupRestoreMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('백업 복원 방식'),
        content: const Text('현재 데이터를 유지하며 병합하거나, 현재 데이터를 지우고 백업으로 덮어쓸 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(BackupRestoreMode.merge),
            child: const Text('병합'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(BackupRestoreMode.overwrite),
            child: const Text('덮어쓰기'),
          ),
        ],
      ),
    );
    if (mode == null || !context.mounted) return;
    await context.read<SettingsCubit>().restoreBackup(path, mode: mode);
  }

  Future<void> _confirmDeleteAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('전체 데이터 삭제'),
        content: const Text('거래, 영수증 이미지, 품목, 동기화 대기열, 설정을 이 기기에서 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<SettingsCubit>().deleteAllData();
  }
}
