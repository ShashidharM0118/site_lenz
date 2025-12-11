import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  bool _isInitialized = false;
  String? _apiKey;
  String _model = 'gpt-4o-mini'; // Default model
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
        onError?.call('OpenAI API key is required. Please set your API key.');
        return;
      }

      _apiKey = apiKeyToUse;
      _isInitialized = true;
    } catch (e) {
      onError?.call('Failed to initialize OpenAI: $e');
      _isInitialized = false;
    }
  }

  void clearHistory() {
    _conversationHistory.clear();
  }

  Future<String?> generateText(String prompt, {List<String>? imageBase64}) async {
    if (!_isInitialized || _apiKey == null) {
      onError?.call('OpenAI service is not initialized. Please provide an API key.');
      return null;
    }

    try {
      onLoadingStateChange?.call(true);
      
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');
      
      // Build message content
      dynamic messageContent;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        // Multi-modal message with images
        List<dynamic> content = [];
        content.add({'type': 'text', 'text': prompt.isNotEmpty ? prompt : 'Describe this image'});
        
        for (String base64Image in imageBase64) {
          content.add({
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,$base64Image'
            }
          });
        }
        messageContent = content;
      } else {
        // Text-only message
        messageContent = prompt;
      }

      // Add user message to history
      _conversationHistory.add({
        'role': 'user',
        'content': messageContent,
      });
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': _conversationHistory,
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      onLoadingStateChange?.call(false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String?;
        
        if (content != null && content.isNotEmpty) {
          // Add assistant response to history
          _conversationHistory.add({
            'role': 'assistant',
            'content': content,
          });
          
          onResponse?.call(content);
          return content;
        } else {
          onError?.call('Empty response from OpenAI');
          return null;
        }
      } else {
        String errorMessage = 'API error: ${response.statusCode}';
        if (response.statusCode == 401) {
          errorMessage = 'Invalid API key. Please check your OpenAI API key.';
        } else if (response.statusCode == 429) {
          errorMessage = 'Rate limit exceeded. Please try again later.';
        } else {
          try {
            final errorData = jsonDecode(response.body);
            errorMessage = errorData['error']['message'] ?? errorMessage;
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
