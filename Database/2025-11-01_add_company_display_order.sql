-- Migration: Add manual ordering for company screen
-- Purpose: Adds company_display_order to coupon, index, and optional backfill.

BEGIN;

-- 1) Column (idempotent)
ALTER TABLE public.coupon
ADD COLUMN IF NOT EXISTS company_display_order integer;

-- 2) Index to optimize queries filtering by user/company/order (idempotent)
CREATE INDEX IF NOT EXISTS idx_coupon_company_display_order
  ON public.coupon (user_id, company, company_display_order);

-- 3) Optional backfill A: initialize order per user+company, newest first
-- Comment out this block if you do not want automatic initialization.
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, company
      ORDER BY date_added DESC
    ) AS rn
  FROM public.coupon
  WHERE is_for_sale = false
)
UPDATE public.coupon c
SET company_display_order = r.rn
FROM ranked r
WHERE c.id = r.id
  AND c.company_display_order IS NULL;

COMMIT;

-- RLS (only if required). Ensure users can update their own rows.
-- NOTE: Enable and policy definitions are safe to run if already present.
-- Uncomment if your project enforces RLS and lacks an update policy.
--
-- ALTER TABLE public.coupon ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY IF NOT EXISTS "Users update own coupons"
-- ON public.coupon
-- FOR UPDATE
-- USING (auth.uid() = user_id)
-- WITH CHECK (auth.uid() = user_id);

