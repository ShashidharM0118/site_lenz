import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'gemini_service.dart';
import 'groq_service.dart';
import 'image_analysis_service.dart';
import 'log_storage_service.dart';

class ReportGenerationService {
  final GeminiAIService _geminiService = GeminiAIService();
  final GroqAIService _groqService = GroqAIService();
  final ImageAnalysisService _imageAnalysisService = ImageAnalysisService();
  bool _isInitialized = false;
  bool _groqInitialized = false;
  
  // Callback for progress updates
  Function(String)? onProgressUpdate;
  
  // Store image analyses for PDF generation
  List<ImageAnalysisResult> _lastImageAnalyses = [];

  void initialize() {
    try {
      print('ReportGenerationService: Initializing services...');
      
      // Initialize Gemini for image analysis
      final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
      print('GEMINI_API_KEY from dotenv: ${geminiApiKey != null ? "Found (${geminiApiKey.length} chars)" : "NULL"}');
      
      if (geminiApiKey != null && geminiApiKey.isNotEmpty && geminiApiKey != 'your_api_key_here') {
        _geminiService.initialize(apiKey: geminiApiKey);
        _geminiService.setModel('gemini-2.5-flash');
        _imageAnalysisService.initialize();
        _isInitialized = _imageAnalysisService.isInitialized; // Check if it actually initialized
        print('✓ Gemini initialized, ImageAnalysis.isInitialized = ${_imageAnalysisService.isInitialized}');
      } else {
        _isInitialized = false;
        print('✗ Gemini API key not valid');
      }
      
      // Initialize Groq for comprehensive report generation
      final groqApiKey = dotenv.env['GROQ_API_KEY'];
      print('GROQ_API_KEY from dotenv: ${groqApiKey != null ? "Found (${groqApiKey.length} chars)" : "NULL"}');
      
      if (groqApiKey != null && groqApiKey.isNotEmpty && groqApiKey != 'your_api_key_here') {
        _groqService.initialize(apiKey: groqApiKey);
        _groqService.setModel('llama-3.3-70b-versatile'); // Use largest model for detailed reports
        _groqInitialized = _groqService.isInitialized; // Verify actual initialization status
        print('✓ Groq initialized: $_groqInitialized');
      } else {
        _groqInitialized = false;
        print('✗ Groq API key not valid');
      }
    } catch (e) {
      _isInitialized = false;
      _groqInitialized = false;
      print('✗ Error during initialization: $e');
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
        final apiKey = dotenv.env['GEMINI_API_KEY'];
        if (apiKey != null && apiKey.isNotEmpty && apiKey != 'your_api_key_here') {
          _geminiService.initialize(apiKey: apiKey);
          _geminiService.setModel('gemini-2.5-flash'); // Use Gemini 2.5 Flash - best for multimodal (3+ images) with 250K TPM
          _isInitialized = true;
        } else {
          throw Exception('Gemini API key not found in .env file. Please ensure GEMINI_API_KEY is set.');
        }
      } catch (e) {
        throw Exception('Failed to initialize Gemini service: $e. Please check your .env file and API key.');
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

    // Generate report using Gemini
    String? reportContent = await _geminiService.generateText(prompt, imageBase64: base64Images);
    
    if (reportContent == null || reportContent.isEmpty) {
      throw Exception('Failed to generate report content from Gemini');
    }

    return reportContent;
  }

  Future<String> generateReportContentFromAllLogs(List<LogEntry> logs) async {
    // Ensure services are initialized
    if (!_isInitialized) {
      initialize();
    }
    
      // Debug: Check what we have
      print('Checking services initialization...');
      print('_isInitialized: $_isInitialized');
      print('_imageAnalysisService.isInitialized: ${_imageAnalysisService.isInitialized}');
      print('_groqInitialized: $_groqInitialized');
      print('_groqService.isInitialized: ${_groqService.isInitialized}');
      print('dotenv.env[GEMINI_API_KEY]: ${dotenv.env['GEMINI_API_KEY'] != null ? "Exists" : "NULL"}');
      print('dotenv.env[GROQ_API_KEY]: ${dotenv.env['GROQ_API_KEY'] != null ? "Exists" : "NULL"}');
      
      // Try to initialize if not already
      if (!_isInitialized || !_imageAnalysisService.isInitialized || !_groqInitialized) {
        print('Re-initializing services...');
        initialize();
        
        // Wait a moment for initialization
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Re-check initialization status after calling initialize()
        _groqInitialized = _groqService.isInitialized;
        _isInitialized = _imageAnalysisService.isInitialized;
      }
      
      if (!_isInitialized || !_imageAnalysisService.isInitialized) {
        throw Exception('Gemini API key not configured. Please ensure GEMINI_API_KEY is set in .env file and restart the app.');
      }
      
      if (!_groqInitialized || !_groqService.isInitialized) {
        throw Exception('Groq API key not configured. Please ensure GROQ_API_KEY is set in .env file for detailed report generation and restart the app.');
      }

    // Collect all images and transcripts
    List<String> allImagePaths = [];
    List<String> allTranscripts = [];
    
    for (LogEntry log in logs) {
      if (log.imagePath.isNotEmpty) {
        final file = File(log.imagePath);
        if (await file.exists()) {
          allImagePaths.add(log.imagePath);
        }
      }
      if (log.transcript.trim().isNotEmpty) {
        allTranscripts.add('${log.createdAt.toLocal().toString().split('.')[0]}: ${log.transcript}');
      }
    }

    if (allImagePaths.isEmpty) {
      throw Exception('No images found in any logs. Cannot generate report without images.');
    }

    // === STAGE 1: INDIVIDUAL IMAGE ANALYSIS ===
    onProgressUpdate?.call('Stage 1: Analyzing images individually...');
    
    List<ImageAnalysisResult> imageAnalyses = [];
    for (int i = 0; i < allImagePaths.length; i++) {
      try {
        onProgressUpdate?.call('Analyzing image ${i + 1} of ${allImagePaths.length}...');
        
        final analysis = await _imageAnalysisService.analyzeImage(allImagePaths[i], i + 1);
        imageAnalyses.add(analysis);
        
        // Small delay between requests to avoid rate limiting
        if (i < allImagePaths.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        print('Warning: Failed to analyze image ${i + 1}: $e');
        // Continue with other images even if one fails
      }
    }

    if (imageAnalyses.isEmpty) {
      throw Exception('Failed to analyze any images. Cannot generate report.');
    }

    // === STAGE 2: COMPREHENSIVE REPORT GENERATION ===
    onProgressUpdate?.call('Stage 2: Generating comprehensive report with costs and estimates...');

    // Combine all transcripts
    String combinedTranscript = allTranscripts.isEmpty 
        ? 'No transcripts provided.' 
        : allTranscripts.join('\n\n---\n\n');

    // Format image analyses for Groq prompt
    final StringBuffer imageAnalysesText = StringBuffer();
    for (var analysis in imageAnalyses) {
      imageAnalysesText.writeln('\n--- IMAGE ${analysis.imageIndex} ANALYSIS ---');
      imageAnalysesText.writeln('Description: ${analysis.description}');
      imageAnalysesText.writeln('Material Type: ${analysis.materialType ?? "Unknown"}');
      imageAnalysesText.writeln('Overall Condition: ${analysis.overallCondition}');
      imageAnalysesText.writeln('\nDetected Defects:');
      
      if (analysis.defects.isEmpty) {
        imageAnalysesText.writeln('  - No defects detected');
      } else {
        for (var defect in analysis.defects) {
          imageAnalysesText.writeln('  * ${defect.type}');
          imageAnalysesText.writeln('    Location: ${defect.location}');
          imageAnalysesText.writeln('    Severity: ${defect.severity}');
          imageAnalysesText.writeln('    Confidence: ${defect.confidenceScore}%');
          imageAnalysesText.writeln('    Details: ${defect.description}');
        }
      }
      imageAnalysesText.writeln();
    }

    // Store image analyses for PDF generation
    _lastImageAnalyses = imageAnalyses;
    
    // Use Groq for comprehensive report generation
    String reportContent = await _generateComprehensiveReport(imageAnalyses, combinedTranscript, imageAnalysesText.toString());
    
    return reportContent;
  }

  // New method that includes image analyses in PDF
  Future<Uint8List> generatePDFFromAllLogsWithAnalyses(String reportContent, List<LogEntry> logs, DateTime reportDate) async {
    return await generatePDFFromAllLogs(reportContent, logs, reportDate, _lastImageAnalyses);
  }

  Future<String> _generateComprehensiveReport(List<ImageAnalysisResult> imageAnalyses, String userTranscript, String formattedImageAnalyses) async {
    // Create comprehensive prompt for Groq
    final StringBuffer promptBuffer = StringBuffer();
    
    promptBuffer.writeln('You are a professional building inspector creating a comprehensive building inspection report.');
    promptBuffer.writeln();
    promptBuffer.writeln('=== INSPECTOR TRANSCRIPT/NOTES ===');
    promptBuffer.writeln(userTranscript);
    promptBuffer.writeln();
    promptBuffer.writeln('=== DETAILED IMAGE ANALYSIS RESULTS ===');
    promptBuffer.writeln('The following ${imageAnalyses.length} images have been analyzed with AI-detected defects and confidence scores:');
    promptBuffer.writeln(formattedImageAnalyses);
    promptBuffer.writeln();
    promptBuffer.writeln('=== YOUR TASK ===');
    promptBuffer.writeln('Based on the image analyses and inspector notes, create a comprehensive professional building inspection report with the following sections:');
    promptBuffer.writeln();
    promptBuffer.writeln('1. EXECUTIVE SUMMARY');
    promptBuffer.writeln('   - Overall property condition');
    promptBuffer.writeln('   - Critical findings summary');
    promptBuffer.writeln('   - Risk level (Critical/High/Medium/Low)');
    promptBuffer.writeln('   - Total defects found across all images');
    promptBuffer.writeln();
    promptBuffer.writeln('2. DETAILED IMAGE ANALYSES');
    promptBuffer.writeln('   For each image analyzed:');
    promptBuffer.writeln('   - Image number and description');
    promptBuffer.writeln('   - Material type');
    promptBuffer.writeln('   - List of defects with confidence scores');
    promptBuffer.writeln('   - Condition assessment');
    promptBuffer.writeln();
    promptBuffer.writeln('3. COST ESTIMATES');
    promptBuffer.writeln('   For each defect/repair needed, provide:');
    promptBuffer.writeln('   - Defect type and location');
    promptBuffer.writeln('   - Estimated material cost (in USD)');
    promptBuffer.writeln('   - Estimated labor cost (in USD)');
    promptBuffer.writeln('   - Total cost for this repair');
    promptBuffer.writeln('   - Include a TOTAL ESTIMATED COST at the end');
    promptBuffer.writeln();
    promptBuffer.writeln('4. TIME ESTIMATES');
    promptBuffer.writeln('   For each repair:');
    promptBuffer.writeln('   - Repair description');
    promptBuffer.writeln('   - Estimated time to complete (in hours/days)');
    promptBuffer.writeln('   - Include TOTAL ESTIMATED TIME at the end');
    promptBuffer.writeln();
    promptBuffer.writeln('5. MATERIALS LIST');
    promptBuffer.writeln('   Itemized list of required materials:');
    promptBuffer.writeln('   - Material name');
    promptBuffer.writeln('   - Quantity needed');
    promptBuffer.writeln('   - Estimated unit cost');
    promptBuffer.writeln('   - Purpose/where it will be used');
    promptBuffer.writeln();
    promptBuffer.writeln('6. CONTRACTOR RECOMMENDATIONS');
    promptBuffer.writeln('   List of contractor types needed:');
    promptBuffer.writeln('   - Contractor type (e.g., Structural Engineer, Mason, Painter, Plasterer, etc.)');
    promptBuffer.writeln('   - Reason why this contractor is needed');
    promptBuffer.writeln('   - Urgency level (Immediate/Within 1 month/Within 3 months/Routine)');
    promptBuffer.writeln();
    promptBuffer.writeln('7. DETAILED FINDINGS');
    promptBuffer.writeln('   Comprehensive analysis of wall conditions:');
    promptBuffer.writeln('   - Structural integrity');
    promptBuffer.writeln('   - Surface conditions');
    promptBuffer.writeln('   - Material degradation');
    promptBuffer.writeln('   - Patterns across multiple images');
    promptBuffer.writeln();
    promptBuffer.writeln('8. RECOMMENDATIONS');
    promptBuffer.writeln('   - Immediate actions required (Critical/High severity items)');
    promptBuffer.writeln('   - Short-term maintenance (within 3 months)');
    promptBuffer.writeln('   - Long-term considerations');
    promptBuffer.writeln('   - Preventive measures');
    promptBuffer.writeln();
    promptBuffer.writeln('9. CONCLUSION');
    promptBuffer.writeln('   - Overall assessment');
    promptBuffer.writeln('   - Priority action items');
    promptBuffer.writeln('   - Final recommendations');
    promptBuffer.writeln();
    promptBuffer.writeln('IMPORTANT REQUIREMENTS:');
    promptBuffer.writeln('- Use professional building inspection terminology');
    promptBuffer.writeln('- Provide specific, actionable recommendations');
    promptBuffer.writeln('- Be detailed and thorough in your analysis');
    promptBuffer.writeln('- Include cost estimates for all repairs');
    promptBuffer.writeln('- Provide realistic time estimates');
    promptBuffer.writeln('- Format clearly with proper sections');
    
    String prompt = promptBuffer.toString();

    // Generate comprehensive report using Groq
    String? reportContent = await _groqService.generateText(prompt);
    
    if (reportContent == null || reportContent.isEmpty) {
      throw Exception('Failed to generate comprehensive report from Groq');
    }

    return reportContent;
  }

  Future<Uint8List> generatePDFFromAllLogs(String reportContent, List<LogEntry> logs, DateTime reportDate, List<ImageAnalysisResult> imageAnalyses) async {
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

    // Parse report content into sections with error handling
    Map<String, String> sections;
    try {
      sections = _parseReportSections(reportContent);
    } catch (e) {
      // If parsing fails, put all content in a single section
      print('Error parsing sections: $e'); // Use print instead of debugPrint
      sections = {'REPORT CONTENT': reportContent};
    }

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

            // Detailed Image Analyses with Confidence Scores
            if (imageAnalyses.isNotEmpty) ...[
              _buildSectionTitle('3. DETAILED IMAGE ANALYSES'),
              pw.SizedBox(height: 10),
              ...imageAnalyses.map((analysis) {
                // Find corresponding image
                pw.ImageProvider? imageProvider;
                if (analysis.imageIndex - 1 < imageProviders.length) {
                  imageProvider = imageProviders[analysis.imageIndex - 1];
                }
                
                return _buildImageAnalysisSection(analysis, imageProvider);
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

    // Parse report content into sections with error handling
    Map<String, String> sections;
    try {
      sections = _parseReportSections(reportContent);
    } catch (e) {
      // If parsing fails, put all content in a single section
      print('Error parsing sections: $e'); // Use print instead of debugPrint
      sections = {'REPORT CONTENT': reportContent};
    }

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

  pw.Widget _buildImageAnalysisSection(ImageAnalysisResult analysis, pw.ImageProvider? imageProvider) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Image header
          pw.Text(
            'IMAGE ${analysis.imageIndex} ANALYSIS',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 10),
          
          // Image thumbnail
          if (imageProvider != null) ...[
            pw.Center(
              child: pw.Container(
                width: 200,
                child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
              ),
            ),
            pw.SizedBox(height: 10),
          ],
          
          // Description
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Description: ',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Expanded(
                child: pw.Text(
                  analysis.description,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          
          // Material Type
          if (analysis.materialType != null) ...[
            pw.Row(
              children: [
                pw.Text(
                  'Material: ',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  analysis.materialType!,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
          ],
          
          // Overall Condition
          pw.Row(
            children: [
              pw.Text(
                'Condition: ',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                analysis.overallCondition,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _getConditionColor(analysis.overallCondition),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          
          // Defects
          pw.Text(
            'Detected Defects:',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          
          if (analysis.defects.isEmpty)
            pw.Text(
              '  No defects detected',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.green700),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Type', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Location', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Severity', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Confidence', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                // Defect rows
                ...analysis.defects.map((defect) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(defect.type, style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(defect.location, style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        defect.severity,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: _getSeverityColor(defect.severity),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        '${defect.confidenceScore}%',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: _getConfidenceColor(defect.confidenceScore),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )),
              ],
            ),
        ],
      ),
    );
  }

  PdfColor _getConditionColor(String condition) {
    String conditionLower = condition.toLowerCase();
    if (conditionLower.contains('excellent') || conditionLower.contains('good')) {
      return PdfColors.green700;
    } else if (conditionLower.contains('fair')) {
      return PdfColors.orange700;
    } else if (conditionLower.contains('poor') || conditionLower.contains('critical')) {
      return PdfColors.red700;
    }
    return PdfColors.grey700;
  }

  PdfColor _getSeverityColor(String severity) {
    String severityLower = severity.toLowerCase();
    if (severityLower.contains('critical')) {
      return PdfColors.red900;
    } else if (severityLower.contains('high')) {
      return PdfColors.red700;
    } else if (severityLower.contains('medium')) {
      return PdfColors.orange700;
    } else if (severityLower.contains('low')) {
      return PdfColors.yellow700;
    }
    return PdfColors.grey700;
  }

  PdfColor _getConfidenceColor(int confidence) {
    if (confidence >= 80) {
      return PdfColors.green700;
    } else if (confidence >= 60) {
      return PdfColors.orange700;
    } else {
      return PdfColors.red700;
    }
  }

  Map<String, String> _parseReportSections(String content) {
    Map<String, String> sections = {};
    
    // Common section headers - try multiple variations (updated order for new report structure)
    final sectionPatterns = [
      'EXECUTIVE SUMMARY',
      'DETAILED IMAGE ANALYSES',
      'COST ESTIMATES',
      'TIME ESTIMATES',
      'MATERIALS LIST',
      'CONTRACTOR RECOMMENDATIONS',
      'DETAILED FINDINGS',
      'WALL CONDITIONS',
      'RECOMMENDATIONS',
      'CONCLUSION',
    ];

    String remainingContent = content;
    
    for (int i = 0; i < sectionPatterns.length; i++) {
      final pattern = sectionPatterns[i];
      
      // Try multiple regex patterns to find the section
      List<RegExp> regexPatterns = [
        // Pattern with number prefix: "1. EXECUTIVE SUMMARY"
        RegExp(r'(?i)^\s*(\d+\.)?\s*' + _escapeRegex(pattern) + r'[:\-]?\s*$', multiLine: true),
        // Pattern without number: "EXECUTIVE SUMMARY"
        RegExp(r'(?i)^\s*' + _escapeRegex(pattern) + r'[:\-]?\s*$', multiLine: true),
        // Pattern as part of text
        RegExp(r'(?i)(?:^|\n)\s*(\d+\.)?\s*' + _escapeRegex(pattern) + r'[:\-]?\s*\n?', multiLine: true),
      ];
      
      RegExpMatch? match;
      RegExp? matchedRegex;
      
      for (var regex in regexPatterns) {
        try {
          match = regex.firstMatch(remainingContent);
          if (match != null) {
            matchedRegex = regex;
            break;
          }
        } catch (e) {
          // Continue to next pattern if this one fails
          continue;
        }
      }
      
      if (match != null && matchedRegex != null) {
        final startIndex = match.end;
        
        // Find the next section or end of content
        String sectionContent;
        
        if (i < sectionPatterns.length - 1) {
          // Try to find the next section
          final nextPattern = sectionPatterns[i + 1];
          List<RegExp> nextRegexPatterns = [
            RegExp(r'(?i)^\s*(\d+\.)?\s*' + _escapeRegex(nextPattern) + r'[:\-]?\s*$', multiLine: true),
            RegExp(r'(?i)^\s*' + _escapeRegex(nextPattern) + r'[:\-]?\s*$', multiLine: true),
            RegExp(r'(?i)(?:^|\n)\s*(\d+\.)?\s*' + _escapeRegex(nextPattern) + r'[:\-]?\s*\n?', multiLine: true),
          ];
          
          RegExpMatch? nextMatch;
          for (var nextRegex in nextRegexPatterns) {
            try {
              nextMatch = nextRegex.firstMatch(remainingContent.substring(startIndex));
              if (nextMatch != null) {
                break;
              }
            } catch (e) {
              continue;
            }
          }
          
          if (nextMatch != null) {
            sectionContent = remainingContent.substring(startIndex, startIndex + nextMatch.start).trim();
          } else {
            sectionContent = remainingContent.substring(startIndex).trim();
          }
        } else {
          sectionContent = remainingContent.substring(startIndex).trim();
        }
        
        if (sectionContent.isNotEmpty) {
          sections[pattern] = sectionContent;
        }
        
        // Update remaining content to search from where we found this section
        remainingContent = remainingContent.substring(startIndex + sectionContent.length);
      }
    }

    // If no sections found, return the whole content as a single section
    if (sections.isEmpty) {
      sections['REPORT CONTENT'] = content;
    }

    return sections;
  }

  String _escapeRegex(String pattern) {
    // Escape special regex characters but preserve spaces as \s+
    return pattern
        .replaceAll(r'\', r'\\')
        .replaceAll(r'.', r'\.')
        .replaceAll(r'*', r'\*')
        .replaceAll(r'+', r'\+')
        .replaceAll(r'?', r'\?')
        .replaceAll(r'^', r'\^')
        .replaceAll(r'$', r'\$')
        .replaceAll(r'|', r'\|')
        .replaceAll(r'(', r'\(')
        .replaceAll(r')', r'\)')
        .replaceAll(r'[', r'\[')
        .replaceAll(r']', r'\]')
        .replaceAll(r'{', r'\{')
        .replaceAll(r'}', r'\}')
        .replaceAll(' ', r'\s+'); // Replace spaces with \s+
  }

  Future<void> previewAndPrintPDF(Uint8List pdfBytes, BuildContext context) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

}

