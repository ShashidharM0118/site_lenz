import 'dart:io';
import 'package:flutter/material.dart';
import '../services/log_storage_service.dart';
import '../services/report_generation_service.dart';
import '../services/image_analysis_service.dart';
import '../widgets/animated_report_loader.dart';
import '../theme/app_theme.dart';

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

  Future<void> _deleteLog(LogEntry log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Log'),
        content: const Text('Are you sure you want to delete this log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logStorage.deleteLog(log);
      await _loadLogs();
      _showSnackBar('Log deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Logs',
            onPressed: _loadLogs,
          ),
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearLogs,
              tooltip: 'Clear Logs',
            ),
        ],
      ),
      bottomNavigationBar: _logs.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generateReportFromAllLogs,
                  icon: const Icon(Icons.description),
                  label: const Text(
                    'Generate Report (All Logs)',
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 80, color: AppTheme.iconGrey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'No logs yet',
                        style: TextStyle(color: AppTheme.textGrey, fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start recording to create logs',
                        style: TextStyle(color: AppTheme.textGrey.withOpacity(0.7), fontSize: 14),
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
                        child: InkWell(
                          onTap: () {
                            _showLogDetails(log);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                _buildThumbnail(log.imagePath),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log.transcript.isEmpty
                                            ? '(No transcript)'
                                            : (log.transcript.length > 50
                                                ? '${log.transcript.substring(0, 50)}...'
                                                : log.transcript),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDateTime(log.createdAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _generateReport(log),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        side: BorderSide(color: AppTheme.primaryPurple, width: 1.5),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.description, size: 18),
                                          SizedBox(width: 4),
                                          Text('Report', style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => _deleteLog(log),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                                        foregroundColor: Colors.redAccent,
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.delete_outline, size: 18),
                                          SizedBox(width: 4),
                                          Text('Delete', style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.borderGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.broken_image, color: AppTheme.iconGrey),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        file,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.borderGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.broken_image, color: AppTheme.iconGrey),
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
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _generateReport(log);
                    },
                    icon: const Icon(Icons.description),
                    label: const Text(
                      'Generate Report',
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteLog(log);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Log'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      side: const BorderSide(color: Colors.redAccent, width: 1.2),
                      foregroundColor: Colors.redAccent,
                    ),
                  ),
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
      // Only show snackbar if widget is still mounted
      if (mounted) {
        _showSnackBar('Error generating report: $e');
      }
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

    // Ask user to choose image analysis provider (Gemini or OpenAI)
    ImageAnalysisProvider? selectedProvider;
    final providerChoice = await showDialog<ImageAnalysisProvider>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Analysis Provider'),
        content: const Text(
          'Choose which AI service to use for analyzing images:\n\n'
          '• OpenAI (Recommended): GPT-4o vision model\n'
          '• Gemini: Gemini 2.5 Flash vision model\n\n'
          'Groq will be used for generating the comprehensive report content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageAnalysisProvider.openai),
            child: const Text('OpenAI (GPT-4o)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageAnalysisProvider.gemini),
            child: const Text('Gemini'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (providerChoice == null) {
      return; // User cancelled
    }

    selectedProvider = providerChoice;
    
    // Set the selected provider in the report service
    _reportService.setImageAnalysisProvider(selectedProvider);

    // Show generating dialog with progress
    if (!mounted) return;

    String progressMessage = 'Initializing AI systems...';
    int totalSteps = logsWithImages.length + 5; // Images + report generation stages
    int currentStep = 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Set up progress callback
          _reportService.onProgressUpdate = (message) {
            setDialogState(() {
              progressMessage = message;
              
              // Calculate progress based on message content
              if (message.contains('Analyzing image')) {
                // Extract image number if present
                final match = RegExp(r'(\d+)').firstMatch(message);
                if (match != null) {
                  currentStep = int.tryParse(match.group(1) ?? '0') ?? currentStep;
                }
              } else if (message.contains('Generating comprehensive report')) {
                currentStep = logsWithImages.length + 1;
              } else if (message.contains('Creating PDF')) {
                currentStep = logsWithImages.length + 2;
              } else if (message.contains('Formatting')) {
                currentStep = logsWithImages.length + 3;
              } else if (message.contains('Finalizing')) {
                currentStep = logsWithImages.length + 4;
              }
            });
          };
          
          return AnimatedReportLoader(
            currentMessage: progressMessage,
            totalSteps: totalSteps,
            currentStep: currentStep,
          );
        },
      ),
    );

    try {
      // Ensure service is initialized
      if (!_reportService.isInitialized) {
        _reportService.initialize();
      }

      // Generate report content from all logs (includes image analyses)
      // This will use the two-stage pipeline: Gemini for images, then Groq for comprehensive report
      String reportContent = await _reportService.generateReportContentFromAllLogs(logsWithImages);

      // Get image analyses (these are stored during report generation)
      // We need to regenerate or pass them - let's update the method
      // For now, generate PDF with the report content
      final pdfBytes = await _reportService.generatePDFFromAllLogsWithAnalyses(
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
