// Edge Function: Send Notification
// Sends push notifications via OneSignal while respecting user preferences
// Supports: new_match, match_join, event_join, chat_message notifications

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ONESIGNAL_APP_ID = '67c70940-dc92-4d95-9072-503b2f5d84c8'
const ONESIGNAL_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Map notification type to user preference field
const NOTIFICATION_PREFERENCE_MAP: Record<string, string> = {
  'new_match': 'notify_new_matches',
  'event_join': 'notify_event_joins',
  'event_created': 'notify_event_joins',
  'chat_message': 'notify_chat_messages',
  'match_join': 'notify_new_matches',
  'poll_agreement': 'notify_event_joins'
}

interface NotificationRequest {
  senderId: string
  recipientIds: string[]
  message: string
  activityName?: string
  chatType?: 'match' | 'event' | 'circle'
  chatId?: string
  notificationType: 'new_match' | 'event_join' | 'event_created' | 'chat_message' | 'match_join' | 'poll_agreement'
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    // Parse request body
    const body: NotificationRequest = await req.json()
    const { senderId, recipientIds, message, activityName, chatType, chatId, notificationType } = body

    // Validate required fields
    if (!senderId || !recipientIds || recipientIds.length === 0 || !message || !notificationType) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required fields: senderId, recipientIds, message, notificationType'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400
        }
      )
    }

    // Get preference field name
    const preferenceField = NOTIFICATION_PREFERENCE_MAP[notificationType]
    if (!preferenceField) {
      return new Response(
        JSON.stringify({
          success: false,
          error: `Invalid notification type: ${notificationType}. Must be one of: new_match, match_join, event_join, event_created, chat_message, poll_agreement`
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

    // Get sender's name
    const { data: sender, error: senderError } = await supabaseClient
      .from('profiles')
      .select('name')
      .eq('id', senderId)
      .single()

    if (senderError) {
      console.error('Error fetching sender:', senderError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to fetch sender profile'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500
        }
      )
    }

    const senderName = sender?.name || 'Someone'

    // Query recipients who:
    // 1. Are in the recipientIds list
    // 2. Have OneSignal player ID (push enabled)
    // 3. Have the specific notification preference enabled
    const { data: recipients, error: recipientsError } = await supabaseClient
      .from('profiles')
      .select('id, name, onesignal_player_id')
      .in('id', recipientIds)
      .not('onesignal_player_id', 'is', null)
      .eq(preferenceField, true)

    if (recipientsError) {
      console.error('Error fetching recipients:', recipientsError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to fetch recipient profiles'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500
        }
      )
    }

    // Filter out recipients who have muted this chat
    let filteredRecipients = recipients || []

    if (chatId && chatType) {
      // Build query to check for muted chats
      let muteQuery = supabaseClient
        .from('muted_chats')
        .select('profile_id')

      // Apply the appropriate filter based on chat type
      if (chatType === 'match') {
        muteQuery = muteQuery.eq('match_id', chatId)
      } else if (chatType === 'event') {
        muteQuery = muteQuery.eq('event_id', chatId)
      } else if (chatType === 'circle') {
        muteQuery = muteQuery.eq('circle_id', chatId)
      }

      const { data: mutedChats, error: mutedError } = await muteQuery

      if (mutedError) {
        console.error('Error checking muted chats:', mutedError)
        // Continue sending notifications even if mute check fails
      } else if (mutedChats && mutedChats.length > 0) {
        const mutedProfileIds = new Set(mutedChats.map(m => m.profile_id))
        filteredRecipients = filteredRecipients.filter(r => !mutedProfileIds.has(r.id))
        console.log(`Filtered out ${mutedChats.length} muted recipients`)
      }
    }

    // Filter out recipients who have blocked the sender (unilateral blocking)
    const { data: blockingRecipients, error: blockError } = await supabaseClient
      .from('blocked_users')
      .select('blocker_id')
      .eq('blocked_id', senderId)

    if (blockError) {
      console.error('Error checking blocked users:', blockError)
      // Continue sending notifications even if block check fails
    } else if (blockingRecipients && blockingRecipients.length > 0) {
      const blockingProfileIds = new Set(blockingRecipients.map(b => b.blocker_id))
      filteredRecipients = filteredRecipients.filter(r => !blockingProfileIds.has(r.id))
      console.log(`Filtered out ${blockingRecipients.length} recipients who blocked the sender`)
    }

    // Filter out null player IDs and get array of player IDs
    const playerIds = filteredRecipients
      ?.map(r => r.onesignal_player_id)
      .filter((id): id is string => id !== null) || []

    console.log(`Sending ${notificationType} notifications:`, {
      senderId,
      senderName,
      recipientCount: recipientIds.length,
      eligibleCount: playerIds.length,
      preferenceField,
      activityName,
      chatType
    })

    // If no eligible recipients, return success but with zero sent
    if (playerIds.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No eligible recipients (all users have disabled this notification type)',
          sent: 0,
          totalRecipients: recipientIds.length
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

    // Build notification content based on type
    let heading = ''
    let content = ''
    let notificationData: Record<string, any> = {
      type: notificationType,
      sender_id: senderId,
      sender_name: senderName
    }

    switch (notificationType) {
      case 'new_match':
        heading = `${activityName || 'New Match'}!`
        content = `${senderName} just joined your match!`
        notificationData.chatType = chatType  // Use camelCase for consistency with client code
        notificationData.chatId = chatId
        break

      case 'match_join':
        heading = `${activityName || 'Match Update'}!`
        content = `${senderName} joined your match!`
        notificationData.chatType = chatType  // Use camelCase for consistency with client code
        notificationData.chatId = chatId
        break

      case 'event_join':
        heading = `${activityName || 'Event Update'}!`
        content = `${senderName} is joining your event!`
        notificationData.chatType = chatType  // Use camelCase for consistency with client code
        notificationData.chatId = chatId
        break

      case 'event_created':
        heading = `${activityName || 'New Event'}!`
        content = message  // Message includes formatted date
        notificationData.chatType = chatType  // Use camelCase for consistency with client code
        notificationData.chatId = chatId
        break

      case 'chat_message':
        heading = activityName || 'New Message'
        content = `${senderName}: ${message}`
        notificationData.chatType = chatType  // Use camelCase for consistency with client code
        notificationData.chatId = chatId
        notificationData.message = message
        break

      case 'poll_agreement':
        heading = `${activityName || 'Event'} - Agreement Reached!`
        content = message  // Message includes the agreed option and vote count
        notificationData.chatType = chatType  // Use camelCase for consistency with client code
        notificationData.chatId = chatId
        break
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
        data: notificationData,
        // Web Push specific settings
        web_push_topic: chatId || undefined,  // Helps group notifications
        isAnyWeb: true,  // Required for Web SDK v16
        chrome_web_image: undefined,  // Prevent image loading errors
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

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Notifications sent successfully',
        sent: playerIds.length,
        totalRecipients: recipientIds.length,
        oneSignalId: oneSignalResult.id
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Fatal error in send-notification:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Unknown error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})
