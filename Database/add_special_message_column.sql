-- Add a special_message column to coupon table
-- Stores an optional, user-defined note shown prominently in the iOS detail view

ALTER TABLE coupon
ADD COLUMN IF NOT EXISTS special_message TEXT;

COMMENT ON COLUMN coupon.special_message IS 'Optional prominent note to show in the iOS detail view.';

