import 'dart:io';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/models/transaction.dart' as ledger;
import '../../core/utils/format_utils.dart';
import '../manual_input/manual_input_page.dart';

class TransactionDetailPage extends StatelessWidget {
  final ledger.Transaction transaction;

  const TransactionDetailPage({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final hive = AppDeps.of(context).hive;
    return AnimatedBuilder(
      animation: hive.listenable,
      builder: (context, _) {
        final current = hive.getTransaction(transaction.id) ?? transaction;
        final receipt = current.receiptId == null
            ? null
            : hive.getReceipt(current.receiptId!);
        final items = hive.itemsByTransaction(current.id);
        return Scaffold(
          appBar: AppBar(
            title: const Text('상세'),
            actions: [
              IconButton(
                tooltip: '수정',
                onPressed: () => _edit(context, current),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: '삭제',
                onPressed: () => _delete(context, current),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (receipt != null && File(receipt.imagePath).existsSync()) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(receipt.imagePath),
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _Section(
                title: current.storeName,
                children: [
                  _InfoRow('날짜', formatCompactDate(current.date)),
                  if (current.time != null) _InfoRow('시간', current.time!),
                  _InfoRow('총액', formatWon(current.total)),
                  if (current.tax != null)
                    _InfoRow('부가세', formatWon(current.tax!)),
                  _InfoRow('결제수단', paymentMethodLabel(current.paymentMethod)),
                  _InfoRow('카테고리', hive.categoryName(current.category)),
                  _InfoRow('구분', expenseTypeLabel(current.expenseType)),
                  if (current.expenseType == 'business')
                    _InfoRow('세무 카테고리', current.taxCategory ?? '미지정'),
                  if (current.businessNumber != null)
                    _InfoRow('사업자번호', current.businessNumber!),
                  if (current.memo != null) _InfoRow('메모', current.memo!),
                  _InfoRow('시트 동기화', current.syncedToSheet ? '완료' : '대기'),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: '품목',
                children: items.isEmpty
                    ? [const Text('품목 정보 없음')]
                    : [
                        for (final item in items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.name),
                            subtitle: Text(
                              '${item.quantity}개 x ${formatWon(item.unitPrice)}',
                            ),
                            trailing: Text(formatWon(item.total)),
                          ),
                      ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _edit(
    BuildContext context,
    ledger.Transaction transaction,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManualInputPage(initialTransaction: transaction),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    ledger.Transaction transaction,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('거래 삭제'),
        content: Text('${transaction.storeName} 거래를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final deps = AppDeps.of(context);
    try {
      await deps.syncQueue.enqueueDeletionIfConfigured(transaction);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 준비 실패: $e')));
      return;
    }
    if (!context.mounted) return;
    await deps.hive.deleteTransaction(transaction.id);
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
