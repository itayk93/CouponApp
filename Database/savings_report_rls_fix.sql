-- RLS Fix for Savings Report (על מה חסכת) 
-- This ensures all necessary data for savings calculations is accessible

-- ==================================================
-- IMPORTANT NOTES:
-- ==================================================
-- 1. This will NOT remove existing RLS policies
-- 2. It adds additional policies specifically for savings data access  
-- 3. Run each section separately and test after each one
-- 4. If you get permission errors, you might need to run as superuser

-- ==================================================
-- 1. ENSURE COUPON TABLE RLS ALLOWS ALL NECESSARY FIELDS
-- ==================================================

-- Drop and recreate the main coupon select policy to ensure all fields are accessible
DROP POLICY IF EXISTS "coupon_select_own" ON coupon;

-- Create a comprehensive policy that allows access to ALL coupon fields
CREATE POLICY "coupon_select_own" ON coupon
    FOR SELECT
    USING (auth.uid()::text = user_id::text);

-- Add policy for aggregate queries (sometimes needed for complex queries)
DROP POLICY IF EXISTS "coupon_select_aggregate" ON coupon;
CREATE POLICY "coupon_select_aggregate" ON coupon
    FOR SELECT
    USING (auth.uid()::text = user_id::text);

-- ==================================================
-- 2. ENSURE DATE FUNCTIONS WORK WITH RLS
-- ==================================================

-- Sometimes date filtering in RLS can cause issues
-- This policy specifically allows date-based filtering
DROP POLICY IF EXISTS "coupon_select_date_filtered" ON coupon;
CREATE POLICY "coupon_select_date_filtered" ON coupon
    FOR SELECT
    USING (
        auth.uid()::text = user_id::text 
        AND date_added IS NOT NULL
    );

-- ==================================================
-- 3. ENSURE CALCULATIONS CAN ACCESS ALL REQUIRED FIELDS
-- ==================================================

-- Policy that explicitly allows access to savings calculation fields
DROP POLICY IF EXISTS "coupon_select_savings_fields" ON coupon;
CREATE POLICY "coupon_select_savings_fields" ON coupon
    FOR SELECT
    USING (
        auth.uid()::text = user_id::text
        AND (
            value IS NOT NULL 
            OR cost IS NOT NULL 
            OR used_value IS NOT NULL
            OR company IS NOT NULL
        )
    );

-- ==================================================
-- 4. ADD POLICY FOR COMPANY GROUPING
-- ==================================================

-- Sometimes GROUP BY queries need explicit policies
DROP POLICY IF EXISTS "coupon_select_company_group" ON coupon;
CREATE POLICY "coupon_select_company_group" ON coupon
    FOR SELECT
    USING (
        auth.uid()::text = user_id::text
        AND company IS NOT NULL
    );

-- ==================================================
-- 5. ENSURE BOOLEAN FIELDS ARE ACCESSIBLE
-- ==================================================

-- Policy for boolean field filtering (is_for_sale, exclude_saving, etc.)
DROP POLICY IF EXISTS "coupon_select_boolean_filters" ON coupon;
CREATE POLICY "coupon_select_boolean_filters" ON coupon
    FOR SELECT
    USING (
        auth.uid()::text = user_id::text
        AND (
            is_for_sale IS NOT NULL
            OR exclude_saving IS NOT NULL
            OR is_available IS NOT NULL
            OR status IS NOT NULL
        )
    );

-- ==================================================
-- 6. REFRESH RLS CACHE (OPTIONAL)
-- ==================================================

-- Sometimes RLS policies need to be refreshed
-- This is optional but can help if policies aren't taking effect immediately
-- SELECT pg_reload_conf(); -- Removed - requires superuser permissions

-- ==================================================
-- 7. GRANT NECESSARY PERMISSIONS
-- ==================================================

-- Ensure authenticated users have the necessary permissions
GRANT SELECT ON coupon TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- ==================================================
-- 8. TEST THE POLICIES
-- ==================================================

-- Test query to verify the policies work
-- Run this after applying the policies above
-- It should return your coupons with all necessary fields

-- SELECT 
--     company,
--     COUNT(*) as total_coupons,
--     SUM(CASE 
--         WHEN cost > 0 THEN GREATEST(0, value - cost)
--         ELSE used_value
--     END) as total_savings
-- FROM coupon 
-- WHERE user_id = auth.uid()::int
--     AND is_for_sale = false 
--     AND exclude_saving = false
-- GROUP BY company
-- ORDER BY total_savings DESC;

-- ==================================================
-- 9. ALTERNATIVE: SIMPLIFIED SINGLE POLICY (IF ABOVE DOESN'T WORK)
-- ==================================================

-- If the multiple policies above cause conflicts, 
-- you can try this single comprehensive policy instead:
-- 
-- First, drop all coupon select policies:
-- DROP POLICY IF EXISTS "coupon_select_own" ON coupon;
-- DROP POLICY IF EXISTS "coupon_select_aggregate" ON coupon;
-- DROP POLICY IF EXISTS "coupon_select_date_filtered" ON coupon;
-- DROP POLICY IF EXISTS "coupon_select_savings_fields" ON coupon;
-- DROP POLICY IF EXISTS "coupon_select_company_group" ON coupon;
-- DROP POLICY IF EXISTS "coupon_select_boolean_filters" ON coupon;
-- DROP POLICY IF EXISTS "coupon_select_marketplace" ON coupon;
-- 
-- Then create this single policy:
-- CREATE POLICY "coupon_full_access_own" ON coupon
--     FOR SELECT
--     USING (
--         auth.uid()::text = user_id::text
--         OR (is_for_sale = true AND status = 'פעיל')
--     );

-- ==================================================
-- TROUBLESHOOTING NOTES:
-- ==================================================
-- 1. If you get "permission denied" errors, make sure you're running as a user with proper permissions
-- 2. If policies conflict, you might need to drop and recreate them
-- 3. The iOS app uses `fetchAllUserCoupons` which should work with `auth.uid()::text = user_id::text`
-- 4. Check that your JWT tokens are valid and contain the correct user ID
-- 5. Make sure the user_id field in your coupon table matches the auth.uid() value

-- ==================================================
-- EMERGENCY DISABLE RLS (USE ONLY IF NOTHING ELSE WORKS)
-- ==================================================
-- NEVER use this in production, but if you need to test without RLS:
-- ALTER TABLE coupon DISABLE ROW LEVEL SECURITY;
-- (Remember to re-enable it afterward with: ALTER TABLE coupon ENABLE ROW LEVEL SECURITY;)