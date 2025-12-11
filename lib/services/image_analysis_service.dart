import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'gemini_service.dart';

class Defect {
  final String type;
  final String location;
  final String severity; // Critical/High/Medium/Low
  final int confidenceScore; // 0-100
  final String description;

  Defect({
    required this.type,
    required this.location,
    required this.severity,
    required this.confidenceScore,
    required this.description,
  });

  factory Defect.fromJson(Map<String, dynamic> json) {
    return Defect(
      type: json['type'] ?? 'Unknown',
      location: json['location'] ?? 'Not specified',
      severity: json['severity'] ?? 'Medium',
      confidenceScore: (json['confidence_score'] ?? 50) is int 
          ? json['confidence_score'] 
          : int.tryParse(json['confidence_score'].toString()) ?? 50,
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'location': location,
    'severity': severity,
    'confidence_score': confidenceScore,
    'description': description,
  };
}

class ImageAnalysisResult {
  final int imageIndex;
  final String description;
  final List<Defect> defects;
  final String overallCondition;
  final String? materialType;

  ImageAnalysisResult({
    required this.imageIndex,
    required this.description,
    required this.defects,
    required this.overallCondition,
    this.materialType,
  });

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json, int imageIndex) {
    List<Defect> defects = [];
    if (json['defects'] != null && json['defects'] is List) {
      defects = (json['defects'] as List)
          .map((d) => Defect.fromJson(d as Map<String, dynamic>))
          .toList();
    }

    return ImageAnalysisResult(
      imageIndex: imageIndex,
      description: json['description'] ?? '',
      defects: defects,
      overallCondition: json['overall_condition'] ?? 'Fair',
      materialType: json['material_type'],
    );
  }

  Map<String, dynamic> toJson() => {
    'image_index': imageIndex,
    'description': description,
    'defects': defects.map((d) => d.toJson()).toList(),
    'overall_condition': overallCondition,
    'material_type': materialType,
  };
}

class ImageAnalysisService {
  final GeminiAIService _geminiService = GeminiAIService();
  bool _isInitialized = false;

  void initialize() {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      print('ImageAnalysisService: GEMINI_API_KEY = ${apiKey != null ? "Found" : "NULL"}');
      if (apiKey != null && apiKey.isNotEmpty && apiKey != 'your_api_key_here') {
        _geminiService.initialize(apiKey: apiKey);
        _geminiService.setModel('gemini-2.5-flash'); // Use Gemini 2.5 Flash for vision
        _isInitialized = true;
        print('✓ ImageAnalysisService initialized successfully');
      } else {
        _isInitialized = false;
        print('✗ ImageAnalysisService: API key not valid');
      }
    } catch (e) {
      _isInitialized = false;
      print('✗ ImageAnalysisService initialization error: $e');
    }
  }

  Future<ImageAnalysisResult> analyzeImage(String imagePath, int imageIndex) async {
    if (!_isInitialized) {
      initialize();
      if (!_isInitialized) {
        throw Exception('Gemini API key not configured for image analysis');
      }
    }

    // Load and encode image
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Image file not found: $imagePath');
    }

    final imageBytes = await file.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    // Create detailed analysis prompt
    String prompt = '''You are an expert building inspector specialized in wall defect detection and assessment. Analyze this wall image in detail.

Provide your analysis in the following JSON format (respond ONLY with valid JSON):

{
  "description": "A detailed description of what you see in the image (wall type, color, condition)",
  "material_type": "The type of wall material (e.g., Concrete, Drywall, Brick, Plaster, etc.)",
  "overall_condition": "Overall condition rating (Excellent/Good/Fair/Poor/Critical)",
  "defects": [
    {
      "type": "Type of defect (e.g., Crack, Moisture damage, Paint peeling, Structural damage, etc.)",
      "location": "Specific location in the image (e.g., Upper left corner, Center of wall, Bottom right, etc.)",
      "severity": "Severity level (Critical/High/Medium/Low)",
      "confidence_score": 85,
      "description": "Detailed description of this specific defect"
    }
  ]
}

IMPORTANT:
- Confidence score must be 0-100 (0=unsure, 100=certain)
- Identify ALL visible defects, no matter how minor
- If no defects are visible, return empty defects array
- Be thorough and professional
- Only respond with valid JSON, no additional text''';

    // Call Gemini for analysis
    String? response = await _geminiService.generateText(prompt, imageBase64: [base64Image]);

    if (response == null || response.isEmpty) {
      throw Exception('Failed to get image analysis from Gemini');
    }

    // Parse JSON response
    try {
      // Clean response - remove markdown code blocks if present
      String cleanedResponse = response.trim();
      if (cleanedResponse.startsWith('```json')) {
        cleanedResponse = cleanedResponse.substring(7);
      } else if (cleanedResponse.startsWith('```')) {
        cleanedResponse = cleanedResponse.substring(3);
      }
      if (cleanedResponse.endsWith('```')) {
        cleanedResponse = cleanedResponse.substring(0, cleanedResponse.length - 3);
      }
      cleanedResponse = cleanedResponse.trim();

      final jsonData = jsonDecode(cleanedResponse) as Map<String, dynamic>;
      return ImageAnalysisResult.fromJson(jsonData, imageIndex);
    } catch (e) {
      // If JSON parsing fails, create a fallback result
      print('Warning: Failed to parse JSON response from Gemini. Using fallback. Error: $e');
      print('Raw response: $response');
      
      return ImageAnalysisResult(
        imageIndex: imageIndex,
        description: response.length > 500 ? response.substring(0, 500) : response,
        defects: [],
        overallCondition: 'Unknown - Analysis incomplete',
        materialType: 'Unknown',
      );
    }
  }

  bool get isInitialized => _isInitialized;
}

