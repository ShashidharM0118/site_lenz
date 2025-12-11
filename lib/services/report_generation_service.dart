import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'openai_service.dart';
import 'log_storage_service.dart';

class ReportGenerationService {
  final OpenAIService _openAIService = OpenAIService();
  bool _isInitialized = false;

  void initialize() {
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey != null && apiKey.isNotEmpty && apiKey != 'your_api_key_here') {
        _openAIService.initialize(apiKey: apiKey);
        _openAIService.setModel('gpt-4o'); // Use GPT-4o for better analysis
        _isInitialized = true;
      } else {
        _isInitialized = false;
      }
    } catch (e) {
      _isInitialized = false;
    }
  }

  bool get isInitialized => _isInitialized;

  Future<String> generateReportContent(String transcript, List<String> imagePaths) async {
    // Ensure we're initialized
    if (!_isInitialized) {
      initialize();
    }
    
    // Double check initialization
    if (!_isInitialized) {
      // Try to reload dotenv and initialize again
      try {
        // Check if dotenv is available
        final apiKey = dotenv.env['OPENAI_API_KEY'];
        if (apiKey != null && apiKey.isNotEmpty && apiKey != 'your_api_key_here') {
          _openAIService.initialize(apiKey: apiKey);
          _openAIService.setModel('gpt-4o');
          _isInitialized = true;
        } else {
          throw Exception('OpenAI API key not found in .env file. Please ensure OPENAI_API_KEY is set.');
        }
      } catch (e) {
        throw Exception('Failed to initialize OpenAI service: $e. Please check your .env file and API key.');
      }
    }

    // Read images and convert to base64
    List<String> base64Images = [];
    for (String imagePath in imagePaths) {
      final file = File(imagePath);
      if (await file.exists()) {
        final imageBytes = await file.readAsBytes();
        final base64Image = base64Encode(imageBytes);
        base64Images.add(base64Image);
      }
    }

    // Create a detailed prompt for building inspection report
    final StringBuffer promptBuffer = StringBuffer();
    promptBuffer.writeln('You are a professional building inspector. Analyze the provided images of walls and the inspector\'s transcript/notes to create a comprehensive Building Inspection Report.');
    promptBuffer.writeln();
    promptBuffer.writeln('The transcript/notes from the inspector are: $transcript');
    promptBuffer.writeln();
    promptBuffer.writeln('Please analyze the wall images and create a professional building inspection report with the following structure:');
    promptBuffer.writeln();
    promptBuffer.writeln('1. EXECUTIVE SUMMARY');
    promptBuffer.writeln('   - Overall condition assessment');
    promptBuffer.writeln('   - Key findings');
    promptBuffer.writeln('   - Risk level (Low/Medium/High)');
    promptBuffer.writeln();
    promptBuffer.writeln('2. PROPERTY INFORMATION');
    promptBuffer.writeln('   - Inspection date (use current date)');
    promptBuffer.writeln('   - Inspector notes summary');
    promptBuffer.writeln();
    promptBuffer.writeln('3. DETAILED FINDINGS');
    promptBuffer.writeln('   - For each issue identified in the images:');
    promptBuffer.writeln('     * Location/Area');
    promptBuffer.writeln('     * Description of the condition');
    promptBuffer.writeln('     * Severity assessment');
    promptBuffer.writeln('     * Recommended actions');
    promptBuffer.writeln();
    promptBuffer.writeln('4. WALL CONDITIONS');
    promptBuffer.writeln('   - Structural integrity observations');
    promptBuffer.writeln('   - Surface conditions (cracks, damage, moisture, etc.)');
    promptBuffer.writeln('   - Material condition');
    promptBuffer.writeln('   - Any visible defects');
    promptBuffer.writeln();
    promptBuffer.writeln('5. RECOMMENDATIONS');
    promptBuffer.writeln('   - Immediate actions required');
    promptBuffer.writeln('   - Short-term maintenance');
    promptBuffer.writeln('   - Long-term considerations');
    promptBuffer.writeln();
    promptBuffer.writeln('6. CONCLUSION');
    promptBuffer.writeln('   - Overall assessment');
    promptBuffer.writeln('   - Compliance notes');
    promptBuffer.writeln('   - Additional remarks');
    promptBuffer.writeln();
    promptBuffer.writeln('Format the report professionally with clear sections, detailed descriptions, and actionable recommendations. Be thorough and professional in your analysis. Use proper building inspection terminology.');
    
    String prompt = promptBuffer.toString();

    // Generate report using OpenAI
    String? reportContent = await _openAIService.generateText(prompt, imageBase64: base64Images);
    
    if (reportContent == null || reportContent.isEmpty) {
      throw Exception('Failed to generate report content from OpenAI');
    }

    return reportContent;
  }

  Future<String> generateReportContentFromAllLogs(List<LogEntry> logs) async {
    // Ensure we're initialized
    if (!_isInitialized) {
      initialize();
    }
    
    // Double check initialization
    if (!_isInitialized) {
      try {
        final apiKey = dotenv.env['OPENAI_API_KEY'];
        if (apiKey != null && apiKey.isNotEmpty && apiKey != 'your_api_key_here') {
          _openAIService.initialize(apiKey: apiKey);
          _openAIService.setModel('gpt-4o');
          _isInitialized = true;
        } else {
          throw Exception('OpenAI API key not found in .env file. Please ensure OPENAI_API_KEY is set.');
        }
      } catch (e) {
        throw Exception('Failed to initialize OpenAI service: $e. Please check your .env file and API key.');
      }
    }

    // Collect all images and transcripts
    List<String> allImagePaths = [];
    List<String> allTranscripts = [];
    Map<String, DateTime> imageToDateMap = {}; // Track which image belongs to which date
    
    for (LogEntry log in logs) {
      if (log.imagePath.isNotEmpty) {
        final file = File(log.imagePath);
        if (await file.exists()) {
          allImagePaths.add(log.imagePath);
          imageToDateMap[log.imagePath] = log.createdAt;
        }
      }
      if (log.transcript.trim().isNotEmpty) {
        allTranscripts.add('${log.createdAt.toLocal().toString().split('.')[0]}: ${log.transcript}');
      }
    }

    if (allImagePaths.isEmpty) {
      throw Exception('No images found in any logs. Cannot generate report without images.');
    }

    // Read all images and convert to base64
    List<String> base64Images = [];
    for (String imagePath in allImagePaths) {
      final file = File(imagePath);
      if (await file.exists()) {
        final imageBytes = await file.readAsBytes();
        final base64Image = base64Encode(imageBytes);
        base64Images.add(base64Image);
      }
    }

    // Combine all transcripts
    String combinedTranscript = allTranscripts.join('\n\n---\n\n');

    // Create a comprehensive prompt for building inspection report from multiple logs
    final StringBuffer promptBuffer = StringBuffer();
    promptBuffer.writeln('You are a professional building inspector. Analyze ALL the provided images of walls and the inspector\'s transcripts/notes from multiple inspection sessions to create a comprehensive Building Inspection Report.');
    promptBuffer.writeln();
    promptBuffer.writeln('The inspector has captured ${allImagePaths.length} images and provided the following transcripts/notes from multiple inspection sessions:');
    promptBuffer.writeln();
    promptBuffer.writeln(combinedTranscript);
    promptBuffer.writeln();
    promptBuffer.writeln('Please analyze ALL the wall images (there are ${allImagePaths.length} images total) and create a comprehensive, unified building inspection report that consolidates findings from all inspection sessions. The report should follow this structure:');
    promptBuffer.writeln();
    promptBuffer.writeln('1. EXECUTIVE SUMMARY');
    promptBuffer.writeln('   - Overall condition assessment across all inspection sessions');
    promptBuffer.writeln('   - Key findings from all images');
    promptBuffer.writeln('   - Risk level assessment (Low/Medium/High)');
    promptBuffer.writeln('   - Summary of areas inspected');
    promptBuffer.writeln();
    promptBuffer.writeln('2. PROPERTY INFORMATION');
    promptBuffer.writeln('   - Inspection period (date range covering all sessions)');
    promptBuffer.writeln('   - Number of inspection sessions conducted');
    promptBuffer.writeln('   - Total number of images analyzed');
    promptBuffer.writeln('   - Inspector notes summary from all sessions');
    promptBuffer.writeln();
    promptBuffer.writeln('3. DETAILED FINDINGS');
    promptBuffer.writeln('   - For each issue identified across ALL images:');
    promptBuffer.writeln('     * Location/Area (reference which inspection session if applicable)');
    promptBuffer.writeln('     * Description of the condition');
    promptBuffer.writeln('     * Severity assessment');
    promptBuffer.writeln('     * Recommended actions');
    promptBuffer.writeln('   - Group similar findings together');
    promptBuffer.writeln('   - Note any patterns or recurring issues across sessions');
    promptBuffer.writeln();
    promptBuffer.writeln('4. WALL CONDITIONS');
    promptBuffer.writeln('   - Structural integrity observations from all images');
    promptBuffer.writeln('   - Surface conditions (cracks, damage, moisture, etc.)');
    promptBuffer.writeln('   - Material condition across different areas');
    promptBuffer.writeln('   - Comparison of conditions across different inspection sessions (if applicable)');
    promptBuffer.writeln('   - Any visible defects found in any of the images');
    promptBuffer.writeln();
    promptBuffer.writeln('5. RECOMMENDATIONS');
    promptBuffer.writeln('   - Immediate actions required');
    promptBuffer.writeln('   - Short-term maintenance');
    promptBuffer.writeln('   - Long-term considerations');
    promptBuffer.writeln('   - Priority actions based on severity');
    promptBuffer.writeln();
    promptBuffer.writeln('6. CONCLUSION');
    promptBuffer.writeln('   - Overall assessment of the property based on all inspection sessions');
    promptBuffer.writeln('   - Compliance notes');
    promptBuffer.writeln('   - Additional remarks');
    promptBuffer.writeln();
    promptBuffer.writeln('Format the report professionally with clear sections, detailed descriptions, and actionable recommendations. Be thorough and professional in your analysis. Use proper building inspection terminology. Make sure to reference findings from multiple sessions where applicable.');
    
    String prompt = promptBuffer.toString();

    // Generate report using OpenAI with all images
    String? reportContent = await _openAIService.generateText(prompt, imageBase64: base64Images);
    
    if (reportContent == null || reportContent.isEmpty) {
      throw Exception('Failed to generate report content from OpenAI');
    }

    return reportContent;
  }

  Future<Uint8List> generatePDFFromAllLogs(String reportContent, List<LogEntry> logs, DateTime reportDate) async {
    final pdf = pw.Document();
    
    // Collect all images and transcripts
    List<String> allImagePaths = [];
    List<String> allTranscripts = [];
    List<DateTime> inspectionDates = [];
    
    for (LogEntry log in logs) {
      if (log.imagePath.isNotEmpty) {
        final file = File(log.imagePath);
        if (await file.exists()) {
          allImagePaths.add(log.imagePath);
        }
      }
      if (log.transcript.trim().isNotEmpty) {
        allTranscripts.add(log.transcript);
      }
      inspectionDates.add(log.createdAt);
    }

    // Helper function to load and process images
    Future<List<pw.ImageProvider>> loadImages() async {
      List<pw.ImageProvider> providers = [];
      for (String imagePath in allImagePaths) {
        final file = File(imagePath);
        if (await file.exists()) {
          final imageBytes = await file.readAsBytes();
          final image = img.decodeImage(imageBytes);
          if (image != null) {
            // Resize image if too large (max width 500px)
            img.Image resizedImage = image;
            if (image.width > 500) {
              resizedImage = img.copyResize(image, width: 500);
            }
            final resizedBytes = img.encodeJpg(resizedImage, quality: 85);
            providers.add(pw.MemoryImage(resizedBytes));
          }
        }
      }
      return providers;
    }

    final imageProviders = await loadImages();

    // Parse report content into sections
    final sections = _parseReportSections(reportContent);

    // Determine date range
    DateTime? earliestDate = inspectionDates.isNotEmpty ? inspectionDates.reduce((a, b) => a.isBefore(b) ? a : b) : null;
    DateTime? latestDate = inspectionDates.isNotEmpty ? inspectionDates.reduce((a, b) => a.isAfter(b) ? a : b) : null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Cover Page / Header
            _buildHeaderForAllLogs(reportDate, earliestDate, latestDate, logs.length, allImagePaths.length),
            pw.SizedBox(height: 20),
            
            // Table of Contents
            if (sections.isNotEmpty) ...[
              _buildTableOfContents(sections),
              pw.SizedBox(height: 20),
            ],

            // Executive Summary
            if (sections.containsKey('EXECUTIVE SUMMARY')) ...[
              _buildSectionTitle('1. EXECUTIVE SUMMARY'),
              pw.SizedBox(height: 10),
              _buildSectionContent(sections['EXECUTIVE SUMMARY']!),
              pw.SizedBox(height: 20),
            ],

            // Property Information
            _buildSectionTitle('2. PROPERTY INFORMATION'),
            pw.SizedBox(height: 10),
            _buildPropertyInfoForAllLogs(earliestDate, latestDate, logs.length, allImagePaths.length, allTranscripts),
            pw.SizedBox(height: 20),

            // Images Section
            if (imageProviders.isNotEmpty) ...[
              _buildSectionTitle('3. INSPECTION IMAGES (${allImagePaths.length} Images)'),
              pw.SizedBox(height: 10),
              ...imageProviders.asMap().entries.map((entry) {
                int index = entry.key + 1;
                return pw.Column(
                  children: [
                    pw.Text(
                      'Image $index of ${imageProviders.length}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 15),
                      child: pw.Center(
                        child: pw.Image(entry.value, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ],
                );
              }),
              pw.SizedBox(height: 20),
            ],

            // Detailed Findings
            if (sections.containsKey('DETAILED FINDINGS')) ...[
              _buildSectionTitle('4. DETAILED FINDINGS'),
              pw.SizedBox(height: 10),
              _buildSectionContent(sections['DETAILED FINDINGS']!),
              pw.SizedBox(height: 20),
            ],

            // Wall Conditions
            if (sections.containsKey('WALL CONDITIONS')) ...[
              _buildSectionTitle('5. WALL CONDITIONS'),
              pw.SizedBox(height: 10),
              _buildSectionContent(sections['WALL CONDITIONS']!),
              pw.SizedBox(height: 20),
            ],

            // Recommendations
            if (sections.containsKey('RECOMMENDATIONS')) ...[
              _buildSectionTitle('6. RECOMMENDATIONS'),
              pw.SizedBox(height: 10),
              _buildSectionContent(sections['RECOMMENDATIONS']!),
              pw.SizedBox(height: 20),
            ],

            // Conclusion
            if (sections.containsKey('CONCLUSION')) ...[
              _buildSectionTitle('7. CONCLUSION'),
              pw.SizedBox(height: 10),
              _buildSectionContent(sections['CONCLUSION']!),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generatePDF(String reportContent, String transcript, List<String> imagePaths, DateTime inspectionDate) async {
    final pdf = pw.Document();
    
    // Helper function to load and process images
    Future<List<pw.ImageProvider>> loadImages() async {
      List<pw.ImageProvider> providers = [];
      for (String imagePath in imagePaths) {
        final file = File(imagePath);
        if (await file.exists()) {
          final imageBytes = await file.readAsBytes();
          final image = img.decodeImage(imageBytes);
          if (image != null) {
            // Resize image if too large (max width 500px)
            img.Image resizedImage = image;
            if (image.width > 500) {
              resizedImage = img.copyResize(image, width: 500);
            }
            final resizedBytes = img.encodeJpg(resizedImage, quality: 85);
            providers.add(pw.MemoryImage(resizedBytes));
          }
        }
      }
      return providers;
    }

    final imageProviders = await loadImages();

    // Parse report content into sections
    final sections = _parseReportSections(reportContent);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Cover Page / Header
            _buildHeader(inspectionDate),
            pw.SizedBox(height: 20),
            
            // Table of Contents
            if (sections.isNotEmpty) ...[
              _buildTableOfContents(sections),
              pw.SizedBox(height: 20),
            ],

            // Executive Summary
            if (sections.containsKey('EXECUTIVE SUMMARY')) ...[
              _buildSectionTitle('1. EXECUTIVE SUMMARY'),
              pw.SizedBox(height: 10),
              _buildSectionContent(sections['EXECUTIVE SUMMARY']!),
              pw.SizedBox(height: 20),
            ],

            // Property Information
            _buildSectionTitle('2. PROPERTY INFORMATION'),
            pw.SizedBox(height: 10),
            _buildPropertyInfo(inspectionDate, transcript),
            pw.SizedBox(height: 20),

            // Images Section
            if (imageProviders.isNotEmpty) ...[
              _buildSectionTitle('3. INSPECTION IMAGES'),
              pw.SizedBox(height: 10),
              ...imageProviders.map((img) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Center(
                  child: pw.Image(img, fit: pw.BoxFit.contain),
                ),
              )),
              pw.SizedBox(height: 20),
            ],

            // Detailed Findings
            if (sections.containsKey('DETAILED FINDINGS')) ...[
              _buildSectionTitle('4. DETAILED FINDINGS'),
              pw.SizedBox(height: 10),
              _buildSectionContent(sections['DETAILED FINDINGS']!),
              pw.SizedBox(height: 20),
            ],

            // Wall Conditions
            if (sections.containsKey('WALL CONDITIONS')) ...[
              _buildSectionTitle('5. WALL CONDITIONS'),
              pw.SizedBox(height: 10),
              _buildSectionContent(sections['WALL CONDITIONS']!),
              pw.SizedBox(height: 20),
            ],

            // Recommendations
            if (sections.containsKey('RECOMMENDATIONS')) ...[
              _buildSectionTitle('6. RECOMMENDATIONS'),
              pw.SizedBox(height: 10),
              _buildSectionContent(sections['RECOMMENDATIONS']!),
              pw.SizedBox(height: 20),
            ],

            // Conclusion
            if (sections.containsKey('CONCLUSION')) ...[
              _buildSectionTitle('7. CONCLUSION'),
              pw.SizedBox(height: 10),
              _buildSectionContent(sections['CONCLUSION']!),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(DateTime inspectionDate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'BUILDING INSPECTION REPORT',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.blue900, thickness: 2),
        pw.SizedBox(height: 15),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Inspection Date: ${inspectionDate.toLocal().toString().split(' ')[0]}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.Text(
              'Report Generated: ${DateTime.now().toLocal().toString().split(' ')[0]}',
              style: const pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildHeaderForAllLogs(DateTime reportDate, DateTime? earliestDate, DateTime? latestDate, int logCount, int imageCount) {
    String dateRange = '';
    if (earliestDate != null && latestDate != null) {
      if (earliestDate == latestDate) {
        dateRange = earliestDate.toLocal().toString().split(' ')[0];
      } else {
        dateRange = '${earliestDate.toLocal().toString().split(' ')[0]} to ${latestDate.toLocal().toString().split(' ')[0]}';
      }
    }
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'COMPREHENSIVE BUILDING INSPECTION REPORT',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.blue900, thickness: 2),
        pw.SizedBox(height: 15),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (dateRange.isNotEmpty)
                  pw.Text(
                    'Inspection Period: $dateRange',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                pw.Text(
                  'Inspection Sessions: $logCount',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Images Analyzed: $imageCount',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
            pw.Text(
              'Report Generated: ${reportDate.toLocal().toString().split(' ')[0]}',
              style: const pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableOfContents(Map<String, String> sections) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TABLE OF CONTENTS',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          ...sections.keys.toList().asMap().entries.map((entry) {
            int index = entry.key + 1;
            String section = entry.value;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Text(
                '$index. $section',
                style: const pw.TextStyle(fontSize: 11),
              ),
            );
          }),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue100,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
    );
  }

  pw.Widget _buildSectionContent(String content) {
    // Split content into paragraphs and format
    final paragraphs = content.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: paragraphs.map((para) {
        // Check if it's a bullet point
        if (para.trim().startsWith('-') || para.trim().startsWith('*')) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 20, bottom: 8),
            child: pw.Text(
              para.trim(),
              style: const pw.TextStyle(fontSize: 11),
            ),
          );
        }
        // Check if it's a heading (all caps or starts with number)
        if (para.length < 100 && (para.toUpperCase() == para || RegExp(r'^\d+\.').hasMatch(para))) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              para.trim(),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          );
        }
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            para.trim(),
            style: const pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.justify,
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildPropertyInfo(DateTime inspectionDate, String transcript) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Inspection Date: ',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                inspectionDate.toLocal().toString().split('.')[0],
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Inspector Notes:',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            transcript.isEmpty ? 'No additional notes provided.' : transcript,
            style: const pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPropertyInfoForAllLogs(DateTime? earliestDate, DateTime? latestDate, int logCount, int imageCount, List<String> transcripts) {
    String dateRange = '';
    if (earliestDate != null && latestDate != null) {
      if (earliestDate == latestDate) {
        dateRange = earliestDate.toLocal().toString().split(' ')[0];
      } else {
        dateRange = '${earliestDate.toLocal().toString().split(' ')[0]} to ${latestDate.toLocal().toString().split(' ')[0]}';
      }
    }
    
    String combinedTranscripts = transcripts.join('\n\n--- Session Break ---\n\n');
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (dateRange.isNotEmpty) ...[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Inspection Period: ',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  dateRange,
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
          ],
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Number of Sessions: ',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '$logCount',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Total Images: ',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '$imageCount',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Inspector Notes (All Sessions):',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            combinedTranscripts.isEmpty ? 'No additional notes provided.' : combinedTranscripts,
            style: const pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  Map<String, String> _parseReportSections(String content) {
    Map<String, String> sections = {};
    
    // Common section headers
    final sectionPatterns = [
      'EXECUTIVE SUMMARY',
      'DETAILED FINDINGS',
      'WALL CONDITIONS',
      'RECOMMENDATIONS',
      'CONCLUSION',
    ];

    String remainingContent = content;
    
    for (int i = 0; i < sectionPatterns.length; i++) {
      final pattern = sectionPatterns[i];
      final regex = RegExp(r'(?i)(?:^|\n)\s*(\d+\.)?\s*' + pattern.replaceAll(' ', r'\s+') + r'[:\-]?\s*\n', multiLine: true);
      
      final match = regex.firstMatch(remainingContent);
      if (match != null) {
        final startIndex = match.end;
        // Find the next section or end of content
        String sectionContent;
        
        if (i < sectionPatterns.length - 1) {
          final nextPattern = sectionPatterns[i + 1];
          final nextRegex = RegExp(r'(?i)(?:^|\n)\s*(\d+\.)?\s*' + nextPattern.replaceAll(' ', r'\s+') + r'[:\-]?\s*\n', multiLine: true);
          final nextMatch = nextRegex.firstMatch(remainingContent.substring(startIndex));
          
          if (nextMatch != null) {
            sectionContent = remainingContent.substring(startIndex, startIndex + nextMatch.start).trim();
          } else {
            sectionContent = remainingContent.substring(startIndex).trim();
          }
        } else {
          sectionContent = remainingContent.substring(startIndex).trim();
        }
        
        sections[pattern] = sectionContent;
        remainingContent = remainingContent.substring(startIndex + sectionContent.length);
      }
    }

    // If no sections found, return the whole content as a single section
    if (sections.isEmpty) {
      sections['REPORT CONTENT'] = content;
    }

    return sections;
  }

  Future<void> previewAndPrintPDF(Uint8List pdfBytes, BuildContext context) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

}

