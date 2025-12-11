import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}

class GroqAIService {
  bool _isInitialized = false;
  String? _apiKey;
  String _model = 'llama-3.3-70b-versatile'; // Default model - updated from decommissioned version
  int _maxTokens = 4096; // Increased default for comprehensive reports
  List<Map<String, dynamic>> _conversationHistory = [];

  // Callbacks
  Function(String)? onResponse;
  Function(String)? onError;
  Function(bool)? onLoadingStateChange;

  void setModel(String model) {
    _model = model;
  }

  void setMaxTokens(int maxTokens) {
    _maxTokens = maxTokens;
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
      onError?.call('Groq AI service is not initialized. Please provide an API key.');
      return null;
    }

    // Groq API (Llama models) does not support images/vision
    // Return error if images are provided
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      onError?.call('Groq API does not support image analysis. Please use OpenAI or Gemini for image-based conversations.');
      return null;
    }

    try {
      onLoadingStateChange?.call(true);
      
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      
      // Text-only message (Groq doesn't support images)
      String messageContent = prompt.isNotEmpty ? prompt : 'Please provide a message.';

      // Add user message to history
      _conversationHistory.add({
        'role': 'user',
        'content': messageContent, // Always string for Groq
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
          'max_tokens': _maxTokens, // Use configurable max tokens
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
          onError?.call('Empty response from Groq AI');
          return null;
        }
      } else {
        String errorMessage = 'API error: ${response.statusCode}';
        if (response.statusCode == 401) {
          errorMessage = 'Invalid API key. Please check your Groq API key.';
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