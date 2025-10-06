import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Enhanced form field with real-time validation and better UX
class EnhancedFormField extends StatefulWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final String? helperText;
  final bool showPasswordStrength;
  final bool required;

  const EnhancedFormField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines = 1,
    this.enabled = true,
    this.onChanged,
    this.inputFormatters,
    this.focusNode,
    this.helperText,
    this.showPasswordStrength = false,
    this.required = false,
  });

  @override
  State<EnhancedFormField> createState() => _EnhancedFormFieldState();
}

class _EnhancedFormFieldState extends State<EnhancedFormField>
    with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  bool _hasError = false;
  String? _errorText;
  bool _showPassword = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    widget.controller.addListener(_onTextChanged);
    widget.focusNode?.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode?.removeListener(_onFocusChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {
        // Real-time validation
        if (widget.controller.text.isNotEmpty && widget.validator != null) {
          final error = widget.validator!(widget.controller.text);
          _hasError = error != null;
          _errorText = error;
        } else {
          _hasError = false;
          _errorText = null;
        }
      });
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {
        _isFocused = widget.focusNode?.hasFocus ?? false;
      });
      
      if (_isFocused) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _showPassword = !_showPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with required indicator
        Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _hasError 
                    ? AppTheme.error 
                    : _isFocused 
                        ? AppTheme.primaryBlue 
                        : AppTheme.grey700,
              ),
            ),
            if (widget.required) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        
        // Form field
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _isFocused ? [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  keyboardType: widget.keyboardType,
                  obscureText: widget.obscureText && !_showPassword,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  enabled: widget.enabled,
                  onChanged: widget.onChanged,
                  inputFormatters: widget.inputFormatters,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: AppTheme.grey400,
                      fontSize: 16,
                    ),
                    prefixIcon: widget.prefixIcon,
                    suffixIcon: _buildSuffixIcon(),
                    filled: true,
                    fillColor: _isFocused 
                        ? Colors.white 
                        : AppTheme.grey50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _hasError 
                            ? AppTheme.error 
                            : _isFocused 
                                ? AppTheme.primaryBlue 
                                : AppTheme.grey300,
                        width: _isFocused ? 2 : 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _hasError 
                            ? AppTheme.error 
                            : AppTheme.grey300,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _hasError 
                            ? AppTheme.error 
                            : AppTheme.primaryBlue,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.error,
                        width: 2,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.error,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    errorStyle: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  validator: widget.validator,
                ),
              ),
            );
          },
        ),
        
        // Helper text or error text
        if (widget.helperText != null && !_hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.grey500,
            ),
          ),
        ],
        
        if (_errorText != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 16,
                color: AppTheme.error,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _errorText!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
        
        // Password strength indicator
        if (widget.showPasswordStrength && widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildPasswordStrengthIndicator(),
        ],
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.obscureText) {
      return IconButton(
        icon: Icon(
          _showPassword ? Icons.visibility_off : Icons.visibility,
          color: _isFocused ? AppTheme.primaryBlue : AppTheme.grey500,
        ),
        onPressed: _togglePasswordVisibility,
      );
    }
    return widget.suffixIcon;
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = widget.controller.text;
    final strength = _calculatePasswordStrength(password);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: strength.value,
                backgroundColor: AppTheme.grey200,
                valueColor: AlwaysStoppedAnimation<Color>(strength.color),
                minHeight: 4,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              strength.text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: strength.color,
              ),
            ),
          ],
        ),
        if (password.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _getPasswordRequirements(password),
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.grey500,
            ),
          ),
        ],
      ],
    );
  }

  PasswordStrength _calculatePasswordStrength(String password) {
    if (password.isEmpty) {
      return PasswordStrength('', 0.0, AppTheme.grey400);
    }
    
    double score = 0.0;
    String text = '';
    Color color = AppTheme.grey400;
    
    // Length check
    if (password.length >= 8) score += 0.3;
    if (password.length >= 12) score += 0.2;
    
    // Character variety checks
    if (password.contains(RegExp(r'[a-z]'))) score += 0.1;
    if (password.contains(RegExp(r'[A-Z]'))) score += 0.1;
    if (password.contains(RegExp(r'[0-9]'))) score += 0.1;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score += 0.2;
    
    if (score < 0.3) {
      text = 'Zayıf';
      color = AppTheme.error;
    } else if (score < 0.6) {
      text = 'Orta';
      color = Colors.orange;
    } else if (score < 0.8) {
      text = 'İyi';
      color = Colors.blue;
    } else {
      text = 'Güçlü';
      color = Colors.green;
    }
    
    return PasswordStrength(text, score, color);
  }

  String _getPasswordRequirements(String password) {
    final requirements = <String>[];
    
    if (password.length < 8) {
      requirements.add('En az 8 karakter');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      requirements.add('Büyük harf');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      requirements.add('Rakam');
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      requirements.add('Özel karakter');
    }
    
    if (requirements.isEmpty) {
      return 'Şifre güçlü!';
    }
    
    return 'Eksik: ${requirements.join(', ')}';
  }
}

class PasswordStrength {
  final String text;
  final double value;
  final Color color;

  PasswordStrength(this.text, this.value, this.color);
}
