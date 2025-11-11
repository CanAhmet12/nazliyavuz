import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ModernChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onSend;
  final VoidCallback? onAttachment;
  final VoidCallback? onVoiceRecord;
  final bool isSending;
  final bool isRecording;
  final VoidCallback? onStopRecording;

  const ModernChatInput({
    Key? key,
    required this.controller,
    this.onSend,
    this.onAttachment,
    this.onVoiceRecord,
    this.isSending = false,
    this.isRecording = false,
    this.onStopRecording,
  }) : super(key: key);

  @override
  State<ModernChatInput> createState() => _ModernChatInputState();
}

class _ModernChatInputState extends State<ModernChatInput>
    with TickerProviderStateMixin {
  late AnimationController _recordingAnimationController;
  late Animation<double> _recordingAnimation;
  bool _isExpanded = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _recordingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _recordingAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _recordingAnimationController, curve: Curves.easeInOut),
    );
    
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _recordingAnimationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isExpanded = widget.controller.text.isNotEmpty;
    });
  }

  void _onFocusChanged() {
    setState(() {
      _isExpanded = _focusNode.hasFocus || widget.controller.text.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1E8), // Bej background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recording indicator
              if (widget.isRecording) _buildRecordingIndicator(),
              
              // Main input row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment button
                  _buildAttachmentButton(),
                  const SizedBox(width: 8),
                  
                  // Text input
                  Expanded(
                    child: _buildTextInput(),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Voice/Send button
                  _buildActionButton(),
                ],
              ),
              
              // Expanded options (when typing)
              if (_isExpanded) _buildExpandedOptions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _recordingAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _recordingAnimation.value,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          const Text(
            'Kayıt yapılıyor...',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onStopRecording,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.stop,
                color: Colors.red,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton() {
    return GestureDetector(
      onTap: widget.onAttachment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F1E8), // Bej background
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Icon(
          Icons.attach_file_rounded,
          color: Colors.black87,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTextInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        maxLines: null,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          hintText: 'Mesaj yazın...',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
          ),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty && !widget.isSending) {
            widget.onSend?.call();
          }
        },
      ),
    );
  }

  Widget _buildActionButton() {
    if (widget.controller.text.trim().isEmpty && !widget.isRecording) {
      return _buildVoiceButton();
    } else if (widget.isRecording) {
      return _buildStopButton();
    } else {
      return _buildSendButton();
    }
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onTap: widget.onVoiceRecord,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50), // Green color
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.mic,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return GestureDetector(
      onTap: widget.onStopRecording,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.red[500],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.stop,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: widget.isSending ? null : widget.onSend,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: widget.isSending ? Colors.grey[300] : const Color(0xFF4CAF50), // Green color
          borderRadius: BorderRadius.circular(20),
        ),
        child: widget.isSending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
      ),
    );
  }

  Widget _buildExpandedOptions() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          _buildOptionButton(
            icon: Icons.emoji_emotions,
            label: 'Emoji',
            onTap: () => _showEmojiPicker(),
          ),
          _buildOptionButton(
            icon: Icons.photo_camera,
            label: 'Kamera',
            onTap: () => _takePhoto(),
          ),
          _buildOptionButton(
            icon: Icons.photo_library,
            label: 'Galeri',
            onTap: () => _selectFromGallery(),
          ),
          _buildOptionButton(
            icon: Icons.location_on,
            label: 'Konum',
            onTap: () => _shareLocation(),
          ),
          _buildOptionButton(
            icon: Icons.contact_phone,
            label: 'Kişi',
            onTap: () => _shareContact(),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: Colors.grey[600], size: 24),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmojiPicker() {
    // Implement emoji picker
    HapticFeedback.lightImpact();
  }

  void _takePhoto() {
    // Implement camera
    HapticFeedback.lightImpact();
  }

  void _selectFromGallery() {
    // Implement gallery selection
    HapticFeedback.lightImpact();
  }

  void _shareLocation() {
    // Implement location sharing
    HapticFeedback.lightImpact();
  }

  void _shareContact() {
    // Implement contact sharing
    HapticFeedback.lightImpact();
  }
}
