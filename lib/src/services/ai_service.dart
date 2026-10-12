import 'package:firebase_ai/firebase_ai.dart';

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.8-flash',
    systemInstruction: Content.text(
      'You are FitTrack AI, a helpful fitness assistant. Give practical, concise fitness and nutrition guidance. '
      'Use the user context when provided. Do not diagnose medical conditions or replace professional medical advice. '
      'For health concerns, recommend speaking with a qualified healthcare professional.',
    ),
  );

  ChatSession? _chat;

  ChatSession get _session => _chat ??= _model.startChat();

  Future<String> sendMessage({
    required String message,
    String userContext = '',
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }

    final prompt = userContext.trim().isEmpty
        ? trimmedMessage
        : 'User context:\n$userContext\n\nUser message:\n$trimmedMessage';

    final response = await _session.sendMessage(Content.text(prompt));
    final text = response.text?.trim();

    if (text == null || text.isEmpty) {
      throw StateError('The AI returned an empty response.');
    }

    return text;
  }

  void resetChat() {
    _chat = null;
  }
}
