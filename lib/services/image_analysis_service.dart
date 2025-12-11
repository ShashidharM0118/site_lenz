import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'gemini_service.dart';
import 'openai_service.dart';

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

enum ImageAnalysisProvider { gemini, openai }

class ImageAnalysisService {
  final GeminiAIService _geminiService = GeminiAIService();
  final OpenAIService _openaiService = OpenAIService();
  bool _isInitialized = false;
  bool _openaiInitialized = false;
  ImageAnalysisProvider _preferredProvider = ImageAnalysisProvider.openai; // Default to OpenAI

  void initialize() {
    try {
      // Initialize Gemini
      final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
      print('ImageAnalysisService: GEMINI_API_KEY = ${geminiApiKey != null ? "Found" : "NULL"}');
      if (geminiApiKey != null && geminiApiKey.isNotEmpty && geminiApiKey != 'your_api_key_here') {
        _geminiService.initialize(apiKey: geminiApiKey);
        _geminiService.setModel('gemini-2.5-flash'); // Use Gemini 2.5 Flash for vision
        _isInitialized = true;
        print('✓ ImageAnalysisService (Gemini) initialized successfully');
      } else {
        _isInitialized = false;
        print('✗ ImageAnalysisService: Gemini API key not valid');
      }
      
      // Initialize OpenAI as fallback
      final openaiApiKey = dotenv.env['OPENAI_API_KEY'];
      print('ImageAnalysisService: OPENAI_API_KEY = ${openaiApiKey != null ? "Found" : "NULL"}');
      if (openaiApiKey != null && openaiApiKey.isNotEmpty && openaiApiKey != 'your_api_key_here') {
        _openaiService.initialize(apiKey: openaiApiKey);
        _openaiService.setModel('gpt-4o'); // Use GPT-4o for vision (better than mini for image analysis)
        _openaiInitialized = true;
        print('✓ ImageAnalysisService (OpenAI fallback) initialized successfully');
      } else {
        _openaiInitialized = false;
        print('✗ ImageAnalysisService: OpenAI API key not available for fallback');
      }
    } catch (e) {
      _isInitialized = false;
      print('✗ ImageAnalysisService initialization error: $e');
    }
  }

  Future<ImageAnalysisResult> analyzeImage(String imagePath, int imageIndex) async {
    // Initialize services if not already done
    if (!_isInitialized && !_openaiInitialized) {
      initialize();
      if (!_isInitialized && !_openaiInitialized) {
        throw Exception('Neither Gemini nor OpenAI API key configured for image analysis');
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

    String? response;
    String provider = 'Unknown';

    // Use preferred provider first
    if (_preferredProvider == ImageAnalysisProvider.openai && _openaiInitialized) {
      try {
        print('Attempting image analysis with OpenAI (preferred)...');
        response = await _openaiService.generateText(prompt, imageBase64: [base64Image]);
        provider = 'OpenAI';
        
        if (response != null && response.isNotEmpty) {
          print('✓ Image analysis successful with OpenAI');
        }
      } catch (e) {
        print('✗ OpenAI image analysis failed: $e');
        response = null;
      }
    } else if (_preferredProvider == ImageAnalysisProvider.gemini && _isInitialized) {
      try {
        print('Attempting image analysis with Gemini (preferred)...');
        response = await _geminiService.generateText(prompt, imageBase64: [base64Image]);
        provider = 'Gemini';
        
        if (response != null && response.isNotEmpty) {
          print('✓ Image analysis successful with Gemini');
        }
      } catch (e) {
        print('✗ Gemini image analysis failed: $e');
        response = null;
      }
    }

    // Fallback to the other provider if preferred one failed
    if ((response == null || response.isEmpty)) {
      if (_preferredProvider == ImageAnalysisProvider.openai && _isInitialized) {
        try {
          print('Falling back to Gemini for image analysis...');
          response = await _geminiService.generateText(prompt, imageBase64: [base64Image]);
          provider = 'Gemini';
          
          if (response != null && response.isNotEmpty) {
            print('✓ Image analysis successful with Gemini (fallback)');
          }
        } catch (e) {
          print('✗ Gemini fallback also failed: $e');
          response = null;
        }
      } else if (_preferredProvider == ImageAnalysisProvider.gemini && _openaiInitialized) {
        try {
          print('Falling back to OpenAI for image analysis...');
          response = await _openaiService.generateText(prompt, imageBase64: [base64Image]);
          provider = 'OpenAI';
          
          if (response != null && response.isNotEmpty) {
            print('✓ Image analysis successful with OpenAI (fallback)');
          }
        } catch (e) {
          print('✗ OpenAI fallback also failed: $e');
          response = null;
        }
      }
    }

    if (response == null || response.isEmpty) {
      throw Exception('Failed to get image analysis from both Gemini and OpenAI');
    }

    // Parse JSON response (works for both Gemini and OpenAI)
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
      print('✓ Successfully parsed JSON response from $provider');
      return ImageAnalysisResult.fromJson(jsonData, imageIndex);
    } catch (e) {
      // If JSON parsing fails, try to extract JSON from the response
      print('Warning: Failed to parse JSON response from $provider. Attempting to extract JSON... Error: $e');
      
      // Try to find JSON object in the response
      try {
        final jsonMatch = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', dotAll: true).firstMatch(response);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
          print('✓ Successfully extracted and parsed JSON from $provider response');
          return ImageAnalysisResult.fromJson(jsonData, imageIndex);
        }
      } catch (e2) {
        print('✗ Failed to extract JSON from response: $e2');
      }
      
      // Final fallback: create result from text response
      print('Using text fallback for image analysis from $provider');
      return ImageAnalysisResult(
        imageIndex: imageIndex,
        description: response.length > 500 ? response.substring(0, 500) : response,
        defects: [],
        overallCondition: 'Unknown - Analysis incomplete (parsing failed)',
        materialType: 'Unknown',
      );
    }
  }

  bool get isInitialized => _isInitialized || _openaiInitialized;

  void setPreferredProvider(ImageAnalysisProvider provider) {
    _preferredProvider = provider;
  }

  ImageAnalysisProvider get preferredProvider => _preferredProvider;
}

