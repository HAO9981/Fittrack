import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static const requestTimeout = Duration(seconds: 35);
  static const _modelName = 'gemini-3.8-flash';
  static const _systemPrompt =
      'You are FitTrack AI, a helpful fitness assistant. Give practical, concise fitness and nutrition guidance. '
      'Use the user context when provided. Do not diagnose medical conditions or replace professional medical advice. '
      'For health concerns, recommend speaking with a qualified healthcare professional.';

  GenerativeModel? _model;
  List<Content> _recoveryHistory = const [];

  ChatSession? _chat;
  int _chatGeneration = 0;

  GenerativeModel _getModel() {
    final current = _model;
    if (current != null) return current;

    developer.log(
      'Initializing Firebase AI model $_modelName.',
      name: 'FitTrack.AiService',
    );
    final model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      systemInstruction: Content.text(_systemPrompt),
    );
    _model = model;
    developer.log('Firebase AI model initialized.', name: 'FitTrack.AiService');
    return model;
  }

  ChatSession _getSession() {
    final current = _chat;
    if (current != null) return current;

    developer.log(
      'Creating Firebase AI chat session.',
      name: 'FitTrack.AiService',
    );
    final session = _getModel().startChat(history: _recoveryHistory);
    _chat = session;
    developer.log(
      'Firebase AI chat session created.',
      name: 'FitTrack.AiService',
    );
    return session;
  }

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

    final stopwatch = Stopwatch()..start();
    ChatSession? requestSession;
    final generation = _chatGeneration;
    developer.log('AI request started.', name: 'FitTrack.AiService');
    try {
      requestSession = _getSession();
      final response = await requestSession
          .sendMessage(Content.text(prompt))
          .timeout(
            requestTimeout,
            onTimeout: () {
              throw TimeoutException(
                'FitTrack AI request timed out.',
                requestTimeout,
              );
            },
          );
      final text = response.text?.trim();

      if (text == null || text.isEmpty) {
        throw StateError('The AI returned an empty response.');
      }

      if (generation == _chatGeneration && identical(_chat, requestSession)) {
        _recoveryHistory = requestSession.history.toList(growable: false);
      }
      developer.log(
        'AI request completed in ${stopwatch.elapsedMilliseconds} ms.',
        name: 'FitTrack.AiService',
      );
      return text;
    } catch (error, stackTrace) {
      if (requestSession != null && generation == _chatGeneration) {
        _recoveryHistory = requestSession.history.toList(growable: false);
        if (identical(_chat, requestSession)) _chat = null;
      }
      final category = _failureCategory(error);
      final detail = error is FirebaseAIException
          ? error.message
          : error.toString();
      final safeDetail = _redact(detail);
      developer.log(
        'AI request failed [$category] (${error.runtimeType}): $safeDetail',
        name: 'FitTrack.AiService',
        error: error.runtimeType.toString(),
        stackTrace: stackTrace,
      );
      debugPrint(
        'FitTrack AI request failed [$category] (${error.runtimeType}): $safeDetail',
      );
      rethrow;
    } finally {
      stopwatch.stop();
      developer.log(
        'AI request settled after ${stopwatch.elapsedMilliseconds} ms.',
        name: 'FitTrack.AiService',
      );
    }
  }

  void resetChat() {
    _chatGeneration++;
    _chat = null;
    _recoveryHistory = const [];
  }

  String _failureCategory(Object error) {
    if (error is TimeoutException) return 'timeout';
    final message = error is FirebaseAIException
        ? error.message.toLowerCase()
        : error.toString().toLowerCase();
    if (message.contains('app check')) return 'app-check';
    if (message.contains('api key') || message.contains('api_key')) {
      return 'api-configuration';
    }
    if (message.contains('permission denied') ||
        message.contains('service_api_not_enabled')) {
      return 'permission-or-project-configuration';
    }
    if (message.contains('quota') || message.contains('resource exhausted')) {
      return 'quota';
    }
    if (message.contains('model') &&
        (message.contains('not found') || message.contains('invalid'))) {
      return 'model-configuration';
    }
    if (message.contains('socket') ||
        message.contains('network') ||
        message.contains('unavailable') ||
        message.contains('connection')) {
      return 'network';
    }
    return 'request';
  }

  String _redact(String value) => value
      .replaceAll(RegExp(r'AIza[0-9A-Za-z_-]{30,}'), '[redacted API key]')
      .replaceAll(
        RegExp(r'(key|token)[=: ]+[A-Za-z0-9_-]{16,}', caseSensitive: false),
        r'$1=[redacted]',
      )
      .replaceAll(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'), '[redacted email]')
      .replaceAll(
        RegExp(r'\b[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}\b'),
        '[redacted id]',
      );
}
