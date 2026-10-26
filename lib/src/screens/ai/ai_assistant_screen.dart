import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';

import '../../models/meal.dart';
import '../../models/user_profile.dart';
import '../../models/workout.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/workout_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];

  bool _isSending = false;
  bool _isLoadingContext = true;
  bool _contextLoadFailed = false;
  String _userContext = '';
  String? _failedMessage;

  @override
  void initState() {
    super.initState();
    developer.log(
      'AI assistant screen initialized.',
      name: 'FitTrack.AiScreen',
    );
    AiService.instance.resetChat();
    _loadUserContext();
  }

  @override
  void dispose() {
    if (_isSending) {
      developer.log(
        'AI assistant screen disposed while a request was pending.',
        name: 'FitTrack.AiScreen',
      );
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUserContext() async {
    developer.log('User context load started.', name: 'FitTrack.AiScreen');
    final stopwatch = Stopwatch()..start();
    try {
      final user = FirebaseAuthService.instance.currentUser;
      if (user == null) {
        developer.log(
          'No signed-in user; using an empty AI context.',
          name: 'FitTrack.AiScreen',
        );
        return;
      }

      final results = await Future.wait<dynamic>([
        FirestoreService.instance.getUserProfile(user.uid),
        WorkoutService.instance
            .getRecentWorkouts(lookback: const Duration(days: 30), limit: 10)
            .first,
        NutritionService.instance.getMeals().first,
      ]).timeout(const Duration(seconds: 12));

      final profile = results[0] as UserProfile?;
      final workouts = results[1] as List<Workout>;
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final meals = (results[2] as List<Meal>)
          .where((meal) => meal.date.isAfter(cutoff))
          .take(10)
          .toList();

      final buffer = StringBuffer()
        ..writeln('Name: ${profile?.displayName ?? user.displayName ?? 'User'}')
        ..writeln('Fitness goal: ${profile?.fitnessGoal ?? 'Not set'}')
        ..writeln('Age: ${profile?.age ?? 'Not set'}')
        ..writeln('Height: ${profile?.heightCm ?? 'Not set'} cm')
        ..writeln('Current weight: ${profile?.weightKg ?? 'Not set'} kg')
        ..writeln('Target weight: ${profile?.targetWeightKg ?? 'Not set'} kg')
        ..writeln('Recent workouts: ${_formatWorkouts(workouts)}')
        ..writeln('Recent meals: ${_formatMeals(meals)}');

      if (!mounted) return;
      setState(() {
        _userContext = buffer.toString();
        _contextLoadFailed = false;
      });
      developer.log(
        'User context load completed in ${stopwatch.elapsedMilliseconds} ms.',
        name: 'FitTrack.AiScreen',
      );
    } catch (error, stackTrace) {
      final detail = error is FirebaseException
          ? '${error.plugin}/${error.code}'
          : error is TimeoutException
          ? 'timeout'
          : error.runtimeType.toString();
      developer.log(
        'User context load failed ($detail); continuing without personalization.',
        name: 'FitTrack.AiScreen',
        error: error.runtimeType.toString(),
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() => _contextLoadFailed = true);
      }
    } finally {
      stopwatch.stop();
      if (mounted) {
        setState(() => _isLoadingContext = false);
      }
      developer.log(
        'User context loading state reset.',
        name: 'FitTrack.AiScreen',
      );
    }
  }

  Future<void> _sendMessage([String? preset, bool retry = false]) async {
    final message = (preset ?? _controller.text).trim();
    if (message.isEmpty || _isSending) return;

    if (!retry) _controller.clear();
    setState(() {
      if (!retry) _messages.add(_ChatMessage(text: message, isUser: true));
      _failedMessage = null;
      _isSending = true;
    });

    developer.log(
      'AI message submitted; request state set to loading.',
      name: 'FitTrack.AiScreen',
    );
    try {
      final response = await AiService.instance.sendMessage(
        message: message,
        userContext: _userContext,
      );
      if (!mounted) return;
      setState(
        () => _messages.add(_ChatMessage(text: response, isUser: false)),
      );
      developer.log('AI response rendered.', name: 'FitTrack.AiScreen');
    } catch (error, stackTrace) {
      developer.log(
        'AI request failed in screen (${error.runtimeType}).',
        name: 'FitTrack.AiScreen',
        error: error.runtimeType.toString(),
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _failedMessage = message;
        final errorMessage = _ChatMessage(
          text: _friendlyAiError(error),
          isUser: false,
          isError: true,
        );
        if (_messages.isNotEmpty && _messages.last.isError) {
          _messages[_messages.length - 1] = errorMessage;
        } else {
          _messages.add(errorMessage);
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        developer.log(
          'AI screen loading state reset.',
          name: 'FitTrack.AiScreen',
        );
      }
    }
  }

  String _friendlyAiError(Object error) {
    if (error is TimeoutException) {
      return 'FitTrack AI took too long to respond. Check your connection and retry.';
    }
    if (error is ServiceApiNotEnabled) {
      return 'FitTrack AI is not enabled for this Firebase project yet. Please try again later.';
    }
    if (error is InvalidApiKey) {
      return 'FitTrack AI could not verify the app configuration. Please contact support.';
    }
    if (error is QuotaExceeded) {
      return 'FitTrack AI has reached its current usage limit. Please try again later.';
    }
    if (error is UnsupportedUserLocation) {
      return 'FitTrack AI is unavailable in this location.';
    }
    if (error is FirebaseAIException &&
        error.message.toLowerCase().contains('app check') &&
        error.message.toLowerCase().contains('invalid')) {
      return 'FitTrack AI could not verify this app. For a debug build, register its App Check debug token in Firebase Console, then retry.';
    }
    if (error is FirebaseAIException) {
      return 'FitTrack AI could not complete that request. Please try again.';
    }
    return 'FitTrack AI is temporarily unavailable. Check your connection and try again.';
  }

  String _formatWorkouts(List<Workout> workouts) {
    if (workouts.isEmpty) return 'None recorded in the last 30 days.';
    return workouts
        .map(
          (workout) =>
              '${workout.name} (${workout.category}, ${workout.formattedDuration})',
        )
        .join('; ');
  }

  String _formatMeals(List<Meal> meals) {
    if (meals.isEmpty) return 'None recorded in the last 30 days.';
    return meals
        .map(
          (meal) =>
              '${meal.foodName} (${meal.category}, ${meal.calories} kcal)',
        )
        .join('; ');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('FitTrack AI'),
      actions: [
        IconButton(
          tooltip: 'New chat',
          onPressed: _isSending
              ? null
              : () {
                  AiService.instance.resetChat();
                  setState(() {
                    _messages.clear();
                    _failedMessage = null;
                  });
                },
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _WelcomeView(
                  isLoadingContext: _isLoadingContext,
                  contextLoadFailed: _contextLoadFailed,
                  onPreset: _sendMessage,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) =>
                      _MessageBubble(message: _messages[index]),
                ),
        ),
        if (_isSending)
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (_failedMessage != null && !_isSending)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _sendMessage(_failedMessage, true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Ask FitTrack AI...',
                      prefixIcon: Icon(Icons.auto_awesome),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSending ? null : () => _sendMessage(),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({
    required this.isLoadingContext,
    required this.contextLoadFailed,
    required this.onPreset,
  });

  final bool isLoadingContext;
  final bool contextLoadFailed;
  final ValueChanged<String> onPreset;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.auto_awesome,
              size: 34,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text('FitTrack AI', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Ask for practical workout and nutrition guidance based on your FitTrack profile and recent activity.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (isLoadingContext) const LinearProgressIndicator(),
          if (contextLoadFailed) ...[
            const SizedBox(height: 8),
            const Text(
              'Personal activity could not be loaded. You can still ask FitTrack AI.',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _SuggestionChip(
                label: 'What workout should I do today?',
                onTap: onPreset,
              ),
              _SuggestionChip(
                label: 'How can I improve my fitness?',
                onTap: onPreset,
              ),
              _SuggestionChip(
                label: 'Give me a healthy meal idea.',
                onTap: onPreset,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) =>
      ActionChip(label: Text(label), onPressed: () => onTap(label));
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: message.isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.text,
          style: message.isError ? TextStyle(color: scheme.error) : null,
        ),
      ),
    );
  }
}
