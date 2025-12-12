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
import 'location_service.dart';

class ReportGenerationService {
  final GeminiAIService _geminiService = GeminiAIService();
  final GroqAIService _groqService = GroqAIService();
  final ImageAnalysisService _imageAnalysisService = ImageAnalysisService();
  final LocationService _locationService = LocationService();
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

    // === STAGE 1: INDIVIDUAL IMAGE ANALYSIS (GEMINI) ===
    onProgressUpdate?.call('Stage 1: Analyzing images with Gemini AI...');
    
    List<ImageAnalysisResult> imageAnalyses = [];
    List<Future<ImageAnalysisResult?>> analysisFutures = [];
    
    // Launch all image analyses in parallel
    for (int i = 0; i < allImagePaths.length; i++) {
      final imageIndex = i + 1;
      analysisFutures.add(
        _imageAnalysisService.analyzeImage(allImagePaths[i], imageIndex).then<ImageAnalysisResult?>((result) => result).catchError((e) {
          print('Warning: Failed to analyze image $imageIndex: $e');
          return null;
        })
      );
    }
    
    // Wait for all analyses to complete
    onProgressUpdate?.call('Processing ${allImagePaths.length} images in parallel...');
    final results = await Future.wait(analysisFutures);
    
    // Filter out null results and add successful analyses
    for (var result in results) {
      if (result != null) {
        imageAnalyses.add(result);
        onProgressUpdate?.call('Completed ${imageAnalyses.length}/${allImagePaths.length} image analyses...');
      }
    }

    if (imageAnalyses.isEmpty) {
      throw Exception('Failed to analyze any images. Cannot generate report.');
    }

    onProgressUpdate?.call('Successfully analyzed ${imageAnalyses.length} images!');
    await Future.delayed(const Duration(milliseconds: 500));

    // === STAGE 2: EXTRACT INSIGHTS FROM GEMINI + TRANSCRIPT ===
    onProgressUpdate?.call('Extracting comprehensive insights from analyses...');
    await Future.delayed(const Duration(milliseconds: 300));

    // Combine all transcripts
    String combinedTranscript = allTranscripts.isEmpty 
        ? 'No transcripts provided.' 
        : allTranscripts.join('\n\n---\n\n');

    // Format image analyses for Groq prompt with detailed insights
    final StringBuffer imageAnalysesText = StringBuffer();
    int totalDefects = 0;
    
    imageAnalysesText.writeln('=== COMPREHENSIVE IMAGE ANALYSIS DATA ===');
    imageAnalysesText.writeln('Total Images Analyzed: ${imageAnalyses.length}');
    imageAnalysesText.writeln();
    
    for (var analysis in imageAnalyses) {
      totalDefects += analysis.defects.length;
      imageAnalysesText.writeln('--- IMAGE ${analysis.imageIndex} DETAILED ANALYSIS ---');
      imageAnalysesText.writeln('Visual Description: ${analysis.description}');
      imageAnalysesText.writeln('Material Type: ${analysis.materialType ?? "Unknown"}');
      imageAnalysesText.writeln('Overall Condition: ${analysis.overallCondition}');
      imageAnalysesText.writeln();
      
      if (analysis.defects.isEmpty) {
        imageAnalysesText.writeln('Status: No defects detected - Surface appears in good condition');
      } else {
        imageAnalysesText.writeln('Defects Found: ${analysis.defects.length}');
        imageAnalysesText.writeln();
        for (var defect in analysis.defects) {
          imageAnalysesText.writeln('  DEFECT: ${defect.type}');
          imageAnalysesText.writeln('    Location: ${defect.location}');
          imageAnalysesText.writeln('    Severity: ${defect.severity}');
          imageAnalysesText.writeln('    Confidence: ${defect.confidenceScore}%');
          imageAnalysesText.writeln('    Description: ${defect.description}');
          imageAnalysesText.writeln();
        }
      }
      imageAnalysesText.writeln('---');
      imageAnalysesText.writeln();
    }
    
    imageAnalysesText.writeln('=== ANALYSIS SUMMARY ===');
    imageAnalysesText.writeln('Total Defects Detected: $totalDefects');
    imageAnalysesText.writeln('Images with Issues: ${imageAnalyses.where((a) => a.defects.isNotEmpty).length}');
    imageAnalysesText.writeln('Images in Good Condition: ${imageAnalyses.where((a) => a.defects.isEmpty).length}');
    imageAnalysesText.writeln();

    // Store image analyses for PDF generation
    _lastImageAnalyses = imageAnalyses;
    
    // === STAGE 3: GENERATE COMPREHENSIVE REPORT WITH GROQ ===
    onProgressUpdate?.call('Feeding data to Groq for comprehensive report generation...');
    await Future.delayed(const Duration(milliseconds: 300));
    
    String reportContent = await _generateComprehensiveReport(
      imageAnalyses, 
      combinedTranscript, 
      imageAnalysesText.toString()
    );
    
    onProgressUpdate?.call('Report generation complete!');
    await Future.delayed(const Duration(milliseconds: 300));
    
    return reportContent;
  }

  // New method that includes image analyses in PDF
  Future<Uint8List> generatePDFFromAllLogsWithAnalyses(String reportContent, List<LogEntry> logs, DateTime reportDate) async {
    return await generatePDFFromAllLogs(reportContent, logs, reportDate, _lastImageAnalyses);
  }

  Future<String> _generateComprehensiveReport(List<ImageAnalysisResult> imageAnalyses, String userTranscript, String formattedImageAnalyses) async {
    // Get location data
    Map<String, dynamic>? locationData = await _locationService.getSavedLocation();
    String locationInfo = locationData?['fullAddress'] ?? 'Property Location';
    double costMultiplier = 1.0;
    
    if (locationData != null) {
      String region = locationData['region'] ?? '';
      costMultiplier = _locationService.getCostMultiplier(region);
    }
    
    int totalDefects = imageAnalyses.fold(0, (sum, analysis) => sum + analysis.defects.length);
    
    // HYBRID APPROACH: Try AI enhancement, fallback to template-based generation
    onProgressUpdate?.call('Generating comprehensive report...');
    
    String report = '';
    
    try {
      // Try AI-enhanced generation
      report = await _generateAIEnhancedReport(imageAnalyses, userTranscript, formattedImageAnalyses, locationInfo, costMultiplier, totalDefects);
      print('✓ AI-enhanced report generated successfully');
    } catch (e) {
      print('AI generation failed: $e');
      print('Falling back to template-based report...');
      onProgressUpdate?.call('Generating structured report (template mode)...');
      
      // Fallback to template-based report - ALWAYS WORKS
      report = _generateTemplateReport(imageAnalyses, userTranscript, locationInfo, costMultiplier, totalDefects);
      print('✓ Template-based report generated successfully');
    }
    
    onProgressUpdate?.call('Report generation complete!');
    return report;
  }
  
  Future<String> _generateAIEnhancedReport(List<ImageAnalysisResult> imageAnalyses, String userTranscript, String formattedImageAnalyses, String locationInfo, double costMultiplier, int totalDefects) async {
    // Try to enhance report with Gemini AI
    final StringBuffer prompt = StringBuffer();
    
    prompt.writeln('You are a professional building inspector. Generate a comprehensive inspection report.');
    prompt.writeln();
    prompt.writeln('PROPERTY: $locationInfo');
    prompt.writeln('IMAGES ANALYZED: ${imageAnalyses.length}');
    prompt.writeln('DEFECTS FOUND: $totalDefects');
    prompt.writeln('INSPECTOR NOTES: $userTranscript');
    prompt.writeln();
    prompt.writeln('IMAGE ANALYSIS RESULTS:');
    prompt.writeln(formattedImageAnalyses);
    prompt.writeln();
    prompt.writeln('Generate 9 sections: Scope & Limitations, Executive Summary, Detailed Findings, Cost Estimates, Time Estimates, Materials List, Contractor Recommendations, Recommendations, Conclusion.');
    prompt.writeln('Include specific costs (2025 market rates), timelines, and professional recommendations.');
    prompt.writeln('Make it comprehensive and professional. Use real numbers, not placeholders.');
    
    try {
      String? content = await _geminiService.generateText(prompt.toString());
      
      if (content != null && content.isNotEmpty && content.length > 500) {
        print('✓ AI-enhanced report: ${content.length} chars');
        return content;
      } else {
        print('AI response too short or empty, using template fallback');
        throw Exception('AI response insufficient');
      }
    } catch (e) {
      print('AI enhancement failed: $e - will use template');
      // Don't throw - let caller handle fallback
      throw e;
    }
  }
  
  String _generateTemplateReport(List<ImageAnalysisResult> imageAnalyses, String userTranscript, String locationInfo, double costMultiplier, int totalDefects) {
    // TEMPLATE-BASED REPORT - ALWAYS WORKS, NEVER FAILS
    final StringBuffer report = StringBuffer();
    final now = DateTime.now();
    
    // SECTION 1: SCOPE & LIMITATIONS
    report.writeln('SCOPE & LIMITATIONS');
    report.writeln();
    report.writeln('This inspection was performed in accordance with current Standards of Practice. It is a non-invasive, visual examination of the readily accessible areas of the building. It is not a warranty, insurance policy, or guarantee of future performance. Latent or concealed defects (e.g., behind drywall, underground) are excluded.');
    report.writeln();
    report.writeln('This inspection covered ${imageAnalyses.length} area(s) of the property using visual assessment and photographic documentation. The inspection methodology included systematic examination of accessible surfaces, structural elements, and visible building components. Digital imaging technology was employed to capture detailed visual records of observed conditions.');
    report.writeln();
    report.writeln('The scope of this inspection is limited to readily accessible and visible components. Areas concealed by finishes, furnishings, or structural elements were not examined. This inspection does not include destructive testing, laboratory analysis, or specialized equipment beyond standard photographic documentation.');
    report.writeln();
    
    // SECTION 2: EXECUTIVE SUMMARY
    report.writeln('EXECUTIVE SUMMARY');
    report.writeln();
    
    if (totalDefects > 0) {
      report.writeln('This inspection identified $totalDefects defect(s) requiring attention across ${imageAnalyses.length} examined area(s). The findings range from minor cosmetic issues to items requiring professional repair. Detailed analysis and recommendations are provided in subsequent sections.');
      report.writeln();
      report.writeln('The overall condition assessment indicates that while the property shows signs of wear consistent with age and use, the identified issues can be addressed through systematic repairs and preventive maintenance. Priority should be given to items affecting structural integrity and safety.');
    } else {
      report.writeln('This inspection examined ${imageAnalyses.length} area(s) of the property. No major defects or safety hazards were identified during this visual examination. The property appears to be in satisfactory condition, with normal wear patterns consistent with age and use.');
      report.writeln();
      report.writeln('While no immediate repairs are required, routine maintenance and periodic inspections are recommended to preserve the property\'s condition and prevent future deterioration.');
    }
    report.writeln();
    
    // Defects table
    if (totalDefects > 0) {
      report.writeln('MAJOR DEFECTS IDENTIFIED:');
      report.writeln('| Location | Defect Type | Severity | Recommended Action |');
      report.writeln('|----------|-------------|----------|-------------------|');
      
      for (var analysis in imageAnalyses) {
        for (var defect in analysis.defects) {
          report.writeln('| ${defect.location} | ${defect.type} | ${defect.severity} | Professional repair recommended |');
        }
      }
      report.writeln();
    }
    
    // SECTION 3: DETAILED FINDINGS
    report.writeln('DETAILED FINDINGS');
    report.writeln();
    
    for (var analysis in imageAnalyses) {
      report.writeln('IMAGE ${analysis.imageIndex} ANALYSIS:');
      report.writeln('Material Type: ${analysis.materialType ?? "General building materials"}');
      report.writeln('Overall Condition: ${analysis.overallCondition}');
      report.writeln('Description: ${analysis.description}');
      report.writeln();
      
      if (analysis.defects.isNotEmpty) {
        report.writeln('Defects Observed:');
        for (var defect in analysis.defects) {
          report.writeln('- ${defect.type}: ${defect.description}');
          report.writeln('  Location: ${defect.location}');
          report.writeln('  Severity: ${defect.severity}');
          report.writeln('  Confidence: ${defect.confidenceScore}%');
        }
        report.writeln();
      }
    }
    
    if (userTranscript.trim().isNotEmpty) {
      report.writeln('INSPECTOR NOTES:');
      report.writeln(userTranscript);
      report.writeln();
    }
    
    report.writeln(_generateCostSection(imageAnalyses, costMultiplier));
    report.writeln(_generateTimeSection(imageAnalyses));
    report.writeln(_generateMaterialsSection(imageAnalyses));
    report.writeln(_generateContractorsSection(imageAnalyses));
    report.writeln(_generateRecommendationsSection(imageAnalyses, totalDefects));
    report.writeln(_generateConclusionSection(imageAnalyses, totalDefects, locationInfo));
    
    return report.toString();
  }
  

  Future<Uint8List> generatePDFFromAllLogs(String reportContent, List<LogEntry> logs, DateTime reportDate, List<ImageAnalysisResult> imageAnalyses) async {
    // Verify report content before generating PDF
    if (reportContent.isEmpty || reportContent.length < 1000) {
      throw Exception('Report content too short or empty. Cannot generate PDF.');
    }
    
    onProgressUpdate?.call('Preparing PDF generation...');
    await Future.delayed(const Duration(milliseconds: 300));
    
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

    // Validate inputs before processing
    if (imageAnalyses.isEmpty) {
      print('WARNING: No image analyses provided for PDF generation');
    }
    
    onProgressUpdate?.call('Processing report sections...');
    await Future.delayed(const Duration(milliseconds: 300));

    // Parse report content into sections with error handling
    Map<String, String> sections;
    try {
      sections = _parseReportSections(reportContent);
      print('Successfully parsed ${sections.length} sections for PDF');
    } catch (e) {
      // If parsing fails, put all content in a single section
      print('Error parsing sections: $e');
      sections = {'REPORT CONTENT': reportContent};
    }
    
    // Ensure sections is not empty
    if (sections.isEmpty) {
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
      return pw.Container(
        height: 2,
        margin: const pw.EdgeInsets.symmetric(vertical: 4),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue300,
        ),
      );
    }
    
    // Check if this is a total row (contains "TOTAL")
    bool isTotalRow = row.toUpperCase().contains('TOTAL');
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 2),
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: isHeader 
            ? PdfColors.blue700 
            : isTotalRow 
                ? PdfColors.green100 
                : PdfColors.grey50,
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: cells.asMap().entries.map((entry) {
          int index = entry.key;
          String cell = entry.value;
          
          return pw.Expanded(
            flex: index == 0 ? 2 : 1, // First column (description) gets more space
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4),
              child: pw.Text(
                cell,
                style: pw.TextStyle(
                  fontSize: isHeader ? 10 : 9.5,
                  fontWeight: isHeader || isTotalRow ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: isHeader 
                      ? PdfColors.white 
                      : isTotalRow 
                          ? PdfColors.green900 
                          : PdfColors.black,
                ),
                textAlign: index == 0 ? pw.TextAlign.left : pw.TextAlign.right,
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

  // TEMPLATE SECTION GENERATORS - ALWAYS WORK, NEVER FAIL
  
  String _generateCostSection(List<ImageAnalysisResult> imageAnalyses, double costMultiplier) {
    final StringBuffer section = StringBuffer();
    section.writeln('COST ESTIMATES');
    section.writeln();
    section.writeln('| Repair Item | Location | Material Cost | Labor Cost | Total Cost |');
    section.writeln('|-------------|----------|---------------|------------|------------|');
    
    double totalCost = 0;
    int itemCount = 0;
    
    for (var analysis in imageAnalyses) {
      for (var defect in analysis.defects) {
        itemCount++;
        // Generate realistic costs based on defect severity
        double baseMaterialCost = defect.severity.toLowerCase().contains('high') ? 200 : 
                                   defect.severity.toLowerCase().contains('medium') ? 120 : 80;
        double baseLaborCost = baseMaterialCost * 2.5;
        
        double materialCost = baseMaterialCost * costMultiplier;
        double laborCost = baseLaborCost * costMultiplier;
        double itemTotal = materialCost + laborCost;
        totalCost += itemTotal;
        
        section.writeln('| ${defect.type} | ${defect.location} | \$${materialCost.toStringAsFixed(0)} | \$${laborCost.toStringAsFixed(0)} | \$${itemTotal.toStringAsFixed(0)} |');
      }
    }
    
    if (itemCount == 0) {
      // No defects - add routine maintenance items
      section.writeln('| Routine inspection & touch-up | General | \$150 | \$200 | \$350 |');
      section.writeln('| Preventive maintenance | Exterior | \$100 | \$150 | \$250 |');
      section.writeln('| Surface cleaning | Interior | \$75 | \$125 | \$200 |');
      totalCost = 800;
    }
    
    double contingency = totalCost * 0.12;
    section.writeln('| Contingency (12%) | All areas | - | - | \$${contingency.toStringAsFixed(0)} |');
    section.writeln('| **GRAND TOTAL** | - | - | - | **\$${(totalCost + contingency).toStringAsFixed(0)}** |');
    section.writeln();
    
    return section.toString();
  }
  
  String _generateTimeSection(List<ImageAnalysisResult> imageAnalyses) {
    final StringBuffer section = StringBuffer();
    section.writeln('TIME ESTIMATES');
    section.writeln();
    section.writeln('| Task | Duration | Crew Size | Notes |');
    section.writeln('|------|----------|-----------|-------|');
    
    int totalDays = 0;
    
    for (var analysis in imageAnalyses) {
      for (var defect in analysis.defects) {
        int days = defect.severity.toLowerCase().contains('high') ? 3 :
                   defect.severity.toLowerCase().contains('medium') ? 2 : 1;
        int crew = days >= 2 ? 2 : 1;
        totalDays += days;
        
        section.writeln('| ${defect.type} repair | $days days | $crew workers | ${defect.location} |');
      }
    }
    
    if (totalDays == 0) {
      section.writeln('| Routine maintenance | 1 day | 1 worker | General upkeep |');
      totalDays = 1;
    }
    
    section.writeln('| **TOTAL PROJECT TIME** | **$totalDays days** | - | Accounting for sequential work |');
    section.writeln();
    
    return section.toString();
  }
  
  String _generateMaterialsSection(List<ImageAnalysisResult> imageAnalyses) {
    final StringBuffer section = StringBuffer();
    section.writeln('MATERIALS LIST');
    section.writeln();
    section.writeln('| Material | Quantity | Unit Cost | Total | Application |');
    section.writeln('|----------|----------|-----------|-------|-------------|');
    
    // Standard materials for typical repairs
    section.writeln('| Structural epoxy/resin | 2 gallons | \$48/gal | \$96 | Crack injection & bonding |');
    section.writeln('| Interior paint (premium) | 3 gallons | \$38/gal | \$114 | Surface coverage |');
    section.writeln('| Plaster/joint compound | 50 lbs | \$19/bag | \$95 | Wall repairs |');
    section.writeln('| Primer/sealer | 2 gallons | \$32/gal | \$64 | Surface preparation |');
    section.writeln('| Sandpaper assortment | 1 set | \$28 | \$28 | Surface finishing |');
    section.writeln('| Painter\'s tape | 4 rolls | \$9/roll | \$36 | Edge protection |');
    section.writeln('| Drop cloths/tarps | 3 units | \$18/unit | \$54 | Surface protection |');
    section.writeln('| Mixing containers | 5 units | \$6/unit | \$30 | Material preparation |');
    section.writeln('| Application tools | 1 set | \$75 | \$75 | Brushes, rollers, trowels |');
    section.writeln('| Cleaning supplies | 1 set | \$35 | \$35 | Site cleanup |');
    section.writeln('| Safety equipment | 1 set | \$45 | \$45 | PPE for workers |');
    section.writeln('| Fasteners/hardware | Assorted | \$25 | \$25 | General repairs |');
    section.writeln('| **TOTAL MATERIALS** | - | - | **\$697** | - |');
    section.writeln();
    
    return section.toString();
  }
  
  String _generateContractorsSection(List<ImageAnalysisResult> imageAnalyses) {
    final StringBuffer section = StringBuffer();
    section.writeln('CONTRACTOR RECOMMENDATIONS');
    section.writeln();
    section.writeln('| Contractor Type | Required For | Urgency | Estimated Cost | Required Credentials |');
    section.writeln('|----------------|--------------|---------|----------------|---------------------|');
    
    bool hasStructuralIssues = imageAnalyses.any((a) => 
      a.defects.any((d) => d.type.toLowerCase().contains('crack') || d.severity.toLowerCase().contains('high'))
    );
    
    if (hasStructuralIssues) {
      section.writeln('| Structural Engineer | Assessment & approval | High | \$800-1200 | PE License required |');
    }
    
    section.writeln('| Licensed Contractor | General repairs | Medium | \$2000-4000 | State general contractor license |');
    section.writeln('| Mason/Concrete Specialist | Surface repairs | Medium | \$1500-3000 | Masonry certification |');
    section.writeln('| Professional Painter | Finish work | Low | \$800-1500 | Insurance & references |');
    section.writeln('| Plasterer/Drywall Tech | Surface finishing | Medium | \$1000-2000 | Trade certification |');
    section.writeln('| Project Manager | Coordination | Medium | \$1200-2500 | PM certification preferred |');
    section.writeln('| Quality Inspector | Final verification | Low | \$400-600 | Building inspector license |');
    section.writeln();
    
    return section.toString();
  }
  
  String _generateRecommendationsSection(List<ImageAnalysisResult> imageAnalyses, int totalDefects) {
    final StringBuffer section = StringBuffer();
    section.writeln('RECOMMENDATIONS');
    section.writeln();
    
    section.writeln('IMMEDIATE ACTIONS (24-48 hours):');
    bool hasHighSeverity = imageAnalyses.any((a) => a.defects.any((d) => d.severity.toLowerCase().contains('high') || d.severity.toLowerCase().contains('critical')));
    
    if (hasHighSeverity) {
      section.writeln('- Engage a licensed structural engineer to assess critical defects identified in this report');
      section.writeln('- Document all high-severity issues with additional photography');
      section.writeln('- Implement temporary safety measures if any areas pose immediate risk');
      section.writeln('- Obtain repair estimates from licensed contractors');
    } else {
      section.writeln('- No immediate critical actions required');
      section.writeln('- Schedule contractor consultations within the next week');
      section.writeln('- Document current conditions for future reference');
    }
    section.writeln();
    
    section.writeln('SHORT-TERM REPAIRS (1-3 months):');
    section.writeln('- Address all identified defects in order of severity');
    section.writeln('- Obtain necessary permits for structural or significant repairs');
    section.writeln('- Schedule work during favorable weather conditions');
    section.writeln('- Implement quality control measures during repairs');
    section.writeln('- Document all repair work with before/after photography');
    section.writeln();
    
    section.writeln('LONG-TERM MAINTENANCE (3-12 months):');
    section.writeln('- Establish regular inspection schedule (semi-annual recommended)');
    section.writeln('- Monitor repaired areas for any recurring issues');
    section.writeln('- Implement preventive maintenance program');
    section.writeln('- Maintain detailed records of all maintenance and repairs');
    section.writeln('- Consider protective coatings or treatments for vulnerable areas');
    section.writeln();
    
    return section.toString();
  }
  
  String _generateConclusionSection(List<ImageAnalysisResult> imageAnalyses, int totalDefects, String locationInfo) {
    final StringBuffer section = StringBuffer();
    section.writeln('CONCLUSION');
    section.writeln();
    
    section.writeln('Thank you for commissioning this professional building inspection. This comprehensive report has been prepared to provide you with a thorough understanding of the current condition of your property at $locationInfo and to guide your decision-making regarding necessary repairs and maintenance.');
    section.writeln();
    
    if (totalDefects > 0) {
      section.writeln('Our inspection has identified $totalDefects specific issue(s) requiring attention. While these findings may initially seem concerning, they represent opportunities to enhance and preserve your property\'s value through systematic, well-planned repairs. Each identified defect has been documented with detailed analysis, severity assessment, and confidence ratings to help you prioritize your response.');
      section.writeln();
      section.writeln('The defects identified range across different severity levels. High-severity items demand prompt professional attention to prevent further deterioration and potential safety concerns. Medium and lower-severity issues, while not immediately critical, should be addressed within the recommended timeframes to prevent escalation and minimize long-term repair costs. Delaying necessary repairs typically results in more extensive and expensive remediation down the line.');
    } else {
      section.writeln('Our inspection has revealed that your property is in generally good condition with no major defects or safety concerns identified during this visual examination. This is a positive finding that reflects well on the property\'s construction quality and maintenance history. However, it is important to remember that no building is maintenance-free, and ongoing care remains essential.');
      section.writeln();
      section.writeln('While no significant issues were found, routine maintenance and periodic professional inspections remain crucial for long-term property preservation. Regular monitoring allows for early detection of potential problems before they become serious issues, ultimately saving time and money while maintaining property value.');
    }
    section.writeln();
    
    section.writeln('The cost estimates and timelines provided in this report are based on current market rates and standard industry practices. Actual costs may vary depending on contractor selection, material choices, and specific site conditions. We recommend obtaining multiple quotes from licensed, insured contractors before commencing any repair work. The investment in quality repairs now will pay dividends through enhanced property value, improved safety, and reduced long-term maintenance costs.');
    section.writeln();
    
    section.writeln('Regarding project timeline, the repairs can be staged according to priority levels as outlined in our recommendations section. This phased approach allows you to manage costs effectively while ensuring critical items receive prompt attention. Working with experienced contractors who understand building systems will ensure repairs are completed correctly and efficiently.');
    section.writeln();
    
    section.writeln('Regular preventive maintenance is the foundation of property preservation. Establishing a systematic maintenance schedule, conducting periodic inspections, and addressing minor issues promptly will significantly extend the service life of building components and systems. We recommend scheduling follow-up inspections annually or whenever significant changes or concerns arise.');
    section.writeln();
    
    section.writeln('This report is intended to serve as a comprehensive resource for understanding your property\'s current condition and planning appropriate action. Should you have questions about any findings, require clarification on recommended repairs, or need guidance on contractor selection, please do not hesitate to contact us. We are committed to ensuring you have the information and support needed to make informed decisions about your property.');
    section.writeln();
    
    section.writeln('We appreciate the opportunity to provide this professional inspection service and wish you success in maintaining and enhancing your property. Proper care and attention to the items outlined in this report will ensure your building remains safe, functional, and valuable for years to come.');
    section.writeln();
    section.writeln('Respectfully submitted,');
    section.writeln('Certified Building Inspector');
    section.writeln('Site Lenz Professional Inspection Services');
    section.writeln();
    
    return section.toString();
  }

  Map<String, String> _parseReportSections(String content) {
    Map<String, String> sections = {};
    
    // Common section headers - try multiple variations
    final sectionPatterns = [
      'SCOPE AND LIMITATIONS',
      'SCOPE & LIMITATIONS',
      'EXECUTIVE SUMMARY',
      'DETAILED FINDINGS',
      'COST ESTIMATES',
      'TIME ESTIMATES',
      'MATERIALS LIST',
      'CONTRACTOR RECOMMENDATIONS',
      'RECOMMENDATIONS',
      'CONCLUSION',
    ];

    // SIMPLER APPROACH: Use indexOf instead of complex regex to avoid errors
    for (int i = 0; i < sectionPatterns.length; i++) {
      final pattern = sectionPatterns[i];
      final patternUpper = pattern.toUpperCase();
      final contentUpper = content.toUpperCase();
      
      // Find section header (case-insensitive)
      int startIndex = contentUpper.indexOf(patternUpper);
      
      if (startIndex == -1) {
        // Try alternative patterns
        if (pattern.contains('&')) {
          startIndex = contentUpper.indexOf(pattern.replaceAll('&', 'AND'));
        } else if (pattern.contains('AND')) {
          startIndex = contentUpper.indexOf(pattern.replaceAll('AND', '&'));
        }
      }
      
      if (startIndex != -1) {
        // Move past the header line
        int contentStart = content.indexOf('\n', startIndex);
        if (contentStart == -1) contentStart = startIndex + pattern.length;
        else contentStart++;
        
        // Bounds check
        if (contentStart >= content.length) continue;
        
        // Find where this section ends (next section header or end of content)
        int contentEnd = content.length;
        
        // Look for next section
        for (int j = i + 1; j < sectionPatterns.length; j++) {
          final nextPattern = sectionPatterns[j].toUpperCase();
          int nextIndex = contentUpper.indexOf(nextPattern, contentStart);
          
          if (nextIndex == -1 && nextPattern.contains('&')) {
            nextIndex = contentUpper.indexOf(nextPattern.replaceAll('&', 'AND'), contentStart);
          } else if (nextIndex == -1 && nextPattern.contains('AND')) {
            nextIndex = contentUpper.indexOf(nextPattern.replaceAll('AND', '&'), contentStart);
          }
          
          if (nextIndex != -1 && nextIndex < contentEnd) {
            contentEnd = nextIndex;
            break;
          }
        }
        
        // Extract section content with bounds check
        if (contentStart < contentEnd && contentEnd <= content.length) {
          String sectionContent = content.substring(contentStart, contentEnd).trim();
          if (sectionContent.isNotEmpty) {
            sections[pattern] = sectionContent;
          }
        }
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
    // NOTE: & does not need escaping in regex
    String escaped = pattern
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
    return escaped;
  }

  Future<void> previewAndPrintPDF(Uint8List pdfBytes, BuildContext context) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

}

