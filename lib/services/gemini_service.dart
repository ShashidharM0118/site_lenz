import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiAIService {
  bool _isInitialized = false;
  String? _apiKey;
  String _model = 'gemini-1.5-pro'; // Default model
  List<Map<String, dynamic>> _conversationHistory = [];

  // Callbacks
  Function(String)? onResponse;
  Function(String)? onError;
  Function(bool)? onLoadingStateChange;

  void setModel(String model) {
    _model = model;
  }

  String get currentModel => _model;

  void initialize({String? apiKey}) {
    try {
      final apiKeyToUse = apiKey ?? '';
      
      if (apiKeyToUse.isEmpty || apiKeyToUse == 'your_api_key_here') {
        _isInitialized = false;
        return;
      }

      _apiKey = apiKeyToUse;
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
    }
  }

  void clearHistory() {
    _conversationHistory.clear();
  }

  Future<String?> generateText(String prompt, {List<String>? imageBase64}) async {
    if (!_isInitialized || _apiKey == null) {
      onError?.call('Gemini service is not initialized. Please provide an API key.');
      return null;
    }

    try {
      onLoadingStateChange?.call(true);
      
      // Add text part
      Map<String, dynamic> textPart = {
        'text': prompt
      };
      
      // Build parts array
      List<Map<String, dynamic>> parts = [textPart];
      
      // Add image parts if provided
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        for (String base64Image in imageBase64) {
          parts.add({
            'inline_data': {
              'mime_type': 'image/jpeg',
              'data': base64Image
            }
          });
        }
      }

      // Build the request body
      Map<String, dynamic> requestBody = {
        'contents': [
          {
            'parts': parts
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 2048,
        }
      };

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      onLoadingStateChange?.call(false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Extract text from Gemini response
        String? content;
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          content = data['candidates'][0]['content']['parts'][0]['text'] as String?;
        }
        
        if (content != null && content.isNotEmpty) {
          // Add to conversation history
          _conversationHistory.add({
            'role': 'user',
            'parts': parts,
          });
          
          _conversationHistory.add({
            'role': 'model',
            'parts': [
              {'text': content}
            ],
          });
          
          onResponse?.call(content);
          return content;
        } else {
          onError?.call('Empty response from Gemini AI');
          return null;
        }
      } else {
        String errorMessage = 'API error: ${response.statusCode}';
        if (response.statusCode == 401 || response.statusCode == 403) {
          errorMessage = 'Invalid API key. Please check your Gemini API key.';
        } else if (response.statusCode == 429) {
          errorMessage = 'Rate limit exceeded. Please try again later.';
        } else {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData['error'] != null && errorData['error']['message'] != null) {
              errorMessage = errorData['error']['message'];
            }
          } catch (_) {
            errorMessage = 'Failed to get response: ${response.body}';
          }
        }
        onError?.call(errorMessage);
        return null;
      }
    } catch (e) {
      onLoadingStateChange?.call(false);
      String errorMessage = 'Failed to generate text: $e';
      
      if (e.toString().contains('SocketException') || e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }
      
      onError?.call(errorMessage);
      return null;
    }
  }

  Future<String?> generateTextFromMessage(String messageText, {List<String>? imageBase64}) async {
    if (messageText.trim().isEmpty && (imageBase64 == null || imageBase64.isEmpty)) {
      return null;
    }

    return await generateText(messageText, imageBase64: imageBase64);
  }

  bool get isInitialized => _isInitialized;
}

