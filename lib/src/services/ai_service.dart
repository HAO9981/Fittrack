import 'package:firebase_ai/firebase_ai.dart';

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.5-flash-lite',
    systemInstruction: Content.text(
      'You are FitTrack AI, a helpful personal fitness assistant. '
      'Give practical, concise, beginner-friendly fitness and nutrition guidance. '
      'Use the user context when provided to personalize recommendations. '
      'Do not repeat the user profile unless it is directly relevant. '
      'For workout requests, provide a simple plan with exercise, sets/reps or duration, and rest when useful. '
      'For nutrition requests, suggest practical meal ideas and briefly explain why they fit the user goal. '
      'Keep normal answers under 180 words and use short headings or bullet points for readability. '
      'Do not diagnose medical conditions. Avoid making strong medical claims from BMI or other profile data. '
      'If a health concern is raised, recommend speaking with a qualified healthcare professional.',
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
