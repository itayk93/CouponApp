# Repository Guidelines

These guidelines help contributors work efficiently on CouponManagerApp (Swift/iOS with a Widget extension and Supabase backend).

## Project Structure & Module Organization
- `CouponManagerApp/`: Main iOS app (Swift/SwiftUI).
- `CouponWidgetExtension/`: Widget extension code.
- `Database/`: SQL migrations, RLS policies, helper functions.
- `Documentation/`: Setup guides and architecture notes.
- `Services/`, `ViewModels/`, `Views/`, `Models/`, `Shared/`, `Utils/`, `Extensions/`: App modules by responsibility.
- `supabase/`: Edge functions (serverless) code.
- `Scripts/`: Utilities (e.g., HTML/TS helpers).

## Build, Test, and Development Commands
- Open in Xcode: `open CouponManagerApp.xcodeproj` (preferred for run/debug).
- CLI build (Simulator): `xcodebuild -scheme CouponManagerApp -destination 'platform=iOS Simulator,name=iPhone 15' build`.
- CLI tests (if test target exists): `xcodebuild -scheme CouponManagerApp -destination 'platform=iOS Simulator,name=iPhone 15' test`.
- List schemes: `xcodebuild -list -project CouponManagerApp.xcodeproj`.

## Coding Style & Naming Conventions
- Swift style: 2-space indentation, trailing commas allowed, prefer `let`, early returns.
- Naming: Types `PascalCase`, methods/properties `camelCase`.
- File per main type. UI: `SomethingView.swift`; state: `SomethingViewModel.swift`; infra: `SomethingService.swift`.
- Keep SwiftUI views small and composable; side effects live in ViewModels/Services.

## Testing Guidelines
- Framework: XCTest. Place tests under an `XCTest` target (e.g., `CouponManagerAppTests`).
- Names: `FeatureNameTests.swift`; methods `test_doesWhat_whenGivenInput`.
- Focus: pure logic in `Services/` and `ViewModels/`; use DI to mock network/storage.
- Run: Xcode Test action or CLI `xcodebuild ... test`. Aim for meaningful coverage over arbitrary %.

## Commit & Pull Request Guidelines
- Commits: imperative mood, concise subject (<= 50 chars), optional body for context.
  - Examples: `Add QuickUsageView model binding`, `Fix RLS policy for widget`.
- PRs: clear description, linked issues, steps to test, relevant screenshots (UI), and notes on config/DB changes.

### After Adding a New Feature
Run the following Git commands and use a clear, English commit message that summarizes the change:

```
git add .
git commit -m "telegr"   # replace with a meaningful English message
git push origin main
```

## Security & Configuration Tips
- Never commit real secrets. Use `Config.xcconfig` locally (templated by `Config.xcconfig.example`).
- Do not commit `Secrets.swift` with live keys; load from bundle/xcconfig.
- Use GitHub Secrets for CI; `.env.example` documents required env for scripts.

## Git Hooks: Pre-commit Secret/Artifacts Guard
- Purpose: blocks accidental commits of secrets and build artifacts.
- Installed script: `Scripts/pre-commit.sh`.
- Blocks:
  - Non-example `.xcconfig` files (only commit `Config.xcconfig.example`).
  - Build artifacts: `build/`, `*/build/`, `.xcarchive`, `.ipa`, `.app`.
  - Added lines matching common secret patterns (examples):
    - OpenAI keys `sk-...`, GitHub tokens `ghp_...`, AWS `AKIA...`/`aws_secret_access_key`.
    - Private keys (`-----BEGIN ... PRIVATE KEY-----`, `BEGIN OPENSSH PRIVATE KEY`).
    - Bearer tokens, JWT-like `SUPABASE_ANON_KEY` values, hardcoded passwords.
- Install or update locally:
  - `cp Scripts/pre-commit.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`
- Bypass in emergencies: append `--no-verify` to `git commit` (avoid unless necessary).

### Secret Hygiene Checklist
- Keep live credentials only in `Config.xcconfig` (ignored) or environment variables.
- Use placeholders in committed files and docs; never real credentials.
- Ensure `build/` is ignored and never committed.

## Language Policy
- All code comments, docstrings, and TODOs must be written in English only.
- Commit messages, PR titles, and PR descriptions must also be in English.
- The app UI and some project docs may be in Hebrew, but all in-code and VCS text should remain English for consistency and collaboration.
