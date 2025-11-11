import 'package:equatable/equatable.dart';

class MessageTranslation extends Equatable {
  final int id;
  final int messageId;
  final String languageCode;
  final String translatedContent;
  final String? translationService;
  final double? confidenceScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MessageTranslation({
    required this.id,
    required this.messageId,
    required this.languageCode,
    required this.translatedContent,
    this.translationService,
    this.confidenceScore,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MessageTranslation.fromJson(Map<String, dynamic> json) {
    return MessageTranslation(
      id: json['id'] as int,
      messageId: json['message_id'] as int,
      languageCode: json['language_code'] as String,
      translatedContent: json['translated_content'] as String,
      translationService: json['translation_service'] as String?,
      confidenceScore: json['confidence_score'] != null 
          ? (json['confidence_score'] as num).toDouble() 
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'language_code': languageCode,
      'translated_content': translatedContent,
      'translation_service': translationService,
      'confidence_score': confidenceScore,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        messageId,
        languageCode,
        translatedContent,
        translationService,
        confidenceScore,
        createdAt,
        updatedAt,
      ];
}
