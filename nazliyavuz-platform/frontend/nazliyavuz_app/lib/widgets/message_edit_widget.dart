import 'package:flutter/material.dart';

class MessageEditWidget extends StatefulWidget {
  final String initialContent;
  final Function(String)? onSave;
  final Function()? onCancel;
  final int maxLength;

  const MessageEditWidget({
    Key? key,
    required this.initialContent,
    this.onSave,
    this.onCancel,
    this.maxLength = 4000,
  }) : super(key: key);

  @override
  State<MessageEditWidget> createState() => _MessageEditWidgetState();
}

class _MessageEditWidgetState extends State<MessageEditWidget> {
  late TextEditingController _controller;
  late String _originalContent;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _originalContent = widget.initialContent;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit,
                size: 16,
                color: Colors.blue[700],
              ),
              const SizedBox(width: 8),
              Text(
                'Mesajı Düzenle',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: widget.maxLength,
            decoration: InputDecoration(
              hintText: 'Mesajınızı düzenleyin...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_controller.text.length}/${widget.maxLength}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _canSave() ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canSave() {
    final currentText = _controller.text.trim();
    return currentText.isNotEmpty && 
           currentText != _originalContent &&
           currentText.length <= widget.maxLength;
  }

  void _save() {
    if (_canSave()) {
      widget.onSave?.call(_controller.text.trim());
    }
  }
}
