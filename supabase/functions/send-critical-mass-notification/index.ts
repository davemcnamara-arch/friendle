// Edge Function: Send Critical Mass Notification
// Sends push notifications when activities reach 4 or 8 interested users
// Helps solve coordination problem by notifying at key momentum thresholds

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ONESIGNAL_APP_ID = '67c70940-dc92-4d95-9072-503b2f5d84c8'
const ONESIGNAL_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CriticalMassRequest {
  matchId: string
  threshold: 4 | 8
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    // Parse request body
    const body: CriticalMassRequest = await req.json()
    const { matchId, threshold } = body

    // Validate required fields
    if (!matchId || !threshold) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required fields: matchId, threshold'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400
        }
      )
    }

    // Validate threshold value
    if (threshold !== 4 && threshold !== 8) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Invalid threshold. Must be 4 or 8'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400
        }
      )
    }

    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get match details and check if notification already sent
    const { data: match, error: matchError } = await supabaseClient
      .from('matches')
      .select(`
        id,
        activity_id,
        circle_id,
        notified_at_4,
        notified_at_8,
        activities (name),
        circles (name)
      `)
      .eq('id', matchId)
      .single()

    if (matchError || !match) {
      console.error('Error fetching match:', matchError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Match not found'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 404
        }
      )
    }

    // Check if notification already sent for this threshold
    const notificationField = threshold === 4 ? 'notified_at_4' : 'notified_at_8'
    if (match[notificationField]) {
      console.log(`Notification already sent for threshold ${threshold}`)
      return new Response(
        JSON.stringify({
          success: true,
          message: `Notification already sent for threshold ${threshold}`,
          sent: 0
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

    // Anti-spam: If threshold 8, check if threshold 4 was sent less than 30 minutes ago
    if (threshold === 8 && match.notified_at_4) {
      const threshold4Time = new Date(match.notified_at_4).getTime()
      const now = new Date().getTime()
      const minutesSinceThreshold4 = (now - threshold4Time) / 1000 / 60

      if (minutesSinceThreshold4 < 30) {
        console.log(`Skipping threshold 8 notification - threshold 4 sent ${minutesSinceThreshold4.toFixed(1)} minutes ago`)
        return new Response(
          JSON.stringify({
            success: true,
            message: 'Skipping notification - too soon after threshold 4',
            sent: 0
          }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200
          }
        )
      }
    }

    // Get all interested users for this activity + circle
    const { data: interestedUsers, error: interestedError } = await supabaseClient
      .from('preferences')
      .select('profile_id')
      .eq('circle_id', match.circle_id)
      .eq('activity_id', match.activity_id)
      .eq('selected', true)

    if (interestedError) {
      console.error('Error fetching interested users:', interestedError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to fetch interested users'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500
        }
      )
    }

    const interestedCount = interestedUsers?.length || 0
    const interestedProfileIds = interestedUsers?.map(u => u.profile_id) || []

    // Get users who have already joined the match
    const { data: participants, error: participantsError } = await supabaseClient
      .from('match_participants')
      .select('profile_id')
      .eq('match_id', matchId)

    if (participantsError) {
      console.error('Error fetching participants:', participantsError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to fetch match participants'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500
        }
      )
    }

    const joinedCount = participants?.length || 0
    const joinedProfileIds = new Set(participants?.map(p => p.profile_id) || [])

    // Filter to get users who are interested but haven't joined yet
    const eligibleProfileIds = interestedProfileIds.filter(id => !joinedProfileIds.has(id))

    if (eligibleProfileIds.length === 0) {
      console.log('No eligible users to notify (all interested users have joined)')
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No eligible users to notify',
          sent: 0
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

    // Get user preferences field based on threshold
    const preferenceField = threshold === 4 ? 'notify_at_4' : 'notify_at_8'

    // Query eligible users who have enabled this notification type and have OneSignal player ID
    const { data: eligibleUsers, error: usersError } = await supabaseClient
      .from('profiles')
      .select('id, name, onesignal_player_id, timezone')
      .in('id', eligibleProfileIds)
      .not('onesignal_player_id', 'is', null)
      .eq(preferenceField, true)

    if (usersError) {
      console.error('Error fetching eligible users:', usersError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to fetch eligible users'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500
        }
      )
    }

    // Filter out users in quiet hours (midnight-7am local time)
    const usersNotInQuietHours = eligibleUsers?.filter(user => {
      if (!user.timezone) return true // If no timezone set, send notification

      try {
        // Get current time in user's timezone
        const now = new Date()
        const userTime = new Date(now.toLocaleString('en-US', { timeZone: user.timezone }))
        const hour = userTime.getHours()

        // Quiet hours: midnight (0) to 7am (6)
        return hour >= 7 || hour < 0
      } catch (error) {
        console.error(`Error parsing timezone for user ${user.id}:`, error)
        return true // If timezone parsing fails, send notification
      }
    }) || []

    // Get player IDs for notification
    const playerIds = usersNotInQuietHours
      .map(u => u.onesignal_player_id)
      .filter((id): id is string => id !== null)

    console.log(`Critical mass notification for threshold ${threshold}:`, {
      matchId,
      activityName: match.activities?.name,
      circleName: match.circles?.name,
      interestedCount,
      joinedCount,
      eligibleUsers: eligibleProfileIds.length,
      afterPreferences: eligibleUsers?.length || 0,
      afterQuietHours: playerIds.length,
      threshold
    })

    // If no eligible recipients after filtering, mark as sent but don't send
    if (playerIds.length === 0) {
      // Still mark as sent to avoid checking again
      await supabaseClient
        .from('matches')
        .update({ [notificationField]: new Date().toISOString() })
        .eq('id', matchId)

      return new Response(
        JSON.stringify({
          success: true,
          message: 'No eligible recipients after filtering (quiet hours, preferences, or no player IDs)',
          sent: 0
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

    // Build notification content based on threshold
    const activityName = match.activities?.name || 'Activity'
    let heading = ''
    let content = ''

    if (threshold === 4) {
      heading = `${activityName} crew forming!`
      content = `${interestedCount} people interested • ${joinedCount} in chat\nJoin now to coordinate`
    } else { // threshold === 8
      heading = `${activityName} is really happening!`
      content = `${interestedCount} people interested • ${joinedCount} in chat\nDon't miss out!`
    }

    // Send push notification via OneSignal
    const oneSignalResponse = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${ONESIGNAL_API_KEY}`
      },
      body: JSON.stringify({
        app_id: ONESIGNAL_APP_ID,
        include_player_ids: playerIds,
        headings: { en: heading },
        contents: { en: content },
        data: {
          type: 'critical_mass',
          matchId: matchId,
          activityId: match.activity_id,
          circleId: match.circle_id,
          threshold: threshold,
          chatType: 'match',
          chatId: matchId
        },
        buttons: [
          {
            id: 'join',
            text: 'Join Match'
          },
          {
            id: 'dismiss',
            text: 'Not Now'
          }
        ],
        web_push_topic: matchId,
        isAnyWeb: true,
        chrome_web_image: undefined
      })
    })

    if (!oneSignalResponse.ok) {
      const errorText = await oneSignalResponse.text()
      console.error('OneSignal API error:', errorText)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to send push notifications',
          details: errorText
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500
        }
      )
    }

    const oneSignalResult = await oneSignalResponse.json()
    console.log('OneSignal response:', oneSignalResult)

    // Mark notification as sent
    const { error: updateError } = await supabaseClient
      .from('matches')
      .update({ [notificationField]: new Date().toISOString() })
      .eq('id', matchId)

    if (updateError) {
      console.error('Error marking notification as sent:', updateError)
      // Don't fail the request - notification was sent successfully
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Critical mass notifications sent successfully',
        sent: playerIds.length,
        threshold: threshold,
        interestedCount: interestedCount,
        joinedCount: joinedCount,
        oneSignalId: oneSignalResult.id
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in send-critical-mass-notification:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error occurred'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})
