import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../services/log_storage_service.dart';
import '../services/speech_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SpeechRecognitionService _speechService;
  final LogStorageService _logStorage = LogStorageService();
  
  String _transcript = '';
  String _statusMessage = 'Ready';
  bool _hasError = false;
  bool _isSavingLog = false;
  
  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  String _sessionId = '';

  @override
  void initState() {
    super.initState();
    _sessionId = _generateSessionId();
    _initializeServices();
  }

  String _generateSessionId() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> _initializeServices() async {
    _speechService = SpeechRecognitionService();

    // Set up speech service callbacks
    _speechService.onTranscriptUpdate = (transcript) {
      setState(() {
        _transcript = transcript;
      });
    };

    _speechService.onListeningStateChange = (isListening) {
      setState(() {
        if (isListening) {
          _statusMessage = 'Recording...';
          _hasError = false;
        } else {
          _statusMessage = 'Ready';
        }
      });
    };

    _speechService.onError = (error) {
      setState(() {
        _statusMessage = 'Error';
        _hasError = true;
      });
      _showSnackBar(error);
    };

    await _initializeSpeech();
    await _initializeCamera();
  }

  Future<void> _initializeSpeech() async {
    bool initialized = await _speechService.initializeSpeechRecognition();
    if (initialized) {
      setState(() {
        _statusMessage = 'Ready';
      });
    } else {
      setState(() {
        _statusMessage = 'Error';
        _hasError = true;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  Future<void> _refreshCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
    await _initializeCamera();
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

  Future<void> _handleStartLogging() async {
    await _speechService.startListening();
  }

  Future<void> _handleStopLogging() async {
    await _speechService.stopListening();
    
    // Wait a bit for transcript to be finalized
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_transcript.trim().isEmpty) {
      _showSnackBar('No transcript to save');
      return;
    }
    
    await _captureAndSaveLog();
  }

  Future<void> _captureAndSaveLog() async {
    try {
      setState(() {
        _isSavingLog = true;
      });

      // Take picture from camera controller
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final XFile imageFile = await _cameraController!.takePicture();
        
        final savedPath = await _logStorage.saveImageToLocalDir(File(imageFile.path));

        await _logStorage.addLog(LogEntry(
          transcript: _transcript.trim(),
          imagePath: savedPath,
          createdAt: DateTime.now(),
        ));

        setState(() {
          _isSavingLog = false;
          _transcript = '';
          _sessionId = _generateSessionId();
        });
        _speechService.clearTranscript();
        
        _showSnackBar('Log saved successfully');
        
        // Trigger logs screen refresh if it exists
        // This will be handled by pull-to-refresh on logs screen
      } else {
        setState(() {
          _isSavingLog = false;
        });
        _showSnackBar('Camera not ready');
      }
    } catch (e) {
      setState(() {
        _isSavingLog = false;
      });
      _showSnackBar('Error saving log: $e');
      print('Error capturing and saving: $e');
    }
  }

  @override
  void dispose() {
    _speechService.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header - Purple theme
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Site Lenz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Camera Preview Section
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: Stack(
                  children: [
                    // Camera preview
                    if (_isCameraInitialized && _cameraController != null)
                      SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: CameraPreview(_cameraController!),
                      )
                    else
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    
                    // Status indicator bottom left
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _hasError
                                  ? Colors.red
                                  : _speechService.isListening
                                      ? Colors.orange
                                      : Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Refresh button bottom right
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: _refreshCamera,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4A90E2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // START LOGGING Button
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _speechService.isListening
                    ? _handleStopLogging
                    : _handleStartLogging,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _speechService.isListening ? AppTheme.primaryPurple : AppTheme.accentGreen,
                  foregroundColor: _speechService.isListening ? Colors.white : AppTheme.textDark,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _speechService.isListening ? Icons.stop_circle : Icons.mic,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _speechService.isListening ? 'STOP LOGGING' : 'START LOGGING',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Live Transcript Section
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderGrey, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Transcript Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withOpacity(0.05),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.text_fields, color: AppTheme.primaryPurple, size: 22),
                          const SizedBox(width: 10),
                          const Text(
                            'Live Transcript',
                            style: TextStyle(
                              color: AppTheme.primaryPurple,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Transcript Content
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: _transcript.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.mic,
                                      size: 64,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Transcript will appear here',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Start logging to begin transcription',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                child: Text(
                                  _transcript,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Session Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Session: $_sessionId',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
