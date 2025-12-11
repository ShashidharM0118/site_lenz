import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import '../services/groq_service.dart';
import '../services/openai_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? imagePaths;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imagePaths,
  });
}

enum AIService { groq, openai }

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GroqAIService _groqService = GroqAIService();
  final OpenAIService _openAIService = OpenAIService();
  final ImagePicker _imagePicker = ImagePicker();
  
  List<ChatMessage> _messages = [];
  List<String> _selectedImages = []; // Base64 encoded images
  List<String> _imageFilePaths = []; // File paths for display
  bool _isLoading = false;
  String? _groqApiKey;
  String? _openaiApiKey;
  bool _groqInitialized = false;
  bool _openaiInitialized = false;
  
  AIService _currentService = AIService.groq;
  
  // Available Groq models
  final List<String> _groqModels = [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
    'llama-3.1-70b-versatile',
    'mixtral-8x7b-32768',
    'gemma2-9b-it',
  ];
  
  // Available OpenAI models
  final List<String> _openaiModels = [
    'gpt-4o-mini',
    'gpt-4o',
    'gpt-4-turbo',
    'gpt-3.5-turbo',
  ];
  
  String _selectedModel = 'llama-3.3-70b-versatile';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    // Initialize Groq
    _groqApiKey = dotenv.env['GROQ_API_KEY'];
    if (_groqApiKey != null && _groqApiKey!.isNotEmpty && _groqApiKey != 'your_api_key_here') {
      _groqService.initialize(apiKey: _groqApiKey);
      _groqService.setModel(_selectedModel);
      _groqInitialized = true;
    }

    _groqService.onResponse = (response) {
      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    };

    _groqService.onLoadingStateChange = (isLoading) {
      setState(() {
        _isLoading = isLoading;
      });
      if (isLoading) {
        _scrollToBottom();
      }
    };

    _groqService.onError = (error) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar(error);
    };

    // Initialize OpenAI
    _openaiApiKey = dotenv.env['OPENAI_API_KEY'];
    if (_openaiApiKey != null && _openaiApiKey!.isNotEmpty && _openaiApiKey != 'your_api_key_here') {
      _openAIService.initialize(apiKey: _openaiApiKey);
      _openAIService.setModel('gpt-4o-mini');
      _openaiInitialized = true;
    }

    _openAIService.onResponse = (response) {
      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    };

    _openAIService.onLoadingStateChange = (isLoading) {
      setState(() {
        _isLoading = isLoading;
      });
      if (isLoading) {
        _scrollToBottom();
      }
    };

    _openAIService.onError = (error) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar(error);
    };
  }

  void _switchService(AIService service) {
    if (_currentService == service) return;
    
    setState(() {
      _currentService = service;
      // Update model based on service
      if (service == AIService.groq) {
        _selectedModel = _groqModels[0];
        _groqService.setModel(_selectedModel);
      } else {
        _selectedModel = _openaiModels[0];
        _openAIService.setModel(_selectedModel);
      }
    });
  }

  List<String> get _availableModels {
    return _currentService == AIService.groq ? _groqModels : _openaiModels;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage();
      
      if (pickedFiles.isNotEmpty) {
        List<String> base64Images = [];
        List<String> filePaths = [];
        
        for (XFile file in pickedFiles) {
          File imageFile = File(file.path);
          List<int> imageBytes = await imageFile.readAsBytes();
          String base64Image = base64Encode(imageBytes);
          base64Images.add(base64Image);
          filePaths.add(file.path);
        }
        
        setState(() {
          _selectedImages.addAll(base64Images);
          _imageFilePaths.addAll(filePaths);
        });
      }
    } catch (e) {
      _showSnackBar('Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imageFilePaths.removeAt(index);
    });
  }

  Future<void> _sendMessage() async {
    String messageText = _messageController.text.trim();
    
    if (messageText.isEmpty && _selectedImages.isEmpty) {
      return;
    }

    // Initialize service if needed
    if (_currentService == AIService.groq) {
      if (!_groqInitialized || _groqApiKey == null || !_groqService.isInitialized) {
        _groqApiKey = dotenv.env['GROQ_API_KEY'];
        if (_groqApiKey != null && _groqApiKey!.isNotEmpty && _groqApiKey != 'your_api_key_here') {
          _groqService.initialize(apiKey: _groqApiKey);
          _groqService.setModel(_selectedModel);
          _groqInitialized = true;
        } else {
          _showSnackBar('Groq API key not configured. Please set it in .env file.');
          return;
        }
      }
    } else {
      if (!_openaiInitialized || _openaiApiKey == null || !_openAIService.isInitialized) {
        _openaiApiKey = dotenv.env['OPENAI_API_KEY'];
        if (_openaiApiKey != null && _openaiApiKey!.isNotEmpty && _openaiApiKey != 'your_api_key_here') {
          _openAIService.initialize(apiKey: _openaiApiKey);
          _openAIService.setModel(_selectedModel);
          _openaiInitialized = true;
        } else {
          _showSnackBar('OpenAI API key not configured. Please set it in .env file.');
          return;
        }
      }
    }

    // Store images to display
    List<String> imagesToSend = List.from(_selectedImages);
    List<String> imagePathsToSend = List.from(_imageFilePaths);

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: messageText.isEmpty ? 'Image' : messageText,
        isUser: true,
        timestamp: DateTime.now(),
        imagePaths: imagePathsToSend.isNotEmpty ? imagePathsToSend : null,
      ));
      _messageController.clear();
      _selectedImages.clear();
      _imageFilePaths.clear();
    });
    
    _scrollToBottom();

    // Send to selected AI service
    if (_currentService == AIService.groq) {
      await _groqService.generateTextFromMessage(
        messageText.isEmpty ? 'Describe this image' : messageText,
        imageBase64: imagesToSend.isNotEmpty ? imagesToSend : null,
      );
    } else {
      await _openAIService.generateTextFromMessage(
        messageText.isEmpty ? 'Describe this image' : messageText,
        imageBase64: imagesToSend.isNotEmpty ? imagesToSend : null,
      );
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _selectedImages.clear();
      _imageFilePaths.clear();
    });
    _groqService.clearHistory();
    _openAIService.clearHistory();
  }

  void _onModelChanged(String? newModel) {
    if (newModel != null) {
      setState(() {
        _selectedModel = newModel;
      });
      if (_currentService == AIService.groq) {
        _groqService.setModel(newModel);
      } else {
        _openAIService.setModel(newModel);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Expanded(child: Text('AI Chatbot')),
            const SizedBox(width: 8),
            // Service switcher
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _switchService(AIService.groq),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _currentService == AIService.groq
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Groq',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _switchService(AIService.openai),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _currentService == AIService.openai
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'OpenAI',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Model selection dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedModel,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                dropdownColor: Theme.of(context).primaryColor,
                items: _availableModels.map((String model) {
                  String displayName = model;
                  if (model.contains('llama')) {
                    displayName = model.replaceAll('llama-', 'L');
                  } else if (model.contains('mixtral')) {
                    displayName = model.replaceAll('mixtral-', 'M');
                  } else if (model.contains('gemma')) {
                    displayName = model.replaceAll('gemma', 'G');
                  } else if (model.contains('gpt')) {
                    displayName = model.toUpperCase();
                  }
                  return DropdownMenuItem<String>(
                    value: model,
                    child: Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: _onModelChanged,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearChat,
              tooltip: 'Clear Chat',
            ),
        ],
      ),
      body: Column(
        children: [
          // Selected images preview
          if (_imageFilePaths.isNotEmpty)
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _imageFilePaths.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_imageFilePaths[index]),
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Chat messages area
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation with ${_currentService == AIService.groq ? "Groq" : "OpenAI"}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        // Loading indicator
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    // Add image button
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate),
                      onPressed: _isLoading ? null : _pickImages,
                      tooltip: 'Add Image',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isLoading,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _isLoading ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: const Icon(Icons.smart_toy, color: Colors.green),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Images in message
                if (message.imagePaths != null && message.imagePaths!.isNotEmpty)
                  ...message.imagePaths!.map((imagePath) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(imagePath),
                          width: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }),
                // Text message
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(18).copyWith(
                      bottomRight: message.isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                      bottomLeft: message.isUser
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.person, color: Colors.blue),
            ),
          ],
        ],
      ),
    );
  }
}