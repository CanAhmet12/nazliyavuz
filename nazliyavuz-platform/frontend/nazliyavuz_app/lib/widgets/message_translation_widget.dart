import 'package:flutter/material.dart';
import '../models/message_translation.dart';

class MessageTranslationWidget extends StatelessWidget {
  final MessageTranslation translation;
  final VoidCallback? onShowOriginal;
  final bool showOriginal;

  const MessageTranslationWidget({
    Key? key,
    required this.translation,
    this.onShowOriginal,
    this.showOriginal = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.translate,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                _getLanguageName(translation.languageCode),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (translation.confidenceScore != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(translation.confidenceScore!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(translation.confidenceScore! * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (onShowOriginal != null)
                TextButton(
                  onPressed: onShowOriginal,
                  child: Text(
                    showOriginal ? 'Çeviriyi Göster' : 'Orijinali Göster',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            translation.translatedContent,
            style: const TextStyle(fontSize: 14),
          ),
          if (translation.translationService != null) ...[
            const SizedBox(height: 4),
            Text(
              'Çeviri: ${translation.translationService}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getLanguageName(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'tr':
        return 'Türkçe';
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      case 'fr':
        return 'Français';
      case 'es':
        return 'Español';
      case 'it':
        return 'Italiano';
      case 'ru':
        return 'Русский';
      case 'ar':
        return 'العربية';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      default:
        return languageCode.toUpperCase();
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) {
      return Colors.green;
    } else if (confidence >= 0.6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
