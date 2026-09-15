import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  String _userContext = '';

  @override
  void initState() {
    super.initState();
    AiService.instance.resetChat();
    _loadUserContext();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUserContext() async {
    final user = FirebaseAuthService.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingContext = false);
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        FirestoreService.instance.getUserProfile(user.uid),
        WorkoutService.instance
            .getRecentWorkouts(lookback: const Duration(days: 30), limit: 10)
            .first,
        NutritionService.instance
            .getRecentMeals(lookback: const Duration(days: 30), limit: 10)
            .first,
      ]);

      final profile = results[0] as UserProfile?;
      final workouts = results[1] as List<Workout>;
      final meals = results[2] as List<Meal>;

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
        _isLoadingContext = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingContext = false);
      }
    }
  }

  Future<void> _sendMessage([String? preset]) async {
    final message = (preset ?? _controller.text).trim();
    if (message.isEmpty || _isSending) return;

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text: message, isUser: true));
      _isSending = true;
    });

    try {
      final response = await AiService.instance.sendMessage(
        message: message,
        userContext: _userContext,
      );
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(text: response, isUser: false)));
    } catch (error, stackTrace) {
      debugPrint('FitTrack AI error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      final errorText = kDebugMode
          ? 'AI error:\n$error'
          : 'I could not connect to the AI right now. Please try again.';
      setState(() => _messages.add(
            _ChatMessage(
              text: errorText,
              isUser: false,
            ),
          ));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatWorkouts(List<Workout> workouts) {
    if (workouts.isEmpty) return 'None recorded in the last 30 days.';
    return workouts
        .map((workout) => '${workout.name} (${workout.category}, ${workout.duration} min)')
        .join('; ');
  }

  String _formatMeals(List<Meal> meals) {
    if (meals.isEmpty) return 'None recorded in the last 30 days.';
    return meals
        .map((meal) => '${meal.foodName} (${meal.category}, ${meal.calories} kcal)')
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
                      setState(() => _messages.clear());
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
                      onPreset: _sendMessage,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _MessageBubble(message: _messages[index]),
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
  const _WelcomeView({required this.isLoadingContext, required this.onPreset});

  final bool isLoadingContext;
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
                child: Icon(Icons.auto_awesome, size: 34, color: Theme.of(context).colorScheme.primary),
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
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _SuggestionChip(label: 'What workout should I do today?', onTap: onPreset),
                  _SuggestionChip(label: 'How can I improve my fitness?', onTap: onPreset),
                  _SuggestionChip(label: 'Give me a healthy meal idea.', onTap: onPreset),
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
  Widget build(BuildContext context) => ActionChip(
        label: Text(label),
        onPressed: () => onTap(label),
      );
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
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
          color: message.isUser ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(message.text),
      ),
    );
  }
}
