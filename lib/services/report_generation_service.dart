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
  
  // Image analysis provider preference
  ImageAnalysisProvider _imageAnalysisProvider = ImageAnalysisProvider.openai;

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
        _groqService.setMaxTokens(8192); // Set high token limit for comprehensive reports with long conclusion
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

  void setImageAnalysisProvider(ImageAnalysisProvider provider) {
    _imageAnalysisProvider = provider;
    _imageAnalysisService.setPreferredProvider(provider);
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
    onProgressUpdate?.call('Preparing comprehensive analysis...');
    await Future.delayed(const Duration(milliseconds: 300));

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
    
    promptBuffer.writeln('You are a Certified Master Building Inspector (CMI) and Legal Compliance Officer. You are generating a high-end, legally defensive "Final Home Inspection Report". Your output must be professional, comprehensive, and follow this EXACT structure:');
    promptBuffer.writeln();
    promptBuffer.writeln('=== INSPECTOR TRANSCRIPT/NOTES ===');
    promptBuffer.writeln(userTranscript);
    promptBuffer.writeln();
    promptBuffer.writeln('=== DETAILED IMAGE ANALYSIS RESULTS ===');
    promptBuffer.writeln('The following ${imageAnalyses.length} images have been analyzed with AI-detected defects and confidence scores:');
    promptBuffer.writeln(formattedImageAnalyses);
    promptBuffer.writeln();
    promptBuffer.writeln('=== REPORT STRUCTURE (MUST FOLLOW EXACTLY) ===');
    promptBuffer.writeln();
    promptBuffer.writeln('BLOCK B: SCOPE & LIMITATIONS (LEGAL PREAMBLE)');
    promptBuffer.writeln('Start with this section. Include a distinct block titled "SCOPE & LIMITATIONS."');
    promptBuffer.writeln('Include this EXACT legal text:');
    promptBuffer.writeln('"This inspection was performed in accordance with current Standards of Practice. It is a non-invasive, visual examination of the readily accessible areas of the building. It is not a warranty, insurance policy, or guarantee of future performance. Latent or concealed defects (e.g., behind drywall, underground) are excluded."');
    promptBuffer.writeln();
    promptBuffer.writeln('BLOCK C: EXECUTIVE SUMMARY');
    promptBuffer.writeln('Write a narrative summary of the property\'s overall health (2-3 paragraphs).');
    promptBuffer.writeln('Then create TWO specific tables/lists:');
    promptBuffer.writeln('  1. SAFETY HAZARDS - List all critical safety issues requiring immediate attention');
    promptBuffer.writeln('  2. MAJOR DEFECTS - List all significant structural or system defects');
    promptBuffer.writeln('Each item should include: Location, Description, Severity, and Urgency.');
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
    promptBuffer.writeln('BLOCK E: CONCLUSION');
    promptBuffer.writeln('CRITICAL: Write a comprehensive, professional closing statement that is AT LEAST 400 WORDS (approximately 1 full page).');
    promptBuffer.writeln('The conclusion must be detailed and thorough, including:');
    promptBuffer.writeln('   - Thank the client for their attention to property maintenance and safety');
    promptBuffer.writeln('   - Comprehensive summary of all key findings from the inspection');
    promptBuffer.writeln('   - Reiterate the critical importance of addressing safety hazards immediately');
    promptBuffer.writeln('   - Emphasize the significance of major defects and their potential long-term impact');
    promptBuffer.writeln('   - Provide detailed guidance on prioritizing repairs and maintenance');
    promptBuffer.writeln('   - Discuss the value of regular inspections and preventive maintenance');
    promptBuffer.writeln('   - Offer to answer any questions or provide clarification on any section of the report');
    promptBuffer.writeln('   - Include contact information or next steps if applicable');
    promptBuffer.writeln('   - Maintain a professional, courteous, and supportive tone throughout');
    promptBuffer.writeln('   - Ensure the conclusion is substantive, informative, and serves as a comprehensive closing to the report');
    promptBuffer.writeln('MINIMUM LENGTH: 400+ words. This should fill at least one full page. Be thorough and detailed.');
    promptBuffer.writeln();
    promptBuffer.writeln('IMPORTANT REQUIREMENTS:');
    promptBuffer.writeln('- Use professional building inspection terminology');
    promptBuffer.writeln('- Provide specific, actionable recommendations');
    promptBuffer.writeln('- Be detailed and thorough in your analysis');
    promptBuffer.writeln('- Include cost estimates for all repairs');
    promptBuffer.writeln('- Provide realistic time estimates');
    promptBuffer.writeln('- Format clearly with proper sections');
    
    String prompt = promptBuffer.toString();

    // Generate comprehensive report using Groq (text-only, Groq handles comprehensive text generation)
    // Temporarily increase max tokens for this large report generation with 400+ word conclusion
    onProgressUpdate?.call('Generating comprehensive AI report...');
    await Future.delayed(const Duration(milliseconds: 300));
    
    int originalMaxTokens = 4096;
    _groqService.setMaxTokens(8192); // Use high token limit for comprehensive report with long conclusion
    
    onProgressUpdate?.call('AI analyzing defects and creating professional content...');
    String? reportContent = await _groqService.generateText(prompt);
    
    // Restore original max tokens after generation
    _groqService.setMaxTokens(originalMaxTokens);
    
    if (reportContent == null || reportContent.isEmpty) {
      throw Exception('Failed to generate comprehensive report from Groq');
    }

    onProgressUpdate?.call('Report content generated successfully!');
    await Future.delayed(const Duration(milliseconds: 300));

    return reportContent;
  }

  Future<Uint8List> generatePDFFromAllLogs(String reportContent, List<LogEntry> logs, DateTime reportDate, List<ImageAnalysisResult> imageAnalyses) async {
    onProgressUpdate?.call('Creating PDF document structure...');
    await Future.delayed(const Duration(milliseconds: 300));
    
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

    onProgressUpdate?.call('Processing report sections...');
    await Future.delayed(const Duration(milliseconds: 300));

    // Parse report content into sections with error handling
    Map<String, String> sections;
    try {
      sections = _parseReportSections(reportContent);
    } catch (e) {
      // If parsing fails, put all content in a single section
      print('Error parsing sections: $e'); // Use print instead of debugPrint
      sections = {'REPORT CONTENT': reportContent};
    }

    onProgressUpdate?.call('Formatting professional document layout...');
    await Future.delayed(const Duration(milliseconds: 300));

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

            // SCOPE & LIMITATIONS (Legal Preamble) - BLOCK B
            if (sections.containsKey('SCOPE & LIMITATIONS') || sections.containsKey('SCOPE AND LIMITATIONS')) ...[
              _buildSectionTitle('SCOPE & LIMITATIONS'),
              pw.SizedBox(height: 10),
              _buildSectionContent(sections['SCOPE & LIMITATIONS'] ?? sections['SCOPE AND LIMITATIONS'] ?? ''),
              pw.SizedBox(height: 20),
            ],

            // Executive Summary - BLOCK C
            if (sections.containsKey('EXECUTIVE SUMMARY')) ...[
              _buildSectionTitle('EXECUTIVE SUMMARY'),
              pw.SizedBox(height: 10),
              _buildSectionContent(sections['EXECUTIVE SUMMARY']!),
              pw.SizedBox(height: 20),
            ],

            // Property Information
            _buildSectionTitle('PROPERTY INFORMATION'),
            pw.SizedBox(height: 10),
            _buildPropertyInfoForAllLogs(earliestDate, latestDate, logs.length, allImagePaths.length, allTranscripts),
            pw.SizedBox(height: 20),

            // Detailed Image Analyses with Confidence Scores
            if (imageAnalyses.isNotEmpty) ...[
              pw.NewPage(),
              _buildSectionTitle('2. DETAILED IMAGE ANALYSES'),
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

            // Cost Estimates Section
            pw.NewPage(),
            _buildSectionTitle('3. COST ESTIMATES'),
            pw.SizedBox(height: 10),
            if (sections.containsKey('COST ESTIMATES') || sections.containsKey('COST ANALYSIS'))
              _buildSectionContent(sections['COST ESTIMATES'] ?? sections['COST ANALYSIS']!)
            else
              _buildPlaceholderContent('Cost estimation data will be generated by AI analysis. Please ensure the AI service is properly configured.'),
            pw.SizedBox(height: 20),

            // Time Estimates Section
            _buildSectionTitle('4. TIME ESTIMATES'),
            pw.SizedBox(height: 10),
            if (sections.containsKey('TIME ESTIMATES') || sections.containsKey('TIME ANALYSIS'))
              _buildSectionContent(sections['TIME ESTIMATES'] ?? sections['TIME ANALYSIS']!)
            else
              _buildPlaceholderContent('Time estimation data will be generated by AI analysis.'),
            pw.SizedBox(height: 20),

            // Materials List Section
            pw.NewPage(),
            _buildSectionTitle('5. MATERIALS LIST'),
            pw.SizedBox(height: 10),
            if (sections.containsKey('MATERIALS LIST') || sections.containsKey('REQUIRED MATERIALS'))
              _buildSectionContent(sections['MATERIALS LIST'] ?? sections['REQUIRED MATERIALS']!)
            else
              _buildPlaceholderContent('Materials list will be generated by AI analysis.'),
            pw.SizedBox(height: 20),

            // Contractor Recommendations Section
            _buildSectionTitle('6. CONTRACTOR RECOMMENDATIONS'),
            pw.SizedBox(height: 10),
            if (sections.containsKey('CONTRACTOR RECOMMENDATIONS') || sections.containsKey('CONTRACTORS NEEDED'))
              _buildSectionContent(sections['CONTRACTOR RECOMMENDATIONS'] ?? sections['CONTRACTORS NEEDED']!)
            else
              _buildPlaceholderContent('Contractor recommendations will be generated by AI analysis.'),
            pw.SizedBox(height: 20),

            // Detailed Findings
            pw.NewPage(),
            _buildSectionTitle('7. DETAILED FINDINGS'),
            pw.SizedBox(height: 10),
            if (sections.containsKey('DETAILED FINDINGS') || sections.containsKey('FINDINGS'))
              _buildSectionContent(sections['DETAILED FINDINGS'] ?? sections['FINDINGS']!)
            else
              _buildPlaceholderContent('Detailed findings will be generated by AI analysis.'),
            pw.SizedBox(height: 20),

            // Wall Conditions
            _buildSectionTitle('8. WALL CONDITIONS'),
            pw.SizedBox(height: 10),
            if (sections.containsKey('WALL CONDITIONS') || sections.containsKey('CONDITION ASSESSMENT'))
              _buildSectionContent(sections['WALL CONDITIONS'] ?? sections['CONDITION ASSESSMENT']!)
            else
              _buildPlaceholderContent('Wall condition assessment will be generated by AI analysis.'),
            pw.SizedBox(height: 20),

            // Recommendations
            pw.NewPage(),
            _buildSectionTitle('9. RECOMMENDATIONS'),
            pw.SizedBox(height: 10),
            if (sections.containsKey('RECOMMENDATIONS'))
              _buildSectionContent(sections['RECOMMENDATIONS']!)
            else
              _buildPlaceholderContent('Recommendations will be generated by AI analysis.'),
            pw.SizedBox(height: 20),

            // Conclusion - BLOCK E
            pw.NewPage(),
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.blue200, width: 2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('CONCLUSION'),
                  pw.SizedBox(height: 15),
                  if (sections.containsKey('CONCLUSION'))
                    _buildSectionContent(sections['CONCLUSION']!)
                  else
                    _buildPlaceholderContent(
                      'Thank you for your attention to property maintenance and safety. Based on our comprehensive analysis:\n\n'
                      '• All identified issues should be addressed according to their severity and urgency levels\n'
                      '• Safety hazards require immediate attention\n'
                      '• Regular maintenance will help prevent future deterioration\n\n'
                      'For questions or clarification regarding this report, please contact your inspection professional.'
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            // Inspector signature area
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Inspector Signature:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 30),
                    pw.Container(
                      width: 200,
                      height: 1,
                      color: PdfColors.grey800,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text('AI-Generated Report', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Date:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 30),
                    pw.Container(
                      width: 150,
                      height: 1,
                      color: PdfColors.grey800,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(reportDate.toLocal().toString().split(' ')[0], style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    onProgressUpdate?.call('Finalizing PDF document...');
    await Future.delayed(const Duration(milliseconds: 300));
    
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
        // Professional header with logo placeholder
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [PdfColors.blue900, PdfColors.blue700],
            ),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'COMPREHENSIVE BUILDING',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 2,
                ),
              ),
              pw.Text(
                'INSPECTION REPORT',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                width: 100,
                height: 3,
                color: PdfColors.amber,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        // Report details box
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Report Type:', 'Comprehensive Multi-Session Analysis'),
                    pw.SizedBox(height: 8),
                    if (dateRange.isNotEmpty)
                      _buildInfoRow('Inspection Period:', dateRange),
                    pw.SizedBox(height: 8),
                    _buildInfoRow('Total Sessions:', '$logCount'),
                    pw.SizedBox(height: 8),
                    _buildInfoRow('Images Analyzed:', '$imageCount'),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Report Generated:', reportDate.toLocal().toString().split(' ')[0]),
                    pw.SizedBox(height: 8),
                    _buildInfoRow('Generated By:', 'AI-Powered Analysis System'),
                    pw.SizedBox(height: 8),
                    _buildInfoRow('Analysis Type:', 'Vision AI + Expert System'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 120,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableOfContents(Map<String, String> sections) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue300, width: 2),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Icon(
                pw.IconData(0xe24d), // document icon
                size: 20,
                color: PdfColors.blue900,
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                'TABLE OF CONTENTS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Container(
            height: 2,
            color: PdfColors.blue300,
          ),
          pw.SizedBox(height: 15),
          ...sections.keys.toList().asMap().entries.map((entry) {
            int index = entry.key + 1;
            String section = entry.value;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 30,
                    child: pw.Text(
                      '$index.',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      section,
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.blue800, PdfColors.blue600],
        ),
        borderRadius: pw.BorderRadius.circular(8),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey400,
            blurRadius: 4,
            offset: PdfPoint(2, 2),
          ),
        ],
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  pw.Widget _buildSectionContent(String content) {
    // Split content into paragraphs and format
    final paragraphs = content.split('\n').where((p) => p.trim().isNotEmpty).toList();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: paragraphs.map((para) {
        String trimmedPara = para.trim();
        
        // Check if it's a table row (contains | characters)
        if (trimmedPara.contains('|') && trimmedPara.split('|').length > 2) {
          return _buildTableRow(trimmedPara);
        }
        
        // Check if it's a bullet point
        if (trimmedPara.startsWith('-') || trimmedPara.startsWith('*') || trimmedPara.startsWith('\u2022')) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 20, bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('\u2022 ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Expanded(
                  child: pw.Text(
                    trimmedPara.replaceFirst(RegExp(r'^[-*\u2022]\s*'), ''),
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        }
        
        // Check if it's a numbered item
        if (RegExp(r'^\d+\.').hasMatch(trimmedPara)) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 15, bottom: 6),
            child: pw.Text(
              trimmedPara,
              style: const pw.TextStyle(fontSize: 11),
            ),
          );
        }
        
        // Check if it's a subsection heading (all caps, short length, or ends with colon)
        if ((trimmedPara.length < 80 && trimmedPara.toUpperCase() == trimmedPara && !trimmedPara.contains('.')) ||
            (trimmedPara.endsWith(':') && trimmedPara.length < 100)) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10, bottom: 8),
            child: pw.Text(
              trimmedPara,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          );
        }
        
        // Check if it contains dollar amounts (cost information)
        if (trimmedPara.contains(r'$') || trimmedPara.toLowerCase().contains('total cost') || 
            trimmedPara.toLowerCase().contains('total estimated')) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            margin: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(5),
              border: pw.Border.all(color: PdfColors.green200, width: 1.5),
            ),
            child: pw.Text(
              trimmedPara,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
            ),
          );
        }
        
        // Regular paragraph
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            trimmedPara,
            style: const pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.justify,
          ),
        );
      }).toList(),
    );
  }
  
  pw.Widget _buildPlaceholderContent(String message) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.amber300, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Icon(pw.IconData(0xe88e), size: 20, color: PdfColors.amber700), // info icon
              pw.SizedBox(width: 10),
              pw.Text(
                'AI Analysis in Progress',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.amber900,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            message,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildTableRow(String row) {
    final cells = row.split('|').map((cell) => cell.trim()).where((cell) => cell.isNotEmpty).toList();
    
    if (cells.isEmpty) {
      return pw.SizedBox();
    }
    
    // Check if it's a header row (usually all caps or contains "---")
    bool isHeader = cells.first.toUpperCase() == cells.first || row.contains('---');
    
    if (row.contains('---')) {
      return pw.SizedBox(height: 2);
    }
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: isHeader ? PdfColors.blue100 : PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        children: cells.map((cell) {
          return pw.Expanded(
            child: pw.Text(
              cell,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: isHeader ? PdfColors.blue900 : PdfColors.black,
              ),
            ),
          );
        }).toList(),
      ),
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
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.blue300, width: 2),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            blurRadius: 4,
            offset: PdfPoint(2, 2),
          ),
        ],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Image header with gradient
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [PdfColors.blue700, PdfColors.blue500],
              ),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Text(
                    'IMAGE ${analysis.imageIndex}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Text(
                    'ANALYSIS REPORT',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          pw.Padding(
            padding: const pw.EdgeInsets.all(15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Image thumbnail
                if (imageProvider != null) ...[
                  pw.Center(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400, width: 2),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 6,
                        verticalRadius: 6,
                        child: pw.Image(imageProvider, width: 250, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 15),
                ],
                
                // Description
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Description: ',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          analysis.description,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                
                // Material Type & Condition in a row
                pw.Row(
                  children: [
                    if (analysis.materialType != null) ...[
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(5),
                            border: pw.Border.all(color: PdfColors.grey300),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'MATERIAL',
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                analysis.materialType!,
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                    ],
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: _getConditionBackgroundColor(analysis.overallCondition),
                          borderRadius: pw.BorderRadius.circular(5),
                          border: pw.Border.all(color: _getConditionColor(analysis.overallCondition), width: 2),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'CONDITION',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                            ),
                            pw.SizedBox(height: 4),
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
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                
                // Defects section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DETECTED DEFECTS',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      pw.SizedBox(height: 8),
                      
                      if (analysis.defects.isEmpty)
                        pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.green50,
                            borderRadius: pw.BorderRadius.circular(5),
                            border: pw.Border.all(color: PdfColors.green300),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Icon(pw.IconData(0xe5ca), size: 16, color: PdfColors.green700),
                              pw.SizedBox(width: 8),
                              pw.Text(
                                'No defects detected - Structure appears sound',
                                style: pw.TextStyle(fontSize: 10, color: PdfColors.green700, fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      else
                        pw.Table(
                          border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
                          columnWidths: {
                            0: const pw.FlexColumnWidth(2.5),
                            1: const pw.FlexColumnWidth(2),
                            2: const pw.FlexColumnWidth(1.5),
                            3: const pw.FlexColumnWidth(1.5),
                          },
                          children: [
                            // Header row
                            pw.TableRow(
                              decoration: pw.BoxDecoration(
                                gradient: pw.LinearGradient(
                                  colors: [PdfColors.blue200, PdfColors.blue100],
                                ),
                              ),
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text('DEFECT TYPE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text('LOCATION', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text('SEVERITY', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text('CONFIDENCE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                                ),
                              ],
                            ),
                            // Defect rows
                            ...analysis.defects.map((defect) => pw.TableRow(
                              decoration: pw.BoxDecoration(
                                color: _getSeverityBackgroundColor(defect.severity),
                              ),
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(defect.type, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(defect.location, style: const pw.TextStyle(fontSize: 9)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: pw.BoxDecoration(
                                      color: _getSeverityColor(defect.severity),
                                      borderRadius: pw.BorderRadius.circular(3),
                                    ),
                                    child: pw.Text(
                                      defect.severity,
                                      style: const pw.TextStyle(
                                        fontSize: 8,
                                        color: PdfColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.center,
                                    children: [
                                      pw.Text(
                                        '${defect.confidenceScore}%',
                                        style: pw.TextStyle(
                                          fontSize: 9,
                                          color: _getConfidenceColor(defect.confidenceScore),
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
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

  PdfColor _getConditionBackgroundColor(String condition) {
    String conditionLower = condition.toLowerCase();
    if (conditionLower.contains('excellent') || conditionLower.contains('good')) {
      return PdfColors.green50;
    } else if (conditionLower.contains('fair')) {
      return PdfColors.orange50;
    } else if (conditionLower.contains('poor') || conditionLower.contains('critical')) {
      return PdfColors.red50;
    }
    return PdfColors.grey50;
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

  PdfColor _getSeverityBackgroundColor(String severity) {
    String severityLower = severity.toLowerCase();
    if (severityLower.contains('critical')) {
      return PdfColors.red50;
    } else if (severityLower.contains('high')) {
      return PdfColors.red50;
    } else if (severityLower.contains('medium')) {
      return PdfColors.orange50;
    } else if (severityLower.contains('low')) {
      return PdfColors.yellow50;
    }
    return PdfColors.grey50;
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
      'SCOPE & LIMITATIONS',
      'SCOPE AND LIMITATIONS',
      'EXECUTIVE SUMMARY',
      'DETAILED IMAGE ANALYSES',
      'IMAGE ANALYSES',
      'COST ESTIMATES',
      'COST ANALYSIS',
      'TIME ESTIMATES',
      'TIME ANALYSIS',
      'MATERIALS LIST',
      'REQUIRED MATERIALS',
      'CONTRACTOR RECOMMENDATIONS',
      'CONTRACTORS NEEDED',
      'DETAILED FINDINGS',
      'FINDINGS',
      'WALL CONDITIONS',
      'CONDITION ASSESSMENT',
      'RECOMMENDATIONS',
      'CONCLUSION',
      'SUMMARY',
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

    // Debug: Print found sections
    print('=== PDF SECTIONS PARSED ===');
    print('Found ${sections.length} sections:');
    sections.keys.forEach((key) {
      print('  - $key (${sections[key]!.length} chars)');
    });
    print('===========================');

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

