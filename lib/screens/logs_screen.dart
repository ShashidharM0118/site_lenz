import 'dart:io';
import 'package:flutter/material.dart';
import '../services/log_storage_service.dart';
import '../services/report_generation_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> with AutomaticKeepAliveClientMixin {
  final LogStorageService _logStorage = LogStorageService();
  final ReportGenerationService _reportService = ReportGenerationService();
  List<LogEntry> _logs = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    // Initialize report service - it will check for API key when needed
    try {
      _reportService.initialize();
    } catch (e) {
      debugPrint('Report service initialization note: $e');
      // Don't fail if initialization fails here - it will be checked when generating reports
    }
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    final items = await _logStorage.loadLogs();
    if (mounted) {
      setState(() {
        _logs = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs'),
        content: const Text('Are you sure you want to delete all logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logStorage.clearLogs();
      await _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearLogs,
              tooltip: 'Clear Logs',
            ),
        ],
      ),
      floatingActionButton: _logs.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _generateReportFromAllLogs,
              icon: const Icon(Icons.description),
              label: const Text('Generate Report\n(All Logs)'),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No logs yet',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start recording to create logs',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLogs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: InkWell(
                          onTap: () {
                            _showLogDetails(log);
                          },
                          child: ListTile(
                            leading: _buildThumbnail(log.imagePath),
                            title: Text(
                              log.transcript.isEmpty
                                  ? '(No transcript)'
                                  : (log.transcript.length > 50
                                      ? '${log.transcript.substring(0, 50)}...'
                                      : log.transcript),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _formatDateTime(log.createdAt),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.description),
                              color: Colors.blue,
                              onPressed: () => _generateReport(log),
                              tooltip: 'Generate Report',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'Just now';
        }
        return '${diff.inMinutes} minutes ago';
      }
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return dateTime.toLocal().toString().substring(0, 16);
    }
  }

  Widget _buildThumbnail(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return const CircleAvatar(
        backgroundColor: Colors.grey,
        child: Icon(Icons.broken_image, color: Colors.white),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        file,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const CircleAvatar(
            backgroundColor: Colors.grey,
            child: Icon(Icons.broken_image, color: Colors.white),
          );
        },
      ),
    );
  }

  void _showLogDetails(LogEntry log) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Log Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Transcript:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(log.transcript.isEmpty ? '(No transcript)' : log.transcript),
                ),
              ),
              const SizedBox(height: 16),
              if (log.imagePath.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(log.imagePath),
                    width: 300,
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Time: ${log.createdAt.toLocal().toString()}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _generateReport(log);
                    },
                    icon: const Icon(Icons.description),
                    label: const Text('Generate Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateReport(LogEntry log) async {
    // Check if image exists
    if (log.imagePath.isEmpty) {
      _showSnackBar('Cannot generate report: No image found in this log entry.');
      return;
    }

    // Check if transcript is empty
    if (log.transcript.trim().isEmpty) {
      _showSnackBar('Cannot generate report: Transcript is empty.');
      return;
    }

    // Show generating dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(
              child: Text('Generating professional building inspection report...\nThis may take a moment.'),
            ),
          ],
        ),
      ),
    );

    try {
      // Prepare image paths
      List<String> imagePaths = [];
      if (log.imagePath.isNotEmpty) {
        final file = File(log.imagePath);
        if (await file.exists()) {
          imagePaths.add(log.imagePath);
        }
      }

      if (imagePaths.isEmpty) {
        if (mounted) Navigator.pop(context); // Close loading dialog
        if (mounted) _showSnackBar('Error: Image file not found.');
        return;
      }

      // Ensure service is initialized before generating report
      if (!_reportService.isInitialized) {
        _reportService.initialize();
      }

      // Generate report content using OpenAI
      String reportContent = await _reportService.generateReportContent(
        log.transcript,
        imagePaths,
      );

      // Generate PDF
      final pdfBytes = await _reportService.generatePDF(
        reportContent,
        log.transcript,
        imagePaths,
        log.createdAt,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Preview and print PDF
      if (!mounted) return;
      await _reportService.previewAndPrintPDF(pdfBytes, context);
      if (!mounted) return;
      _showSnackBar('Report generated successfully!');
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }
      _showSnackBar('Error generating report: $e');
      debugPrint('Error generating report: $e');
    }
  }

  Future<void> _generateReportFromAllLogs() async {
    // Filter logs that have images
    List<LogEntry> logsWithImages = _logs.where((log) => log.imagePath.isNotEmpty).toList();

    if (logsWithImages.isEmpty) {
      _showSnackBar('Cannot generate report: No logs with images found.');
      return;
    }

    // Check if any logs have transcripts
    bool hasTranscripts = logsWithImages.any((log) => log.transcript.trim().isNotEmpty);
    if (!hasTranscripts) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Transcripts Found'),
          content: const Text(
            'None of the logs have transcripts. You can still generate a report based on images only. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }

    // Show generating dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Generating comprehensive report from ${logsWithImages.length} log${logsWithImages.length > 1 ? 's' : ''}...\nThis may take a moment.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    try {
      // Ensure service is initialized
      if (!_reportService.isInitialized) {
        _reportService.initialize();
      }

      // Generate report content from all logs
      String reportContent = await _reportService.generateReportContentFromAllLogs(logsWithImages);

      // Generate PDF
      final pdfBytes = await _reportService.generatePDFFromAllLogs(
        reportContent,
        logsWithImages,
        DateTime.now(),
      );

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // Preview and print PDF
      if (!mounted) return;
      await _reportService.previewAndPrintPDF(pdfBytes, context);
      if (!mounted) return;
      _showSnackBar('Report generated successfully from ${logsWithImages.length} log${logsWithImages.length > 1 ? 's' : ''}!');
    } catch (e) {
      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error generating report: $e');
      debugPrint('Error generating report from all logs: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.contains('Error') ? Colors.red : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
