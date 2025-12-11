import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogEntry {
  final String transcript;
  final String imagePath;
  final DateTime createdAt;

  LogEntry({
    required this.transcript,
    required this.imagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'transcript': transcript,
        'imagePath': imagePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        transcript: json['transcript'] ?? '',
        imagePath: json['imagePath'] ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class LogStorageService {
  static const String _storageKey = 'speech_logs';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<LogEntry>> loadLogs() async {
    final prefs = await _prefs();
    final rawList = prefs.getStringList(_storageKey) ?? [];
    return rawList
        .map((item) => LogEntry.fromJson(jsonDecode(item)))
        .toList()
        .reversed
        .toList();
  }

  Future<void> addLog(LogEntry entry) async {
    final prefs = await _prefs();
    final rawList = prefs.getStringList(_storageKey) ?? [];
    rawList.add(jsonEncode(entry.toJson()));
    await prefs.setStringList(_storageKey, rawList);
  }

  Future<void> clearLogs() async {
    final prefs = await _prefs();
    await prefs.remove(_storageKey);
  }

  Future<void> deleteLog(LogEntry entry) async {
    final prefs = await _prefs();
    final rawList = prefs.getStringList(_storageKey) ?? [];
    rawList.removeWhere((item) {
      final data = jsonDecode(item) as Map<String, dynamic>;
      return data['createdAt'] == entry.createdAt.toIso8601String() &&
          data['imagePath'] == entry.imagePath &&
          data['transcript'] == entry.transcript;
    });
    await prefs.setStringList(_storageKey, rawList);
  }

  Future<String> saveImageToLocalDir(File imageFile) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = imageFile.path.split('.').last;
    final fileName =
        'capture_${DateTime.now().millisecondsSinceEpoch}.${ext.isNotEmpty ? ext : 'jpg'}';
    final savedPath = '${dir.path}/$fileName';
    final savedFile = await imageFile.copy(savedPath);
    return savedFile.path;
  }
}

