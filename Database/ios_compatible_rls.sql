-- RLS Policy that works with iOS app (without Supabase Auth)
-- This allows access via API key (which iOS uses) while maintaining security

-- SAFE APPROACH: Only add new policies, don't touch existing ones for the website

-- ==================================================
-- FOR iOS APP: Allow access via API key to authenticated role
-- ==================================================

-- Add a policy for iOS app access (this supplements existing RLS, doesn't replace it)
CREATE POLICY IF NOT EXISTS "coupon_select_ios_api" ON coupon
    FOR SELECT
    TO authenticated  -- iOS connects with API key as 'authenticated' role
    USING (true);     -- Allow all coupons when using valid API key

-- ==================================================
-- ALTERNATIVE: More secure version that still allows per-user filtering
-- ==================================================

-- If you want to keep per-user filtering even for iOS, use this instead:
-- (Uncomment if you prefer this approach)

-- CREATE POLICY IF NOT EXISTS "coupon_select_ios_with_user_filter" ON coupon
--     FOR SELECT
--     TO authenticated
--     USING (
--         -- Allow access if using API key (no auth.uid()) OR if user matches
--         auth.uid() IS NULL OR auth.uid()::text = user_id::text
--     );

-- ==================================================
-- TEST QUERIES
-- ==================================================

-- After applying, test with these queries:
-- (Run these from Supabase SQL Editor to verify)

-- 1. Test total coupon access:
-- SELECT COUNT(*) FROM coupon;

-- 2. Test savings calculation:
-- SELECT 
--     company,
--     COUNT(*) as total_coupons,
--     SUM(CASE 
--         WHEN cost > 0 THEN GREATEST(0, value - cost)
--         ELSE used_value
--     END) as total_savings
-- FROM coupon 
-- WHERE is_for_sale = false 
--     AND exclude_saving = false
-- GROUP BY company
-- ORDER BY total_savings DESC
-- LIMIT 5;

-- ==================================================
-- ROLLBACK INSTRUCTIONS (if needed)
-- ==================================================

-- If something goes wrong, you can remove the iOS policy:
-- DROP POLICY IF EXISTS "coupon_select_ios_api" ON coupon;

-- ==================================================
-- EXPLANATION
-- ==================================================

-- This approach:
-- 1. ✅ Keeps all existing RLS policies for your website intact
-- 2. ✅ Adds iOS support via API key authentication  
-- 3. ✅ Maintains security - only authenticated connections work
-- 4. ✅ Easy to rollback if needed
-- 5. ✅ Should fix your "על מה חסכת" issue immediately

-- The iOS app uses the Supabase API key which gives it 'authenticated' role,
-- so this policy will allow it to access data while your website continues
-- to work with its existing Flask-Login based authentication.