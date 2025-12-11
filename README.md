# Site Lenz - AI-Powered Building Inspection App

## TABLE OF CONTENTS

1. Overview
2. Features
3. Prerequisites
4. Installation & Setup
5. Configuration
6. Building the Project
7. Running the App
8. App Usage Guide
9. Troubleshooting
10. Project Structure

---

## 1. OVERVIEW

**Site Lenz** is an AI-powered Flutter mobile application for professional building inspections. It combines real-time speech-to-text transcription, camera capture, and AI analysis to generate comprehensive PDF inspection reports.

### Technology Stack:
- **Framework**: Flutter 3.10.1+
- **Language**: Dart
- **AI Services**: Gemini 2.5 Flash, Groq llama-3.3-70b, OpenAI GPT-4o
- **Platform**: Android (7.0+)

---

## 2. FEATURES

- ✅ **Real-Time Speech Transcription** - Voice-to-text conversion during inspections
- ✅ **AI Image Analysis** - Defect detection, material identification, condition assessment
- ✅ **Professional PDF Reports** - 9-section comprehensive inspection reports
- ✅ **AI Chat Assistant** - Multi-model AI chatbot (Gemini, Groq, OpenAI)
- ✅ **Modern UI** - Purple/Green theme with animated splash screen
- ✅ **Parallel Processing** - Simultaneous image analysis for faster results

---

## 3. PREREQUISITES

### Required Software:
- **Flutter SDK**: 3.10.1 or higher
- **Dart**: 2.19.0 or higher
- **Android Studio**: Latest version
- **Java JDK**: 21 (OpenJDK)
- **Git**: For version control

### Android Device Requirements:
- Android 7.0 (API level 24) or higher
- USB debugging enabled
- Camera and microphone hardware
- Minimum 2GB RAM
- 100MB free storage

### API Keys Required:
- **Gemini API Key** - Get from [Google AI Studio](https://makersuite.google.com/app/apikey)
- **Groq API Key** - Get from [Groq Console](https://console.groq.com/)
- **OpenAI API Key** (Optional) - Get from [OpenAI Platform](https://platform.openai.com/)

---

## 4. INSTALLATION & SETUP

### Step 1: Clone the Repository
```bash
git clone https://github.com/ShashidharM0118/site_lenz.git
cd site_lenz
```

### Step 2: Install Flutter Dependencies
```bash
flutter pub get
```

### Step 3: Verify Flutter Installation
```bash
flutter doctor
```
Resolve any issues reported by Flutter Doctor.

### Step 4: Set Up Java Environment
```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
```

For permanent setup, add to `~/.bashrc` or `~/.zshrc`:
```bash
echo 'export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64' >> ~/.bashrc
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

---

## 5. CONFIGURATION

### Create Environment File
Create a `.env` file in the project root directory:
```bash
touch .env
```

### Add API Keys
Edit `.env` and add your API keys:
```env
GEMINI_API_KEY=your_gemini_api_key_here
GROQ_API_KEY=your_groq_api_key_here
OPENAI_API_KEY=your_openai_api_key_here
```

**Note**: Never commit the `.env` file to version control. It's already in `.gitignore`.

### Update Dependencies
If you modify `pubspec.yaml`, run:
```bash
flutter pub get
```

---

## 6. BUILDING THE PROJECT

### Build for Android Debug
```bash
flutter build apk --debug
```

The APK will be located at:
```
build/app/outputs/flutter-apk/app-debug.apk
```

### Build for Android Release
```bash
flutter build apk --release
```

The release APK will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Build App Bundle (for Google Play)
```bash
flutter build appbundle --release
```

The bundle will be located at:
```
build/app/outputs/bundle/release/app-release.aab
```

### Clean Build (if needed)
```bash
flutter clean
flutter pub get
flutter build apk
```

---

## 7. RUNNING THE APP

### Connect Android Device
1. Enable **Developer Options** on your Android device:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times

2. Enable **USB Debugging**:
   - Settings → Developer Options → USB Debugging

3. Connect device via USB cable

### Check Connected Devices
```bash
flutter devices
```

You should see your device listed (e.g., `LJPVD6QWNFOFXGQS`).

### Run the App
```bash
flutter run -d <device_id>
```

Or with Java environment (all in one command):
```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 && export PATH=$JAVA_HOME/bin:$PATH && cd /home/shashi/projects/site_lenz && flutter run -d LJPVD6QWNFOFXGQS
```

### Hot Reload During Development
While the app is running:
- Press `r` in terminal for hot reload
- Press `R` for hot restart
- Press `q` to quit

### Run in Release Mode
```bash
flutter run --release -d <device_id>
```

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

### Build Issues

**"Gradle build failed"**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk
```

**"Java version mismatch"**
```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
java -version  # Should show version 21
```

**"No devices connected"**
- Enable USB debugging on Android device
- Use `flutter devices` to verify connection
- Try different USB cable/port
- Install Android platform tools: `sudo apt install android-tools-adb`

### Runtime Issues

**"Camera not ready"**
- Grant camera permissions in app settings
- Restart the app

**"Speech recognition not available"**
- Grant microphone permissions
- Check internet connection
- Ensure Google speech services installed

**"Failed to generate report"**
- Verify API keys in `.env` file
- Check internet connection
- Ensure sufficient API credits/quota

**"App crashes during report generation"**
- Close other apps to free memory
- Try smaller batches (1-3 logs)
- Clear app cache and restart device

### Dependency Issues

**"Package not found"**
```bash
flutter pub cache repair
flutter pub get
```

**"Version conflicts"**
```bash
flutter pub upgrade
```

---

## 10. PROJECT STRUCTURE

```
site_lenz/
├── android/                    # Android-specific configuration
│   ├── app/
│   │   ├── src/main/
│   │   └── build.gradle.kts
│   └── build.gradle.kts
├── lib/                        # Main Dart source code
│   ├── main.dart              # App entry point
│   ├── theme/
│   │   └── app_theme.dart     # Purple/Green theme system
│   ├── screens/
│   │   ├── splash_screen.dart # Animated splash
│   │   ├── home_screen.dart   # Recording screen
│   │   ├── logs_screen.dart   # Logs management
│   │   └── chatbot_screen.dart # AI chat interface
│   └── services/
│       ├── gemini_service.dart           # Gemini AI integration
│       ├── groq_service.dart             # Groq AI integration
│       ├── openai_service.dart           # OpenAI integration
│       ├── image_analysis_service.dart   # Image processing
│       ├── report_generation_service.dart # PDF generation
│       ├── speech_service.dart           # Speech-to-text
│       └── log_storage_service.dart      # Local storage
├── build/                      # Build outputs (gitignored)
├── .env                        # API keys (gitignored)
├── pubspec.yaml               # Dependencies
├── analysis_options.yaml      # Linter configuration
└── README.md                  # This file
```

### Key Files

**`lib/main.dart`**
- App initialization
- Theme application
- Navigation setup

**`lib/services/report_generation_service.dart`**
- Parallel image analysis with Future.wait()
- Enhanced AI prompts for comprehensive reports
- PDF generation with professional formatting
- Report validation before PDF creation

**`lib/theme/app_theme.dart`**
- Material Design 3 theme
- Purple (#5F259F) and Green (#B8E600) colors
- Custom button and card widgets

---

## DEVELOPMENT COMMANDS

```bash
# Install dependencies
flutter pub get

# Run app on connected device
flutter run -d <device_id>

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Clean build artifacts
flutter clean

# Analyze code
flutter analyze

# Format code
flutter format lib/

# Check for updates
flutter pub outdated

# Upgrade dependencies
flutter pub upgrade
```

---

## CONTRIBUTING

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/your-feature`
5. Submit a pull request

---

## LICENSE

This project is licensed under the MIT License.

---

## CONTACT

**Developer**: Shashidhar M  
**GitHub**: [@ShashidharM0118](https://github.com/ShashidharM0118)  
**Repository**: [site_lenz](https://github.com/ShashidharM0118/site_lenz)

---

**Version**: 1.0.0  
**Last Updated**: December 2025  
**Platform**: Android (7.0+)  
**Framework**: Flutter 3.10.1+

---

© 2025 Site Lenz. All rights reserved.
