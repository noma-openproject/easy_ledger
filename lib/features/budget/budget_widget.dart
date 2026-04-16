import 'package:flutter/material.dart';

import '../../core/models/category.dart' as model;

class BudgetCategoryField extends StatefulWidget {
  final model.Category category;
  final int? amount;
  final ValueChanged<String> onSave;

  const BudgetCategoryField({
    super.key,
    required this.category,
    required this.amount,
    required this.onSave,
  });

  @override
  State<BudgetCategoryField> createState() => _BudgetCategoryFieldState();
}

class _BudgetCategoryFieldState extends State<BudgetCategoryField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _displayAmount(widget.amount));
    _focusNode = FocusNode()
      ..addListener(() {
        if (!_focusNode.hasFocus) {
          widget.onSave(_controller.text);
        }
      });
  }

  @override
  void didUpdateWidget(covariant BudgetCategoryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = _displayAmount(widget.amount);
    if (!_focusNode.hasFocus && _controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(
              widget.category.colorHex,
            ).withValues(alpha: 0.16),
            child: Text(widget.category.iconEmoji),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.category.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 150,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: '예산 없음',
                suffixText: '원',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: widget.onSave,
            ),
          ),
          if ((widget.amount ?? 0) > 0) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: '예산 삭제',
              onPressed: () {
                _controller.clear();
                widget.onSave('');
              },
              icon: const Icon(Icons.close),
            ),
          ],
        ],
      ),
    );
  }

  String _displayAmount(int? amount) {
    if (amount == null || amount <= 0) return '';
    return amount.toString();
  }
}
