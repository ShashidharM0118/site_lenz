import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class SpeechRecognitionService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;
  String _currentTranscript = '';
  
  // Callbacks
  Function(String)? onTranscriptUpdate;
  Function(bool)? onListeningStateChange;
  Function(String)? onError;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String get currentTranscript => _currentTranscript;

  Future<bool> initializeSpeechRecognition() async {
    try {
      bool available = await _speechToText.initialize(
        onError: (error) {
          onError?.call('Speech recognition error: ${error.errorMsg}');
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            onListeningStateChange?.call(false);
          }
        },
      );
      
      _isAvailable = available;
      return available;
    } catch (e) {
      onError?.call('Failed to initialize speech recognition: $e');
      return false;
    }
  }

  Future<bool> requestMicrophonePermission() async {
    try {
      PermissionStatus status = await Permission.microphone.request();
      
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        onError?.call('Microphone permission is permanently denied. Please enable it in app settings.');
        return false;
      } else {
        onError?.call('Microphone permission was denied.');
        return false;
      }
    } catch (e) {
      onError?.call('Error requesting microphone permission: $e');
      return false;
    }
  }

  Future<void> startListening() async {
    if (!_isAvailable) {
      bool initialized = await initializeSpeechRecognition();
      if (!initialized) {
        return;
      }
    }

    bool hasPermission = await requestMicrophonePermission();
    if (!hasPermission) {
      return;
    }

    if (_isListening) {
      return;
    }

    try {
      _currentTranscript = '';
      _isListening = true;
      onListeningStateChange?.call(true);

      await _speechToText.listen(
        onResult: (result) {
          _currentTranscript = result.recognizedWords;
          onTranscriptUpdate?.call(_currentTranscript);
          
          if (result.finalResult) {
            onTranscriptUpdate?.call(result.recognizedWords);
          }
        },
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      _isListening = false;
      onListeningStateChange?.call(false);
      onError?.call('Failed to start listening: $e');
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }

    try {
      await _speechToText.stop();
      _isListening = false;
      onListeningStateChange?.call(false);
    } catch (e) {
      onError?.call('Failed to stop listening: $e');
    }
  }

  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
      _isListening = false;
      _currentTranscript = '';
      onListeningStateChange?.call(false);
      onTranscriptUpdate?.call('');
    } catch (e) {
      onError?.call('Failed to cancel listening: $e');
    }
  }

  void clearTranscript() {
    _currentTranscript = '';
    onTranscriptUpdate?.call('');
  }

  void dispose() {
    _speechToText.stop();
    _isListening = false;
  }
}

