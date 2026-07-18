import 'package:flutter/material.dart';

class CommentInputSheet extends StatefulWidget {
  final String hintText;
  final Future<bool> Function(String content) onSubmit;

  const CommentInputSheet({
    super.key,
    required this.hintText,
    required this.onSubmit,
  });

  @override
  State<CommentInputSheet> createState() => _CommentInputSheetState();
}

class _CommentInputSheetState extends State<CommentInputSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _canSubmit = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _canSubmit = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);

    try {
      final shouldClose = await widget.onSubmit(_controller.text.trim());
      if (!mounted) return;
      if (shouldClose) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 获取底部键盘高度 + 安全区域
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: theme.dialogTheme.backgroundColor ?? colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withAlpha(80),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _canSubmit && !_submitting ? _submit : null,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_submitting ? '发送中' : '发送'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
