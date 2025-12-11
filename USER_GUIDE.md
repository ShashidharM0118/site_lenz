# Site Lenz - AI-Powered Building Inspection App
## Complete User Guide & Instructions

---

## TABLE OF CONTENTS

1. Overview
2. Features
3. Getting Started
4. Recording Inspections
5. Viewing Logs
6. Generating Reports
7. AI Chatbot
8. Understanding Reports
9. Troubleshooting
10. Tips & Best Practices

---

## 1. OVERVIEW

**Site Lenz** is an AI-powered mobile application designed for professional building inspections. It combines real-time speech-to-text transcription, camera capture, and advanced AI analysis to generate comprehensive inspection reports.

### Key Technologies:
- **Gemini AI**: Analyzes building photos to detect defects, assess conditions, and identify issues
- **Groq AI**: Generates comprehensive professional reports with cost estimates, timelines, and recommendations
- **Real-time Transcription**: Converts your spoken observations into text automatically
- **PDF Generation**: Creates professional, detailed inspection reports

---

## 2. FEATURES

### ✅ Real-Time Transcription
- Voice-to-text conversion as you speak
- Hands-free operation during inspections
- Automatic saving of transcripts with images

### ✅ Image Analysis
- AI-powered defect detection
- Material type identification
- Condition assessment
- Confidence scoring for each finding

### ✅ Comprehensive Reports
- **9 Main Sections**: Scope, Executive Summary, Cost Estimates, Time Estimates, Materials List, Contractor Recommendations, Detailed Findings, Recommendations, Conclusion
- Professional PDF format
- Cost breakdowns with labor and materials
- Time estimates for repairs
- Contractor requirements

### ✅ AI Chat Assistant
- Ask questions about inspections
- Get building advice
- Image analysis on demand
- Multiple AI models available (Gemini, Groq, OpenAI)

---

## 3. GETTING STARTED

### First Launch
1. **Splash Screen**: The app displays an animated "SITE LENZ" splash screen with purple gradient background
2. **Permissions**: Grant camera and microphone permissions when prompted
3. **Navigation**: Use the bottom navigation bar with three tabs:
   - 🎤 **Record**: Main inspection screen
   - 📁 **Logs**: View saved inspections
   - 💬 **AI Chat**: Interact with AI assistant

### App Theme
- **Primary Color**: Deep Purple (#5F259F)
- **Accent Color**: Lime Green (#B8E600)
- **Design**: Modern, rounded corners, outlined components

---

## 4. RECORDING INSPECTIONS

### Step-by-Step Process:

#### Step 1: Navigate to Record Tab
- Tap the microphone icon (🎤) in the bottom navigation
- You'll see the live camera preview at the top

#### Step 2: Start Logging
1. Tap the green **"START LOGGING"** button
2. The button changes to purple **"STOP LOGGING"**
3. Begin speaking your observations
4. Your speech appears in real-time in the "Live Transcript" box below

#### Step 3: Record Your Observations
**What to say:**
- Describe the location (e.g., "Front wall, second floor")
- Note visible conditions (e.g., "Large crack running diagonally")
- Mention materials (e.g., "Brick wall", "Concrete surface")
- Describe severity (e.g., "Significant damage", "Minor wear")
- Add context (e.g., "Appears water damaged", "Structural concern")

**Example:**
> "Inspecting the north-facing exterior wall. I can see a vertical crack approximately 3 feet long starting from the window frame. The crack is about half an inch wide at its widest point. The surrounding plaster shows signs of water damage with discoloration and flaking. This appears to be a structural concern that needs immediate attention."

#### Step 4: Capture & Save
1. Tap **"STOP LOGGING"** when finished with this observation
2. The app automatically captures a photo from the camera
3. The transcript and image are saved together as one log entry
4. The transcript box clears, ready for the next observation

#### Step 5: Repeat
- Continue for each area or issue you want to document
- Each "Start → Record → Stop" cycle creates one log entry
- Build up multiple entries for a complete inspection

### 📌 Tips for Recording:
- Speak clearly and at a moderate pace
- Pause between thoughts for better transcription
- Position camera to capture the issue clearly
- Ensure good lighting for better image analysis
- Include measurements when possible
- Mention safety concerns explicitly

---

## 5. VIEWING LOGS

### Accessing Your Logs:
1. Tap the folder icon (📁) in the bottom navigation
2. View all saved inspection entries

### Log Display:
Each log card shows:
- **Thumbnail**: Preview of the captured image
- **Transcript**: First 50 characters of your observation
- **Timestamp**: When the log was created (e.g., "2 hours ago")
- **Report Button**: Outlined purple button with document icon

### Log Actions:

#### View Details:
- Tap anywhere on the log card
- See full transcript and full-size image
- Review timestamp and session information

#### Generate Single Report:
1. Tap the **"Report"** button on any log card
2. Choose AI provider for image analysis:
   - **Gemini**: Recommended, fast, accurate
   - **OpenAI (GPT-4o)**: Alternative option
3. Wait for analysis (animated loader appears)
4. PDF preview opens automatically
5. Share, save, or print from the preview

#### Generate Combined Report (All Logs):
1. If you have multiple logs, tap the green floating action button (FAB) at bottom-right
2. Shows **"Generate Report"** with document icon
3. Creates comprehensive report from ALL saved logs
4. Combines all images and transcripts into one professional document

#### Clear All Logs:
- Tap the trash icon (🗑️) in the top-right corner
- Confirm deletion
- All logs are permanently removed

---

## 6. GENERATING REPORTS

### The Report Generation Process:

#### Phase 1: Image Analysis (Gemini AI)
**What happens:**
- All captured images analyzed simultaneously (parallel processing)
- AI detects defects, cracks, damage, deterioration
- Identifies material types (concrete, brick, plaster, etc.)
- Assesses overall condition
- Assigns confidence scores to findings
- Duration: ~5-10 seconds per image (processed in parallel)

**Progress shown:**
- "Stage 1: Analyzing images with Gemini AI..."
- "Processing X images in parallel..."
- "Completed Y/X image analyses..."

#### Phase 2: Insight Extraction
**What happens:**
- Aggregates all Gemini analysis results
- Combines with your transcripts
- Calculates statistics (total defects, severity levels)
- Formats comprehensive data for report generation

**Progress shown:**
- "Extracting comprehensive insights from analyses..."

#### Phase 3: Report Generation (Groq AI)
**What happens:**
- Groq AI receives all analysis data + transcripts
- Generates complete professional report with ALL sections:
  1. Scope & Limitations
  2. Executive Summary
  3. Cost Estimates
  4. Time Estimates
  5. Materials List
  6. Contractor Recommendations
  7. Detailed Findings
  8. Recommendations
  9. Conclusion
- Duration: ~15-30 seconds

**Progress shown:**
- "Feeding data to Groq for comprehensive report generation..."
- "Groq AI writing complete report with all sections..."
- "Verified all sections generated successfully!"

#### Phase 4: PDF Creation
**What happens:**
- Formats content into professional PDF
- Adds images with analysis overlays
- Creates table of contents
- Applies styling and formatting
- Generates cover page with date/time

**Progress shown:**
- "Preparing PDF generation..."
- "Creating PDF document structure..."
- "Processing report sections..."
- "Formatting professional document layout..."
- "Finalizing PDF document..."

### Beautiful Animated Loader
During generation, you'll see:
- Gradient purple/green background
- Rotating circular progress indicator
- Pulsing percentage display
- Real-time status messages
- Smooth wave animation at bottom

---

## 7. AI CHATBOT

### Access the AI Chat:
- Tap the chat bubble icon (💬) in bottom navigation

### Features:

#### Multiple AI Models:
Switch between providers using tabs at top:
- **Groq**: Fast text-based responses (llama-3.3-70b)
- **OpenAI**: GPT-4o for advanced queries
- **Gemini**: Google's AI with vision capabilities

#### Chat with Text:
1. Type your question in the input field at bottom
2. Tap the green send button
3. Receive AI-generated response

**Example questions:**
- "What causes vertical cracks in brick walls?"
- "How much does structural repair typically cost?"
- "What contractor do I need for foundation issues?"
- "Is this crack structural or cosmetic?"

#### Chat with Images:
1. Tap the photo icon (📷) to add images
2. Select one or multiple images
3. Type your question or leave blank for general analysis
4. AI analyzes the images and responds
5. Remove unwanted images by tapping the X on thumbnails

**Example image queries:**
- "Analyze this wall damage"
- "Is this crack serious?"
- "What type of repair is needed?"
- "Estimate the cost to fix this"

#### Chat Features:
- **Conversation History**: Scrollable chat interface
- **Message Bubbles**: Purple for your messages, light gray for AI
- **Clear Chat**: Tap trash icon to start fresh
- **Model Selection**: Change AI models anytime

---

## 8. UNDERSTANDING REPORTS

### Report Structure (9 Sections):

#### 1. SCOPE & LIMITATIONS
- Legal disclaimer
- Inspection methodology
- What was examined
- What was excluded
- Standards followed

#### 2. EXECUTIVE SUMMARY
**Includes:**
- Overall property assessment (2-3 paragraphs)
- Safety Hazards Table (Critical issues requiring immediate action)
- Major Defects Table (Significant problems found)

**Table columns:**
- Location, Description, Severity, Urgency

#### 3. COST ESTIMATES
**Detailed breakdown:**

| Repair Item | Location | Material Cost | Labor Cost | Total Cost |
|------------|----------|---------------|------------|------------|
| Wall crack repair | Front wall | $150-200 | $300-400 | $450-600 |
| Paint touch-up | Living room | $25-35 | $75-100 | $100-135 |
| Plaster repair | Bedroom | $80-120 | $200-300 | $280-420 |

**Includes:**
- 5-10+ repair items
- Material and labor costs separated
- Subtotals by category
- **TOTAL ESTIMATED COST** at end
- 10-15% contingency included

#### 4. TIME ESTIMATES
**Detailed breakdown:**

| Repair Task | Duration | Crew Size | Best Time |
|------------|----------|-----------|-----------|
| Structural crack repair | 2-3 days | 2 workers | Spring/Fall |
| Surface prep and painting | 1-2 days | 1 worker | Any time |
| Plaster repair | 3-4 days | 2 workers | Summer (drying) |

**Includes:**
- Time for each repair
- Crew requirements
- Seasonal considerations
- **TOTAL ESTIMATED TIME**
- Critical path items

#### 5. MATERIALS LIST
**Comprehensive table:**

| Material Name | Quantity | Unit Cost | Total | Purpose |
|--------------|----------|-----------|-------|---------|
| Structural epoxy | 2 gallons | $45/gal | $90 | Crack injection |
| Interior paint | 3 gallons | $38/gal | $114 | Wall coverage |
| Joint compound | 50 lbs | $18/bag | $90 | Wall repairs |
| Primer/sealer | 2 gallons | $28/gal | $56 | Surface prep |
| Sandpaper set | 1 set | $25 | $25 | Finishing |

**Includes:**
- 10-15+ material items
- Specific quantities
- Unit and total costs
- Application purpose

#### 6. CONTRACTOR RECOMMENDATIONS
**Detailed list:**

| Contractor Type | Required For | Urgency | Est. Cost | Credentials |
|----------------|--------------|---------|-----------|-------------|
| Structural Engineer | Foundation assessment | Immediate | $500-1000 | PE License |
| Mason | Brick repair | Within 1 month | $2000-3000 | Licensed |
| Painter | Wall finishing | Within 3 months | $800-1200 | Insured |
| Plasterer | Surface repair | Within 2 months | $1500-2000 | Certified |

**Includes:**
- 5-8+ contractor types
- Specific needs
- Urgency levels
- Cost estimates
- Required credentials

#### 7. DETAILED FINDINGS
**Comprehensive analysis (4-6 paragraphs):**
- Structural integrity assessment
- Surface condition analysis
- Material degradation details
- Patterns across multiple areas
- Root cause analysis
- Interconnected issues

#### 8. RECOMMENDATIONS
**Organized by priority:**

**IMMEDIATE ACTIONS** (24-48 hours):
- Critical safety issues
- Temporary measures
- Emergency repairs

**SHORT-TERM** (1-3 months):
- Important repairs
- Preventive maintenance
- System improvements

**LONG-TERM** (3-12 months):
- Monitoring requirements
- Future inspections
- Upgrade recommendations

#### 9. CONCLUSION
**Comprehensive closing (500+ words, 6-8 paragraphs):**
- Thank you to client
- Complete findings summary
- Safety hazard emphasis
- Major defect discussion
- Financial summary
- Timeline guidance
- Maintenance value
- Contact information
- Professional signature

### PDF Formatting:
- **Cover Page**: Purple header with Site Lenz branding
- **Table of Contents**: Clickable navigation
- **Section Headers**: Blue gradient banners
- **Tables**: Professional styling with colored headers
- **Cost Highlights**: Green boxes for totals
- **Images**: Full-size with analysis details
- **Page Numbers**: Bottom of each page
- **Date/Time Stamps**: For record-keeping

---

## 9. TROUBLESHOOTING

### "No supported devices connected"
**Solution:** Connect your Android device via USB and ensure USB debugging is enabled

### "Camera not ready"
**Solution:** 
- Grant camera permissions in app settings
- Restart the app
- Check if another app is using the camera

### "Speech recognition not available"
**Solution:**
- Grant microphone permissions
- Check internet connection (some features require online access)
- Ensure device has Google speech services installed

### "Failed to generate report"
**Solution:**
- Check internet connection (AI services require internet)
- Verify API keys are configured in .env file
- Ensure at least one image with transcript exists
- Try generating report for single log first

### Report shows "AI Analysis in Progress" placeholders
**Solution:**
- Wait longer - report generation can take 30-60 seconds
- Check Groq API key is valid
- Ensure sufficient API credits/quota
- Try with fewer images initially

### App crashes during report generation
**Solution:**
- Close other apps to free memory
- Generate reports for smaller batches (1-3 logs at a time)
- Clear app cache
- Restart device

### Images not analyzing properly
**Solution:**
- Ensure good lighting when capturing
- Hold camera steady
- Capture images from appropriate distance (3-10 feet)
- Avoid blurry or overexposed photos

---

## 10. TIPS & BEST PRACTICES

### For Better Transcriptions:
✅ Speak clearly and naturally
✅ Use complete sentences
✅ Include specific measurements
✅ Mention locations explicitly
✅ State severity levels
✅ Pause between major points
✅ Work in quiet environments when possible

### For Better Image Analysis:
✅ Capture in good, natural lighting
✅ Fill frame with the issue/area
✅ Include context (surrounding area)
✅ Take multiple angles if complex
✅ Keep camera steady
✅ Avoid shadows obscuring defects
✅ Use zoom for distant issues

### For Comprehensive Reports:
✅ Create multiple log entries per inspection
✅ Cover all major areas systematically
✅ Include both defects and good conditions
✅ Mention all materials observed
✅ Document safety concerns explicitly
✅ Note environmental factors (moisture, ventilation)
✅ Record access limitations

### Project Organization:
✅ Clear old logs before new project
✅ Use consistent terminology
✅ Document inspection date in transcript
✅ Mention property address
✅ Note client name if applicable
✅ Save generated PDFs to cloud storage

### Cost & Time Management:
✅ Review estimates before presenting
✅ Adjust for local market rates
✅ Consider seasonal factors
✅ Account for access challenges
✅ Include contingency buffer
✅ Verify contractor availability

### Professional Presentation:
✅ Review PDF before sharing
✅ Add inspector credentials if needed
✅ Include contact information
✅ Attach supporting photos separately if needed
✅ Explain AI-generated content to clients
✅ Keep original logs as backup

---

## QUICK START CHECKLIST

- [ ] Launch app and complete splash screen
- [ ] Grant camera and microphone permissions
- [ ] Navigate to Record tab
- [ ] Tap "START LOGGING"
- [ ] Speak your observations clearly
- [ ] Tap "STOP LOGGING" to capture photo
- [ ] Repeat for all inspection points
- [ ] Navigate to Logs tab
- [ ] Tap green "Generate Report" button
- [ ] Choose Gemini for image analysis
- [ ] Wait for beautiful animated progress
- [ ] Review generated PDF
- [ ] Share or save the report

---

## TECHNICAL SPECIFICATIONS

### AI Models Used:
- **Gemini 2.5 Flash**: Image analysis, defect detection
- **Groq llama-3.3-70b**: Report generation, text analysis
- **OpenAI GPT-4o**: Optional alternative for both

### API Configuration:
Required environment variables in `.env` file:
```
GEMINI_API_KEY=your_gemini_api_key
GROQ_API_KEY=your_groq_api_key
OPENAI_API_KEY=your_openai_api_key (optional)
```

### System Requirements:
- Android 7.0 (API 24) or higher
- Camera with autofocus
- Microphone
- Internet connection
- Minimum 2GB RAM recommended
- 100MB free storage

### Performance:
- Image analysis: 5-10 seconds per image (parallel)
- Report generation: 15-30 seconds
- PDF creation: 5-10 seconds
- Total time: ~30-60 seconds for complete report

---

## SUPPORT & FEEDBACK

For technical support, feature requests, or bug reports:
- Email: support@sitelenz.com
- GitHub: github.com/ShashidharM0118/site_lenz
- Documentation: docs.sitelenz.com

---

**Version**: 1.0.0  
**Last Updated**: December 2025  
**Platform**: Android  
**Developer**: Shashidhar M  

---

© 2025 Site Lenz. All rights reserved.
AI-Powered Building Inspection Technology.
