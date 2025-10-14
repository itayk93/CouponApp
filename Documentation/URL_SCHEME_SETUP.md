# URL Scheme Setup for Widget Deep Linking

Since modern Xcode projects don't use separate Info.plist files, you need to configure the URL scheme through Xcode's project settings.

## Steps to Add URL Scheme:

### 1. Open Project Settings
1. Select your project in Xcode (top-level "CouponManagerApp")
2. Select the "CouponManagerApp" target (not the widget target)
3. Go to the "Info" tab

### 2. Add URL Types
1. Scroll down to "URL Types" section
2. Click the "+" button to add a new URL Type
3. Fill in the following:
   - **Identifier**: `com.couponmanager.deeplink`
   - **URL Schemes**: `couponmanager`
   - **Role**: Editor (default)

### 3. Verify Configuration
The configuration should look like this:
```
URL Types
├── URL Type 1
    ├── Identifier: com.couponmanager.deeplink
    ├── URL Schemes: couponmanager
    └── Role: Editor
```

### 4. Test Deep Linking
After configuration, the app will respond to URLs like:
- `couponmanager://company/שופרסל`
- `couponmanager://company/רמי לוי`

### Alternative: Manual Info.plist Edit
If you prefer to edit the Info.plist directly:
1. Find the Info.plist in your project navigator
2. Add this configuration:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.couponmanager.deeplink</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>couponmanager</string>
        </array>
    </dict>
</array>
```

## Important Notes:
- Only add this to the main app target, NOT the widget extension
- The widget extension has its own Info.plist in the CouponManagerWidget folder
- After adding the URL scheme, clean and rebuild the project