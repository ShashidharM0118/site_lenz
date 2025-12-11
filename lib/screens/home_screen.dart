import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../services/log_storage_service.dart';
import '../services/speech_service.dart';

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
            // Header - Light blue
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: const Color(0xFF4A90E2), // Light blue
              child: const Center(
                child: Text(
                  'Real-time Transcription',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _speechService.isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _speechService.isListening ? 'STOP LOGGING' : 'START LOGGING',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Ready message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _speechService.isListening
                        ? 'Recording... Tap STOP to capture and save'
                        : 'Ready! Tap START to begin transcription',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Transcript Section
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Transcript Header
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.text_fields, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            'Live Transcript',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Transcript Content
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
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
