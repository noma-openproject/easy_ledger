import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app.dart';
import '../../core/models/category.dart' as model;
import '../../core/utils/format_utils.dart';

class CategoryManagerPage extends StatelessWidget {
  const CategoryManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hive = AppDeps.of(context).hive;
    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리 관리'),
        actions: [
          IconButton(
            tooltip: '카테고리 추가',
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: hive.listenable,
        builder: (context, _) {
          final categories = hive.categories();
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) async {
              final reordered = [...categories];
              if (newIndex > oldIndex) newIndex -= 1;
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);
              await hive.reorderCategories(reordered);
            },
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                key: ValueKey(category.id),
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(
                      category.colorHex,
                    ).withValues(alpha: 0.16),
                    child: Text(category.iconEmoji),
                  ),
                  title: Text(category.name),
                  subtitle: Text(
                    [
                      category.isDefault ? '기본' : '사용자 추가',
                      if (category.taxCategory != null) category.taxCategory!,
                    ].join(' · '),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: '편집',
                        onPressed: () => _openEditor(context, category),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: category.isDefault ? '기본 카테고리는 삭제 불가' : '삭제',
                        onPressed: category.isDefault
                            ? null
                            : () => _confirmDelete(context, category),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('추가'),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    model.Category category,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text('${category.name} 카테고리를 삭제할까요?\n기존 거래 기록은 그대로 유지됩니다.'),
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
    await AppDeps.of(context).hive.deleteCategory(category.id);
  }

  Future<void> _openEditor(
    BuildContext context, [
    model.Category? category,
  ]) async {
    final hive = AppDeps.of(context).hive;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category?.name ?? '');
    final iconController = TextEditingController(
      text: category?.iconEmoji ?? '🧾',
    );
    final colorController = TextEditingController(
      text: _formatColorHex(category?.colorHex ?? 0xFF90A4AE),
    );
    String taxCategoryValue = category?.taxCategory ?? _noneTaxCategory;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(category == null ? '카테고리 추가' : '카테고리 편집'),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: '이름',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '이름을 입력하세요.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: iconController,
                                decoration: const InputDecoration(
                                  labelText: '아이콘',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: colorController,
                                decoration: const InputDecoration(
                                  labelText: '색상 ARGB',
                                  hintText: 'FF90A4AE',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: taxCategoryValue,
                          decoration: const InputDecoration(
                            labelText: '세무 카테고리',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: _noneTaxCategory,
                              child: Text('없음'),
                            ),
                            for (final value in kTaxCategories)
                              DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => taxCategoryValue = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.of(dialogContext).pop(true);
                    },
                    child: const Text('저장'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (saved != true || !context.mounted) return;

      final currentCount = hive.categories().length;
      final updated = model.Category(
        id: category?.id ?? const Uuid().v4(),
        name: nameController.text.trim(),
        iconEmoji: _blankToDefault(iconController.text, '🧾'),
        colorHex: _parseColorHex(
          colorController.text,
          category?.colorHex ?? 0xFF90A4AE,
        ),
        isDefault: category?.isDefault ?? false,
        taxCategory: taxCategoryValue == _noneTaxCategory
            ? null
            : taxCategoryValue,
        sortOrder: category?.sortOrder ?? currentCount,
      );
      await hive.upsertCategory(updated);
    } finally {
      nameController.dispose();
      iconController.dispose();
      colorController.dispose();
    }
  }

  String _blankToDefault(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _formatColorHex(int value) {
    return value.toRadixString(16).padLeft(8, '0').toUpperCase();
  }

  int _parseColorHex(String value, int fallback) {
    final cleaned = value.trim().replaceAll('#', '').toUpperCase();
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return int.tryParse(normalized, radix: 16) ?? fallback;
  }
}

const String _noneTaxCategory = '__none__';
