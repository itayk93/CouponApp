Share Extension: Import Image to Quick Add

Goal
- Allow sharing an image from Photos/other apps directly into CouponManagerApp.
- The app opens on the “Add coupon from image” flow and auto‑loads the shared image, then analyzes it (same as the normal flow).

Overview
- Create a Share Extension target that accepts images.
- Copy the shared image into the App Group container.
- Open the container app via deep link: `couponmanager://import-image?file=<uuid>.jpg`.
- In the app, listen for the deep link, load the image from the App Group container, and show the image analysis screen.

Prerequisites
- App Group already used by the widget: `group.com.itaykarkason.CouponManagerApp`.

1) Create the Share Extension target
- In Xcode: File → New → Target → iOS → Share Extension.
- Product name: `CouponShareExtension`.
- Language: Swift. Uncheck “Include UI” (we don’t need a compose UI).
- Finish and activate the new scheme if prompted.

2) Capabilities
- For the Share Extension target, enable “App Groups” and add `group.com.itaykarkason.CouponManagerApp`.
- For the main app target, ensure the same App Group is enabled (already in use by the widget).

3) Info.plist (extension)
Add or verify the following keys:

```
NSExtension (Dictionary)
  NSExtensionPointIdentifier = com.apple.share-services
  NSExtensionAttributes (Dictionary)
    NSExtensionActivationRule = TRUEPREDICATE
    NSExtensionFileProviderSupportsCloudDocs = YES
  NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).ShareViewController
```

To limit to images only, add the activation rule:

```
NSExtensionActivationRule (Dictionary)
  NSExtensionActivationSupportsImageWithMaxCount = 1
```

4) URL scheme for deep linking
- Main app already supports custom scheme `couponmanager` in `Info.plist`.
- Deep link you’ll use: `couponmanager://import-image?file=<fileName>`.

5) ShareViewController implementation
- Replace the template controller with a simple forwarder that:
  - Reads the first `NSItemProvider` of type image.
  - Writes the image data into the App Group folder: `ShareInbox/<uuid>.jpg`.
  - Calls `extensionContext?.open(URL(string: "couponmanager://import-image?file=<uuid>.jpg")!)`.
  - Completes the request.

See `Extensions/ShareExtensionSample/ShareViewController.swift` for a full example.

6) App side handling (already added)
- `CouponManagerAppApp.handleDeepLink` listens for the `import-image` host.
- Posts `NavigateToAddFromImage` with the file name.
- `CouponsListView` loads the image via `SharedImageInbox`, opens `AddCouponFromImageView`, and clears the temp file.

7) Test
- Build & run the app once (to install).
- From Photos, pick an image → Share → More → enable “CouponManagerApp” share extension → tap it.
- App should open on “הוספת קופון מתמונה” with the image pre‑loaded.

Notes
- Files are stored under the app group container in `ShareInbox/`. They are removed after loading.
- If you want to support multiple images, extend the deep link to pass an array or use a JSON descriptor in the container. The current flow takes the first image only.

