import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface User {
  id: number
  email: string
  first_name?: string
  last_name?: string
  push_token?: string
}

interface Coupon {
  id: number
  company: string
  description: string
  expiration_date: string
  user_id: number
  is_expired: boolean
  usage_count: number
  total_uses: number
}

interface GlobalSettings {
  daily_notification_hour: number
  daily_notification_minute: number
  monthly_notification_hour: number
  monthly_notification_minute: number
  expiration_day_hour: number
  expiration_day_minute: number
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    console.log('🚀 Starting daily notification check...')

    // Get global notification settings (we'll add this to your database)
    const { data: settingsData, error: settingsError } = await supabaseClient
      .from('notification_settings')
      .select('*')
      .limit(1)
      .single()

    if (settingsError) {
      console.log('⚠️ No global settings found, using defaults')
    }

    const settings: GlobalSettings = settingsData || {
      daily_notification_hour: 20,
      daily_notification_minute: 14,
      monthly_notification_hour: 10,
      monthly_notification_minute: 0,
      expiration_day_hour: 10,
      expiration_day_minute: 0
    }

    console.log('⚙️ Using notification settings:', settings)

    // Get all users with push tokens
    const { data: users, error: usersError } = await supabaseClient
      .from('users')
      .select('id, email, first_name, last_name, push_token')
      .not('push_token', 'is', null)

    if (usersError) {
      throw usersError
    }

    console.log(`👥 Found ${users?.length || 0} users with push tokens`)

    if (!users || users.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: 'No users with push tokens found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let notificationsSent = 0
    const currentDate = new Date()

    // Check each user's coupons
    for (const user of users) {
      console.log(`🔍 Checking coupons for user ${user.id} (${user.email})`)

      // Get user's coupons
      const { data: coupons, error: couponsError } = await supabaseClient
        .from('coupons')
        .select('*')
        .eq('user_id', user.id)
        .eq('is_expired', false)
        .not('expiration_date', 'is', null)

      if (couponsError) {
        console.error(`❌ Error fetching coupons for user ${user.id}:`, couponsError)
        continue
      }

      if (!coupons || coupons.length === 0) {
        console.log(`📭 No active coupons found for user ${user.id}`)
        continue
      }

      console.log(`📋 Found ${coupons.length} active coupons for user ${user.id}`)

      // Check expiring coupons
      const expiringCoupons = coupons.filter(coupon => {
        if (!coupon.expiration_date) return false
        
        const expirationDate = new Date(coupon.expiration_date)
        const timeDiff = expirationDate.getTime() - currentDate.getTime()
        const daysLeft = Math.ceil(timeDiff / (1000 * 3600 * 24))
        
        // Check if coupon is fully used
        const isFullyUsed = coupon.total_uses > 0 && coupon.usage_count >= coupon.total_uses
        
        // Send notification for coupons expiring in 1-7 days
        return daysLeft >= 1 && daysLeft <= 7 && !isFullyUsed
      })

      if (expiringCoupons.length > 0) {
        console.log(`⚠️ User ${user.id} has ${expiringCoupons.length} expiring coupons`)

        // Send push notification
        const notificationSent = await sendPushNotification(user, expiringCoupons)
        if (notificationSent) {
          notificationsSent++
        }
      } else {
        console.log(`✅ User ${user.id} has no expiring coupons`)
      }
    }

    console.log(`📤 Total notifications sent: ${notificationsSent}`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        notificationsSent,
        totalUsers: users.length,
        timestamp: new Date().toISOString()
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Error in notification function:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

async function sendPushNotification(user: User, expiringCoupons: Coupon[]): Promise<boolean> {
  try {
    if (!user.push_token) {
      console.log(`⚠️ No push token for user ${user.id}`)
      return false
    }

    // Create notification content
    let title = "קופונים עומדים לפוג תוקף!"
    let body = ""
    
    if (expiringCoupons.length === 1) {
      const coupon = expiringCoupons[0]
      const expirationDate = new Date(coupon.expiration_date)
      const daysLeft = Math.ceil((expirationDate.getTime() - new Date().getTime()) / (1000 * 3600 * 24))
      
      if (daysLeft === 1) {
        body = `הקופון של ${coupon.company} פג תוקף מחר!`
      } else {
        body = `הקופון של ${coupon.company} פג תוקף בעוד ${daysLeft} ימים`
      }
    } else {
      body = `יש לך ${expiringCoupons.length} קופונים שפגים השבוע הקרוב`
    }

    // Send via Apple Push Notification service
    const apnPayload = {
      aps: {
        alert: {
          title: title,
          body: body
        },
        sound: "default",
        badge: expiringCoupons.length
      },
      coupons: expiringCoupons.map(c => c.id)
    }

    console.log(`📱 Sending push notification to user ${user.id}:`, { title, body })

    // Here you would integrate with Apple Push Notification service
    // For now, we'll log the notification
    console.log(`📤 Push notification payload:`, apnPayload)
    
    return true

  } catch (error) {
    console.error(`❌ Error sending push notification to user ${user.id}:`, error)
    return false
  }
}

/* 
 * To deploy this function:
 * 1. Run: supabase functions deploy send-daily-notifications
 * 2. Set up a cron job to call this function daily at your chosen time
 */