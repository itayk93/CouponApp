# CouponManagerApp - Project Structure

## 📁 Directory Organization

### `/CouponManagerApp/` - Main iOS App
Contains all Swift source files for the main iOS application.

### `/CouponWidgetExtension/` - iOS Widget Extension  
Contains Swift files for the iOS widget functionality.

### `/Documentation/` - Project Documentation
- Setup guides and instructions
- API documentation
- Widget configuration instructions
- Notification system documentation

### `/Database/` - Database Scripts
- SQL migration files
- Database setup scripts
- RLS (Row Level Security) configurations
- Function definitions

### `/Scripts/` - Utility Scripts
- TypeScript/JavaScript utilities
- HTML tools and helpers
- Build scripts

### `/supabase/` - Supabase Functions
Contains Supabase Edge Functions (serverless functions).

### `/.github/` - GitHub Actions
Automated workflows and CI/CD configurations.

## 🔐 Security Configuration

### Configuration Files
- `Config.xcconfig` - Contains actual API keys (NEVER commit this)
- `Config.xcconfig.example` - Template for other developers
- `Secrets.swift` - Secure configuration manager that reads from bundle

### Protected Data
All sensitive information is now managed through:
1. **Config.xcconfig** - Excluded from Git
2. **GitHub Secrets** - For CI/CD workflows  
3. **Bundle Configuration** - Runtime loading of secrets

### API Keys Secured
- ✅ Main Supabase URL and anon key
- ✅ Notifications Supabase URL and anon key  
- ✅ OpenAI API key
- ✅ Python server URL
- ✅ GitHub workflow secrets

## 🚀 Setup Instructions

1. Copy `Config.xcconfig.example` to `Config.xcconfig`
2. Fill in your actual API keys in `Config.xcconfig`
3. Configure your Xcode project to use the xcconfig file
4. Set up GitHub repository secrets for CI/CD

**Important**: Never commit `Config.xcconfig` to version control!