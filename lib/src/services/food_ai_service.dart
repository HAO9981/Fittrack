import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

class FoodAnalysis {
  const FoodAnalysis({
    required this.foodName,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.portion,
    required this.notes,
  });

  final String foodName;
  final int calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String portion;
  final String notes;

  factory FoodAnalysis.fromJson(Map<String, dynamic> json) {
    int readCalories(dynamic value) =>
        value is num ? value.round() : int.tryParse('$value') ?? 0;
    double readDouble(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

    return FoodAnalysis(
      foodName: (json['foodName'] as String? ?? 'Unknown food').trim(),
      calories: readCalories(json['calories']),
      proteinGrams: readDouble(json['proteinGrams']),
      carbsGrams: readDouble(json['carbsGrams']),
      fatGrams: readDouble(json['fatGrams']),
      portion: (json['portion'] as String? ?? 'Estimated serving').trim(),
      notes: (json['notes'] as String? ?? '').trim(),
    );
  }
}

class DailyNutritionInsight {
  const DailyNutritionInsight({
    required this.summary,
    required this.strengths,
    required this.suggestions,
    required this.disclaimer,
  });

  final String summary;
  final List<String> strengths;
  final List<String> suggestions;
  final String disclaimer;

  factory DailyNutritionInsight.fromJson(Map<String, dynamic> json) {
    List<String> readList(dynamic value) => value is List
        ? value.whereType<String>().map((item) => item.trim()).where((item) => item.isNotEmpty).toList()
        : <String>[];
    return DailyNutritionInsight(
      summary: (json['summary'] as String? ?? '').trim(),
      strengths: readList(json['strengths']),
      suggestions: readList(json['suggestions']),
      disclaimer: (json['disclaimer'] as String? ?? 'Nutrition guidance is general and approximate.').trim(),
    );
  }
}

class FoodAiService {
  FoodAiService._();
  static final FoodAiService instance = FoodAiService._();

  final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.8-flash',
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      temperature: 0.2,
    ),
  );

  Future<FoodAnalysis> analyzeImage({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('The selected food image is empty.');
    }

    const prompt = '''
Identify the visible food and estimate its nutrition for the portion shown.
Return ONLY a JSON object with these exact keys:
{
  "foodName": "short food name",
  "calories": 0,
  "proteinGrams": 0.0,
  "carbsGrams": 0.0,
  "fatGrams": 0.0,
  "portion": "estimated portion description",
  "notes": "short uncertainty or estimation note"
}
Use realistic approximate values for the visible serving. Do not invent hidden ingredients.
If the food is unclear, say so in notes and use conservative estimates.
All nutrition values must be non-negative. Calories must be an integer.
''';

    final response = await _model.generateContent([
      Content.multi([
        TextPart(prompt),
        InlineDataPart(mimeType, imageBytes),
      ]),
    ]).timeout(const Duration(seconds: 45));

    final responseText = response.text?.trim();
    if (responseText == null || responseText.isEmpty) {
      throw StateError('FitTrack AI returned an empty food analysis.');
    }

    final cleaned = responseText
        .replaceFirst(RegExp(r'^\s*\u0060\u0060\u0060(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*\u0060\u0060\u0060\s*$'), '');
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The AI response was not a JSON object.');
    }

    final result = FoodAnalysis.fromJson(decoded);
    if (result.foodName.isEmpty || result.calories <= 0) {
      throw const FormatException('The AI returned invalid nutrition values.');
    }
    return result;
  }

  Future<DailyNutritionInsight> analyzeDailyNutrition({
    required List<Map<String, dynamic>> meals,
    required int totalCalories,
    required double proteinGrams,
    required double carbsGrams,
    required double fatGrams,
    required String dateLabel,
  }) async {
    if (meals.isEmpty) {
      throw ArgumentError('Add at least one meal before requesting an analysis.');
    }

    final prompt = '''
You are FitTrack AI, a practical nutrition coach. Review this user's logged food for $dateLabel.
The nutrition values are estimates and may be incomplete. Do not assume unlogged meals were not eaten.
Do not diagnose diseases or prescribe treatment.
Daily totals:
- Calories: $totalCalories kcal
- Protein: ${proteinGrams.toStringAsFixed(1)} g
- Carbohydrates: ${carbsGrams.toStringAsFixed(1)} g
- Fat: ${fatGrams.toStringAsFixed(1)} g
Logged meals (JSON):
${jsonEncode(meals)}
Return ONLY JSON with this schema:
{
  "summary": "one concise, balanced overview",
  "strengths": ["one positive observation"],
  "suggestions": ["one practical suggestion for the next meal or day"],
  "disclaimer": "short reminder that estimates are approximate"
}
Use only evidence in the supplied records. If macro data is missing, mention that limitation rather than guessing.
Keep each item short, supportive, and actionable. Return 1-3 strengths and 1-3 suggestions.
''';

    final response = await _model.generateContent([Content.text(prompt)]).timeout(const Duration(seconds: 45));
    final responseText = response.text?.trim();
    if (responseText == null || responseText.isEmpty) {
      throw StateError('FitTrack AI returned an empty nutrition insight.');
    }
    final cleaned = responseText
        .replaceFirst(RegExp(r'^\s*```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```\s*$'), '');
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The AI response was not a JSON object.');
    }
    final insight = DailyNutritionInsight.fromJson(decoded);
    if (insight.summary.isEmpty) {
      throw const FormatException('The AI returned an incomplete nutrition insight.');
    }
    return insight;
  }

}
