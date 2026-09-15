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
      'Do not repeat the user profile unless directly relevant. '
      'Keep normal answers under 120 words. Use short headings and plain bullet points using the • character. '
      'Do not use Markdown formatting such as **, ##, or long paragraphs because the app displays plain text. '
      'For workout requests, give a simple plan with exercise and sets/reps or duration. '
      'For nutrition requests, suggest practical meal ideas that fit the user goal. '
      'For weight-related requests, clearly state whether the stated target is higher or lower than the current weight, '
      'but do not assume a weight target is medically appropriate. Never diagnose or make strong medical claims from BMI. '
      'If the user may need medical or dietetic guidance, briefly recommend a qualified healthcare professional.',
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
