# CouponManagerApp — Quick Usage with GPT-4o-mini

This adds a "Quick Usage Report" screen that analyzes pasted text to suggest which of your active coupons were used, using OpenAI gpt-4o-mini.

## Files added
- Models/CouponSuggestion.swift
- Services/AIQuickUsageService.swift
- ViewModels/QuickUsageViewModel.swift
- Views/QuickUsageView.swift

## Configure OpenAI API key
Provide the key in one of the following:
- Environment variable: OPENAI_API_KEY
- Info.plist via xcconfig key `OPENAI_API_KEY` (Config.xcconfig -> Info.plist)

## Wiring into your app
Instantiate QuickUsageView and provide two closures:
- loadActiveCoupons: () -> [Coupon]
- reportUsage: (_ couponIds: [String]) async throws -> Void

Example:
```
QuickUsageView(
  reportUsage: { ids in /* call your usage reporting flow */ },
  loadActiveCoupons: { /* return current active coupons */ }
)
```

The AI service uses chat/completions with response_format json_object and model gpt-4o-mini only.
# 🎟️ CouponApp

A modern iOS application for managing and organizing digital coupons with advanced features including AI-powered coupon extraction, widgets, and smart notifications.

## ✨ Features

- 📱 **Native iOS App** - Built with SwiftUI for optimal performance
- 🧠 **AI-Powered Extraction** - Automatically extract coupon details from text and images using GPT-4
- 🔐 **Secure Authentication** - Face ID/Touch ID support with encrypted storage
- 📊 **Smart Analytics** - Track savings and usage patterns
- 🔔 **Intelligent Notifications** - Get notified before coupons expire
- 🎯 **iOS Widgets** - Quick access to your coupons from home screen
- 🏢 **Company Management** - Organize coupons by brands and stores
- 💾 **Cloud Sync** - Supabase backend for seamless data synchronization

## 🏗️ Project Structure

```
CouponManagerApp/
├── CouponManagerApp/          # Main iOS application source code
├── CouponWidgetExtension/     # iOS widget extension
├── Documentation/             # Project documentation and setup guides
├── Database/                  # SQL scripts and database migrations
├── Scripts/                   # Utility scripts and tools
├── supabase/                  # Supabase Edge Functions
├── .github/workflows/         # GitHub Actions for CI/CD
├── Config.xcconfig.example    # Configuration template
└── README.md                  # This file
```

## 🚀 Quick Start

### Prerequisites
- Xcode 15.0 or later
- iOS 16.0+ deployment target
- Required service accounts for database and AI processing

## 🔧 Configuration

The app uses a secure configuration system to protect API keys.

### Required Services
You'll need accounts and API keys for:
- **Database Service**: For data storage and synchronization
- **AI Service**: For intelligent text and image processing
- **Cloud Functions**: For automated notifications (optional)

See the example configuration file for the required format.

### GitHub Secrets (for CI/CD)
If using GitHub Actions, configure the required secrets for your services in your repository settings.

## 📱 Features Overview

### AI-Powered Coupon Extraction
- Extract coupon details from SMS messages
- Scan coupon images with OCR and AI analysis
- Automatic company and expiration date detection
- Support for multiple languages (Hebrew/English)

### Smart Organization
- Categorize by company/brand
- Filter by expiration date
- Track usage and savings
- Quick search and sort options

### Security & Privacy
- Face ID/Touch ID authentication
- Encrypted local storage
- Secure API key management
- Row-level security with Supabase

### iOS Integration
- Home screen widgets
- Share sheet integration
- Background app refresh for notifications
- Universal links support

## 🛠️ Development

### Architecture
- **Frontend**: SwiftUI + UIKit
- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **AI**: OpenAI GPT-4 Vision API
- **Authentication**: Supabase Auth with biometric support
- **Storage**: Encrypted local storage + cloud sync

### Key Components
- `CouponAPIClient` - Supabase integration
- `OpenAIClient` - AI-powered text/image analysis
- `EncryptionManager` - Secure data handling
- `NotificationManager` - Smart notifications
- `FaceIDManager` - Biometric authentication

## 📊 Database Schema

The app uses Supabase PostgreSQL with these main tables:
- `coupons` - Coupon data and metadata
- `companies` - Brand/store information
- `notification_settings` - User preferences
- Row-level security policies for data protection

## 🔔 Notifications

Automated notification system with:
- Daily coupon reminders
- Expiration warnings
- Monthly savings reports
- Configurable timing and preferences

## 🔒 Security

- Secure API key management
- Data encryption at rest and in transit
- Biometric authentication for app access
- Regular security audits and updates

---

Built with ❤️ using Swift, SwiftUI, and modern iOS development practices.