// Edge Function: Event Reminders
// Runs daily via cron job at 9:00 AM UTC to send reminders for events scheduled today

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ONESIGNAL_APP_ID = '67c70940-dc92-4d95-9072-503b2f5d84c8'
const ONESIGNAL_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')

interface EventReminder {
  event_id: string
  event_name: string
  event_scheduled_date: string
  profile_id: string
  profile_name: string
  onesignal_player_id: string
  match_id: string
}

serve(async (req) => {
  try {
    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const now = new Date()

    // Get start and end of today (UTC)
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    const endOfToday = new Date(startOfToday.getTime() + 24 * 60 * 60 * 1000)

    console.log('Starting event reminders job', {
      now: now.toISOString(),
      startOfToday: startOfToday.toISOString(),
      endOfToday: endOfToday.toISOString()
    })

    // ==========================================
    // Find events scheduled for today
    // ==========================================

    const { data: todaysEvents, error: eventsError } = await supabaseClient
      .from('events')
      .select(`
        id,
        name,
        scheduled_date,
        match_id,
        event_participants!inner(
          profile_id,
          profiles!inner(
            id,
            name,
            onesignal_player_id,
            event_reminders_enabled
          )
        )
      `)
      .gte('scheduled_date', startOfToday.toISOString())
      .lt('scheduled_date', endOfToday.toISOString())
      .eq('status', 'scheduled')
      .eq('event_participants.profiles.event_reminders_enabled', true)
      .not('event_participants.profiles.onesignal_player_id', 'is', null)

    if (eventsError) {
      console.error('Error fetching events:', eventsError)
      throw eventsError
    }

    if (!todaysEvents || todaysEvents.length === 0) {
      console.log('No events scheduled for today with eligible participants')
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No reminders to send',
          timestamp: now.toISOString()
        }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

    console.log(`Found ${todaysEvents.length} events scheduled for today`)

    // ==========================================
    // Process each event and collect reminders
    // ==========================================

    const remindersToSend: EventReminder[] = []

    for (const event of todaysEvents) {
      // Check if each participant has muted this event's chat
      for (const participant of event.event_participants) {
        const profile = participant.profiles

        // Check if user has muted this event
        const { data: mutedChat } = await supabaseClient
          .from('muted_chats')
          .select('id')
          .eq('profile_id', profile.id)
          .eq('event_id', event.id)
          .single()

        if (mutedChat) {
          console.log(`Skipping ${profile.name} - has muted event ${event.id}`)
          continue
        }

        remindersToSend.push({
          event_id: event.id,
          event_name: event.name,
          event_scheduled_date: event.scheduled_date,
          profile_id: profile.id,
          profile_name: profile.name,
          onesignal_player_id: profile.onesignal_player_id,
          match_id: event.match_id
        })
      }
    }

    if (remindersToSend.length === 0) {
      console.log('No reminders to send (all participants have muted notifications)')
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No reminders to send - all muted',
          timestamp: now.toISOString()
        }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

    console.log(`Sending ${remindersToSend.length} event reminders`)

    // ==========================================
    // Group reminders by user and send notifications
    // ==========================================

    // Group reminders by user to send one notification per user
    const remindersByUser = new Map<string, EventReminder[]>()

    for (const reminder of remindersToSend) {
      if (!remindersByUser.has(reminder.profile_id)) {
        remindersByUser.set(reminder.profile_id, [])
      }
      remindersByUser.get(reminder.profile_id)!.push(reminder)
    }

    console.log(`Sending to ${remindersByUser.size} unique users`)

    // Send individual notifications (each user gets a personalized message)
    let successCount = 0

    for (const [profileId, reminders] of remindersByUser.entries()) {
      const eventCount = reminders.length
      const firstEvent = reminders[0]

      const heading = eventCount === 1
        ? 'Event Today!'
        : `${eventCount} Events Today!`

      const content = eventCount === 1
        ? `Reminder: "${firstEvent.event_name}" is scheduled for today`
        : `You have ${eventCount} events scheduled for today`

      try {
        const response = await fetch('https://onesignal.com/api/v1/notifications', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Basic ${ONESIGNAL_API_KEY}`
          },
          body: JSON.stringify({
            app_id: ONESIGNAL_APP_ID,
            include_player_ids: [firstEvent.onesignal_player_id],
            headings: { en: heading },
            contents: { en: content },
            data: {
              type: 'event_reminder',
              event_id: firstEvent.event_id,
              match_id: firstEvent.match_id,
              event_count: eventCount
            }
          })
        })

        if (!response.ok) {
          const errorText = await response.text()
          console.error(`OneSignal API error for user ${profileId}:`, errorText)
        } else {
          successCount++
          console.log(`Sent notification to ${firstEvent.profile_name}`)
        }
      } catch (notifError) {
        console.error(`Error sending notification to user ${profileId}:`, notifError)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Event reminders sent',
        timestamp: now.toISOString(),
        stats: {
          eventsFound: todaysEvents.length,
          remindersSent: successCount,
          uniqueUsers: remindersByUser.size
        }
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Fatal error in event reminders:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})
