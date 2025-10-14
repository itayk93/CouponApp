-- Temporary RLS Fix for Widget
-- Run this in Supabase SQL Editor to allow widget to work

-- ==================================================
-- OPTION 1: DISABLE RLS TEMPORARILY (QUICK FIX)
-- ==================================================
ALTER TABLE coupon DISABLE ROW LEVEL SECURITY;
ALTER TABLE companies DISABLE ROW LEVEL SECURITY;

-- ==================================================
-- OPTION 2: ADD PERMISSIVE POLICIES FOR ANON ROLE
-- ==================================================
-- Uncomment this section if you prefer to keep RLS enabled

/*
-- Re-enable RLS
ALTER TABLE coupon ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "coupon_select_own" ON coupon;
DROP POLICY IF EXISTS "coupon_select_marketplace" ON coupon;
DROP POLICY IF EXISTS "companies_select_all" ON companies;

-- Add permissive policies for anon role
CREATE POLICY "coupon_select_anon_widget" ON coupon
    FOR SELECT TO anon USING (true);

CREATE POLICY "companies_select_anon_widget" ON companies
    FOR SELECT TO anon USING (true);
*/

-- ==================================================
-- TEST THE FIX
-- ==================================================
-- After running the fix, test these queries:

-- 1. Test coupon access
SELECT COUNT(*) as total_coupons FROM coupon;

-- 2. Test companies access
SELECT COUNT(*) as total_companies FROM companies;

-- 3. Test specific user's coupons (replace 1 with actual user ID)
SELECT COUNT(*) as user_coupons FROM coupon WHERE user_id = 1;

-- 4. Test the RPC function (replace 1 with actual user ID)
SELECT * FROM get_widget_coupons(1) LIMIT 5;

-- ==================================================
-- NOTES:
-- ==================================================
-- 1. Option 1 (disable RLS) is simpler but less secure
-- 2. Option 2 (permissive policies) keeps RLS structure but allows anon access
-- 3. For production, implement proper JWT authentication
-- 4. The widget should eventually use Supabase Auth instead of anon key
