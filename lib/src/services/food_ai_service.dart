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
}
