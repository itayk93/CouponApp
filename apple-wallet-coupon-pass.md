---
name: apple-wallet-coupon-pass
description: Apple Wallet passes with balance updates and invalidation
---

# Plan

Add Apple Wallet passes for coupons with a remaining-balance display, Code128 barcode, visible coupon code text, and automatic invalidation when a coupon is fully used or manually marked used. The plan integrates with the existing Supabase tables (`coupon`, `coupon_usage`, `coupon_transaction`, `companies`, `users`) and adds pass metadata columns to `coupon` plus a device registration table for PassKit updates.

## Requirements
- Apple Wallet pass per coupon showing remaining balance (value - used_value) at time of use.
- Barcode format `PKBarcodeFormatCode128` with the coupon code as `message` and `altText`.
- Coupon code displayed as a visible text field in the pass.
- Pass auto-voids when `used_value >= value` and also when user taps “mark used” in the app.
- Pass metadata stored as new columns on `coupon` (per request); device registrations stored separately.

## Scope
- In: PassKit Web Service endpoints, pkpass generation, APNs pass updates, iOS UI + service integration, DB columns in `coupon`, new table for device registrations, hook into usage updates.
- Out: Advanced pass visual design beyond a clean, branded baseline (phase 1 keeps it simple).

## Files and entry points
- `CouponManagerApp/CouponDetailView.swift` (Add to Wallet button, open existing pass, invalid state UI).
- `CouponManagerApp/Services/WalletPassService.swift` (new; download, add, open pass).
- `CouponManagerApp/CouponAPIClient.swift` (call pass endpoints after usage/mark-used actions).
- `supabase/functions/` (new Edge Function: PassKit Web Service + pass generation).
- `Database/` (migration for coupon pass columns + device registrations table).

## Data model / API changes
- **Existing tables used:**
  - `coupon`: `id`, `code`, `value`, `used_value`, `status`, `is_available`, `company`, `company_id`, `user_id`, etc.
  - `coupon_usage`: `coupon_id`, `used_amount`, `action`, `details`, `timestamp`.
  - `coupon_transaction`: optional external usage stream.
- **New columns on `coupon` (names to finalize in implementation):**
  - `wallet_pass_serial` (text)
  - `wallet_pass_auth_token` (text)
  - `wallet_pass_status` (text: active/voided)
  - `wallet_pass_last_balance` (double precision)
  - `wallet_pass_last_generated_at` (timestamptz)
  - `wallet_pass_updated_at` (timestamptz)
  - `wallet_pass_invalidated_at` (timestamptz)
  - SQL migration query will be provided during implementation.
- **New table for PassKit device registrations:**
  - `wallet_pass_registrations`: `serial_number`, `device_library_id`, `push_token`, `created_at`, `updated_at`.
- **PassKit Web Service endpoints (Edge Function):**
  - `POST /v1/devices/{deviceLibraryIdentifier}/registrations/{passTypeIdentifier}/{serialNumber}`
  - `DELETE /v1/devices/{deviceLibraryIdentifier}/registrations/{passTypeIdentifier}/{serialNumber}`
  - `GET /v1/devices/{deviceLibraryIdentifier}/registrations/{passTypeIdentifier}?passesUpdatedSince=...`
  - `GET /v1/passes/{passTypeIdentifier}/{serialNumber}`
  - `POST /v1/log`

## Action items
[ ] Confirm final column names for `coupon` and create a SQL migration (share the SQL during implementation).
[ ] Set up Apple Pass Type ID + Pass certificate + Pass Push certificate; store in Supabase Secrets.
[ ] Define pass.json template (coupon/storeCard style):
- Remaining balance field: `value - used_value`, clamped to `>= 0`.
- Visible coupon code field.
- Barcode: Code128, `message` = coupon code, `altText` = coupon code, `messageEncoding = "iso-8859-1"`.
- `relevantDate` or `expirationDate` when available.
- `voided = true` when invalid.
[ ] Implement Edge Function for PassKit Web Service and pkpass generation (including signing and manifest).
[ ] Implement device registration storage in `wallet_pass_registrations` and support `passesUpdatedSince` using `wallet_pass_updated_at`.
[ ] Implement APNs push updates for pass changes (balance updates and voiding).
[ ] Update usage flows:
- After `updateCouponUsage`, recalc balance; if `used_value >= value`, set `status/is_available` and void pass, else update pass balance.
- After `mark_coupon_as_used_rpc`, force pass voiding and push update.
[ ] Add `WalletPassService` in iOS to download/preview/add pass and open existing pass.
[ ] Add “Add to Apple Wallet” button (Apple-provided asset) to `CouponDetailView` with loading/error states.
[ ] Add guardrails: hide button when `code` is empty/invalid for Code128 or when pass is voided.

## Testing and validation
- Device test: generate and add pass; verify balance and barcode display.
- Update usage: confirm pass balance updates; confirm auto-void on `used_value >= value`.
- Manual “mark used”: confirm pass voided in Wallet.
- Barcode scan test (Code128 + altText visible).
- Security: ensure only owner can fetch pass and register devices.

## Risks and edge cases
- Coupon codes with unsupported Code128 characters require validation/fallback.
- Rounding/precision when `used_value` approaches `value`.
- Push certificate issues or missing APNs configuration prevents updates.
- External usage via `coupon_transaction` needs a trigger or explicit hook to update pass status.

## Open questions
- None (ready to implement with agreed behavior).
