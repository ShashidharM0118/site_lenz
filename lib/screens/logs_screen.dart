import 'dart:io';

import 'package:flutter/material.dart';
import '../services/log_storage_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> with AutomaticKeepAliveClientMixin {
  final LogStorageService _logStorage = LogStorageService();
  List<LogEntry> _logs = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
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
                            // Show full log details
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Transcript',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(log.transcript),
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
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
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
}
