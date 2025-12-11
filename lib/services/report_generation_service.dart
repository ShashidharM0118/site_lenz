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

    // === STAGE 1: INDIVIDUAL IMAGE ANALYSIS (GEMINI) ===
    onProgressUpdate?.call('Stage 1: Analyzing images with Gemini AI...');
    
    List<ImageAnalysisResult> imageAnalyses = [];
    List<Future<ImageAnalysisResult?>> analysisFutures = [];
    
    // Launch all image analyses in parallel
    for (int i = 0; i < allImagePaths.length; i++) {
      analysisFutures.add(
        _imageAnalysisService.analyzeImage(allImagePaths[i], i + 1).catchError((e) {
          print('Warning: Failed to analyze image ${i + 1}: $e');
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
    // Create comprehensive prompt for Groq with enhanced system instructions
    final StringBuffer promptBuffer = StringBuffer();
    
    promptBuffer.writeln('=== SYSTEM ROLE ===');
    promptBuffer.writeln('You are a Certified Master Building Inspector (CMI), Structural Engineer, and Legal Compliance Officer with 20+ years of experience.');
    promptBuffer.writeln('You specialize in comprehensive building assessments, cost estimation, and regulatory compliance.');
    promptBuffer.writeln('Your reports are used for insurance claims, litigation, and major construction decisions.');
    promptBuffer.writeln();
    promptBuffer.writeln('=== CRITICAL INSTRUCTIONS ===');
    promptBuffer.writeln('1. You MUST generate ALL sections in ONE SINGLE RESPONSE');
    promptBuffer.writeln('2. COMPLETE the ENTIRE report before returning any response');
    promptBuffer.writeln('3. EVERY section MUST be fully written with detailed, specific content');
    promptBuffer.writeln('4. NO section should say "AI Analysis in Progress" or "Will be generated" or be left empty');
    promptBuffer.writeln('5. Generate REAL, SPECIFIC data for costs, times, materials, and contractors based on the defects found');
    promptBuffer.writeln('6. Use the image analysis data provided to create realistic estimates');
    promptBuffer.writeln('7. If specific defects are found, calculate actual repair costs based on 2025 industry standards');
    promptBuffer.writeln('8. Include multiple items in each section (minimum 5-10 items per section)');
    promptBuffer.writeln('9. Be thorough, detailed, and professional throughout - this is a COMPLETE report');
    promptBuffer.writeln('10. Generate ALL 9 sections (Scope, Executive Summary, Cost Estimates, Time Estimates, Materials, Contractors, Findings, Recommendations, Conclusion)');
    promptBuffer.writeln();
    promptBuffer.writeln('=== INPUT DATA ===');
    promptBuffer.writeln();
    promptBuffer.writeln('INSPECTOR TRANSCRIPT/NOTES:');
    promptBuffer.writeln(userTranscript);
    promptBuffer.writeln();
    promptBuffer.writeln(formattedImageAnalyses);
    promptBuffer.writeln();
    promptBuffer.writeln('=== OUTPUT FORMAT - GENERATE ALL SECTIONS BELOW ===');
    promptBuffer.writeln('You must write the complete report with ALL sections filled out.');
    promptBuffer.writeln();
    
    promptBuffer.writeln('SCOPE & LIMITATIONS');
    promptBuffer.writeln('Write 3-4 paragraphs covering:');
    promptBuffer.writeln('- Include this EXACT legal text first: "This inspection was performed in accordance with current Standards of Practice. It is a non-invasive, visual examination of the readily accessible areas of the building. It is not a warranty, insurance policy, or guarantee of future performance. Latent or concealed defects (e.g., behind drywall, underground) are excluded."');
    promptBuffer.writeln('- Scope of the inspection performed');
    promptBuffer.writeln('- Areas examined and inspection methodology');
    promptBuffer.writeln('- Limitations and exclusions');
    promptBuffer.writeln('- Standards and guidelines followed');
    promptBuffer.writeln();
    
    promptBuffer.writeln('EXECUTIVE SUMMARY');
    promptBuffer.writeln('Write 3-4 comprehensive paragraphs summarizing:');
    promptBuffer.writeln('- Overall property condition assessment');
    promptBuffer.writeln('- Key findings and concerns');
    promptBuffer.writeln('- Priority recommendations');
    promptBuffer.writeln('Then create detailed tables/lists:');
    promptBuffer.writeln('  SAFETY HAZARDS TABLE:');
    promptBuffer.writeln('  For EACH safety hazard found, list:');
    promptBuffer.writeln('    * Location (specific room/area)');
    promptBuffer.writeln('    * Hazard description (detailed)');
    promptBuffer.writeln('    * Severity (Critical/High/Medium)');
    promptBuffer.writeln('    * Urgency (Immediate/Within 24hrs/Within 1 week)');
    promptBuffer.writeln('  MAJOR DEFECTS TABLE:');
    promptBuffer.writeln('  For EACH major defect found, list:');
    promptBuffer.writeln('    * Location');
    promptBuffer.writeln('    * Defect description');
    promptBuffer.writeln('    * Severity level');
    promptBuffer.writeln('    * Recommended action');
    promptBuffer.writeln();
    
    promptBuffer.writeln('COST ESTIMATES');
    promptBuffer.writeln('MANDATORY: Generate COMPLETE cost breakdown for ALL defects found.');
    promptBuffer.writeln('For EACH defect/repair item, provide:');
    promptBuffer.writeln('Format as a detailed table:');
    promptBuffer.writeln('| Repair Item | Location | Material Cost | Labor Cost | Total Cost |');
    promptBuffer.writeln('Example entries:');
    promptBuffer.writeln('- Wall crack repair (structural): Material \$150-200, Labor \$300-400, Total: \$450-600');
    promptBuffer.writeln('- Paint touch-up (10 sq ft): Material \$25-35, Labor \$75-100, Total: \$100-135');
    promptBuffer.writeln('- Plaster repair (damaged area): Material \$80-120, Labor \$200-300, Total: \$280-420');
    promptBuffer.writeln('MUST INCLUDE:');
    promptBuffer.writeln('- Minimum 5-10 repair items with specific costs');
    promptBuffer.writeln('- Line item for each defect found in images');
    promptBuffer.writeln('- Subtotals for different categories (structural, cosmetic, etc.)');
    promptBuffer.writeln('- TOTAL ESTIMATED COST at the end (sum all items)');
    promptBuffer.writeln('- Include 10-15% contingency for unforeseen issues');
    promptBuffer.writeln('Use realistic market rates for 2025. Be specific with dollar amounts.');
    promptBuffer.writeln();
    
    promptBuffer.writeln('TIME ESTIMATES');
    promptBuffer.writeln('MANDATORY: Generate COMPLETE time breakdown for ALL repairs.');
    promptBuffer.writeln('For EACH repair task, specify:');
    promptBuffer.writeln('Format as a detailed table:');
    promptBuffer.writeln('| Repair Task | Duration | Crew Size | Best Time to Complete |');
    promptBuffer.writeln('Example entries:');
    promptBuffer.writeln('- Structural crack repair: 2-3 days (2 workers)');
    promptBuffer.writeln('- Surface prep and painting: 1-2 days (1 worker)');
    promptBuffer.writeln('- Plaster repair and finishing: 3-4 days (2 workers, includes drying time)');
    promptBuffer.writeln('MUST INCLUDE:');
    promptBuffer.writeln('- Time estimate for EACH cost item listed above');
    promptBuffer.writeln('- Crew size needed');
    promptBuffer.writeln('- Weather/seasonal considerations if applicable');
    promptBuffer.writeln('- TOTAL ESTIMATED TIME (accounting for sequential vs parallel work)');
    promptBuffer.writeln('- Critical path items that affect overall timeline');
    promptBuffer.writeln();
    
    promptBuffer.writeln('MATERIALS LIST');
    promptBuffer.writeln('MANDATORY: Generate COMPLETE itemized materials list.');
    promptBuffer.writeln('Format as a comprehensive table:');
    promptBuffer.writeln('| Material Name | Quantity | Unit Cost | Total Cost | Application/Purpose |');
    promptBuffer.writeln('MUST INCLUDE materials for ALL repairs mentioned in cost estimates:');
    promptBuffer.writeln('Examples:');
    promptBuffer.writeln('- Structural epoxy/resin: 2 gallons @ \$45/gal = \$90 (crack injection)');
    promptBuffer.writeln('- Interior paint (premium): 3 gallons @ \$38/gal = \$114 (wall coverage)');
    promptBuffer.writeln('- Plaster/joint compound: 50 lbs @ \$18/bag = \$90 (wall repairs)');
    promptBuffer.writeln('- Primer/sealer: 2 gallons @ \$28/gal = \$56 (surface prep)');
    promptBuffer.writeln('- Sandpaper (various grits): 1 set @ \$25 = \$25 (surface finishing)');
    promptBuffer.writeln('- Painter\'s tape: 3 rolls @ \$8/roll = \$24 (edge protection)');
    promptBuffer.writeln('Include: cement, mortar, fasteners, adhesives, paints, sealants, etc.');
    promptBuffer.writeln('List minimum 10-15 material items with specific quantities and costs.');
    promptBuffer.writeln();
    
    promptBuffer.writeln('CONTRACTOR RECOMMENDATIONS');
    promptBuffer.writeln('MANDATORY: List ALL contractor types needed for the repairs.');
    promptBuffer.writeln('For EACH contractor type, specify:');
    promptBuffer.writeln('Format as detailed entries:');
    promptBuffer.writeln('| Contractor Type | Required For | Urgency | Estimated Cost | Credentials Needed |');
    promptBuffer.writeln('MUST INCLUDE (based on defects found):');
    promptBuffer.writeln('- Structural Engineer (if structural issues): Reason, Urgency, \$500-1000 for assessment');
    promptBuffer.writeln('- Licensed Mason/Masonry Contractor: Reason, Urgency, cost estimate');
    promptBuffer.writeln('- Professional Painter: Reason, Urgency, cost estimate');
    promptBuffer.writeln('- Plasterer/Drywall Specialist: Reason, Urgency, cost estimate');
    promptBuffer.writeln('- General Contractor/Project Manager: Reason, Urgency, cost estimate');
    promptBuffer.writeln('Include minimum 5-8 contractor types with specific rationale for each.');
    promptBuffer.writeln('Specify required licenses, certifications, or specializations.');
    promptBuffer.writeln();
    
    promptBuffer.writeln('DETAILED FINDINGS');
    promptBuffer.writeln('Write comprehensive analysis (4-6 paragraphs) covering:');
    promptBuffer.writeln('- Structural integrity assessment of all elements examined');
    promptBuffer.writeln('- Surface condition analysis (cracks, deterioration, damage patterns)');
    promptBuffer.writeln('- Material assessment (age, quality, degradation)');
    promptBuffer.writeln('- Patterns observed across multiple images/areas');
    promptBuffer.writeln('- Root cause analysis for identified issues');
    promptBuffer.writeln('- Interconnected issues that may affect multiple systems');
    promptBuffer.writeln('Be specific, technical, and reference image analysis data.');
    promptBuffer.writeln();
    
    promptBuffer.writeln('RECOMMENDATIONS');
    promptBuffer.writeln('Organize in priority order with 3-4 paragraphs for EACH category:');
    promptBuffer.writeln('IMMEDIATE ACTIONS (Critical - Within 24-48 hours):');
    promptBuffer.writeln('  - List specific actions with detailed reasoning');
    promptBuffer.writeln('  - Include safety implications');
    promptBuffer.writeln('  - Specify temporary measures if needed');
    promptBuffer.writeln('SHORT-TERM MAINTENANCE (Within 1-3 months):');
    promptBuffer.writeln('  - Prioritized list of repairs');
    promptBuffer.writeln('  - Rationale for each recommendation');
    promptBuffer.writeln('  - Consequences of delaying action');
    promptBuffer.writeln('LONG-TERM CONSIDERATIONS (3-12 months):');
    promptBuffer.writeln('  - Preventive maintenance recommendations');
    promptBuffer.writeln('  - Monitoring requirements');
    promptBuffer.writeln('  - Future inspection schedule');
    promptBuffer.writeln('Be specific and actionable for each recommendation.');
    promptBuffer.writeln();
    
    promptBuffer.writeln('CONCLUSION');
    promptBuffer.writeln('CRITICAL: Write a comprehensive, professional conclusion of AT LEAST 500 WORDS.');
    promptBuffer.writeln('This must be a COMPLETE, FULLY-WRITTEN conclusion, not a placeholder.');
    promptBuffer.writeln('Structure as 6-8 detailed paragraphs covering:');
    promptBuffer.writeln('Paragraph 1: Thank the client and acknowledge property ownership responsibilities');
    promptBuffer.writeln('Paragraph 2: Comprehensive summary of ALL key findings (be specific, reference actual defects found)');
    promptBuffer.writeln('Paragraph 3: Reiterate critical safety hazards and immediate action items');
    promptBuffer.writeln('Paragraph 4: Discuss major defects, long-term implications, and repair priority');
    promptBuffer.writeln('Paragraph 5: Financial summary - total costs, budgeting advice, potential ROI of repairs');
    promptBuffer.writeln('Paragraph 6: Timeline guidance and project management recommendations');
    promptBuffer.writeln('Paragraph 7: Value of preventive maintenance and regular inspections');
    promptBuffer.writeln('Paragraph 8: Closing remarks, offer support, contact information, professional signature');
    promptBuffer.writeln('MINIMUM 500 WORDS. Make it substantive, informative, and professionally written.');
    promptBuffer.writeln('This should be a complete, detailed narrative that provides closure to the report.');
    promptBuffer.writeln();
    
    promptBuffer.writeln('=== FORMATTING REQUIREMENTS ===');
    promptBuffer.writeln('- Use clear section headers (all caps for main sections)');
    promptBuffer.writeln('- Use bullet points (-) for lists');
    promptBuffer.writeln('- Use numbered lists (1., 2., 3.) for sequential steps');
    promptBuffer.writeln('- Include table-like formatting with | separators where specified');
    promptBuffer.writeln('- Separate sections with blank lines');
    promptBuffer.writeln('- Be consistent with terminology and formatting throughout');
    promptBuffer.writeln();
    
    promptBuffer.writeln('=== QUALITY STANDARDS ===');
    promptBuffer.writeln('- NO incomplete sections or placeholders');
    promptBuffer.writeln('- ALL costs must be realistic 2025 market rates');
    promptBuffer.writeln('- ALL recommendations must be specific and actionable');
    promptBuffer.writeln('- Use proper building inspection terminology');
    promptBuffer.writeln('- Cross-reference between sections for consistency');
    promptBuffer.writeln('- Ensure all numbers, dates, and figures are accurate');
    
    String prompt = promptBuffer.toString();

    // Generate comprehensive report using Groq (text-only, Groq handles comprehensive text generation)
    // Use maximum tokens for this detailed report generation
    onProgressUpdate?.call('Generating comprehensive AI report (all sections)...');
    await Future.delayed(const Duration(milliseconds: 300));
    
    int originalMaxTokens = 4096;
    _groqService.setMaxTokens(16384); // Use maximum token limit for comprehensive detailed report
    
    onProgressUpdate?.call('Groq AI writing complete report with all sections...');
    String? reportContent = await _groqService.generateText(prompt);
    
    // Restore original max tokens after generation
    _groqService.setMaxTokens(originalMaxTokens);
    
    if (reportContent == null || reportContent.isEmpty) {
      throw Exception('Failed to generate comprehensive report from Groq');
    }

    // Validate that key sections exist in the generated content
    final requiredSections = ['COST ESTIMATES', 'TIME ESTIMATES', 'MATERIALS LIST', 'CONTRACTOR RECOMMENDATIONS', 'CONCLUSION'];
    final missingSections = <String>[];
    
    for (var section in requiredSections) {
      if (!reportContent.toUpperCase().contains(section)) {
        missingSections.add(section);
      }
    }
    
    if (missingSections.isNotEmpty) {
      print('WARNING: Generated report is missing sections: ${missingSections.join(", ")}');
      print('Report length: ${reportContent.length} characters');
      // Still return the content, but log the warning
    }

    onProgressUpdate?.call('Verified all sections generated successfully!');
    await Future.delayed(const Duration(milliseconds: 300));

    return reportContent;
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

