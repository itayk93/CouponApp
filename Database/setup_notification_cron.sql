-- Enable the pg_cron extension (if not already enabled)
-- This needs to be run by a superuser
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule daily notification check
-- This will run every day at the time specified in notification_settings
-- For now, let's set it to run every day at 20:14 (8:14 PM)

-- First, remove any existing cron job for notifications
SELECT cron.unschedule('daily-coupon-notifications');

-- Schedule the new cron job
SELECT cron.schedule(
    'daily-coupon-notifications',           -- job name
    '14 20 * * *',                         -- cron expression (20:14 daily)
    'SELECT net.http_post(
        url := ''https://your-supabase-project.supabase.co/functions/v1/send-daily-notifications'',
        headers := ''{"Authorization": "Bearer YOUR_ANON_KEY", "Content-Type": "application/json"}'',
        body := ''{}''
    );'
);

-- Alternative: Schedule to run every hour and check the time in the function
-- This allows for dynamic scheduling based on admin settings
SELECT cron.schedule(
    'hourly-notification-check',
    '0 * * * *',  -- Every hour at minute 0
    'SELECT net.http_post(
        url := ''https://your-supabase-project.supabase.co/functions/v1/send-daily-notifications'',
        headers := ''{"Authorization": "Bearer YOUR_ANON_KEY", "Content-Type": "application/json"}'',
        body := ''{"check_time": true}''
    );'
);

-- Check scheduled jobs
SELECT * FROM cron.job;

/*
IMPORTANT SETUP INSTRUCTIONS:

1. Replace 'your-supabase-project' with your actual Supabase project URL
2. Replace 'YOUR_ANON_KEY' with your actual Supabase anon key
3. Run this in your Supabase SQL editor
4. Make sure pg_cron extension is enabled (contact Supabase support if needed)

The cron job will:
- Run every day at 20:14 (or the time you set)
- Call the Edge Function we created
- The function will check all users and send notifications for expiring coupons
*/