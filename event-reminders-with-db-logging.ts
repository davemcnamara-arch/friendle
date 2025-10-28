// Edge Function: Event Reminders with Database Logging
// Writes to function_execution_logs table since console.log doesn't show for cron jobs

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ONESIGNAL_APP_ID = '67c70940-dc92-4d95-9072-503b2f5d84c8'
const ONESIGNAL_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')

// Helper to log to database
async function logToDB(supabaseClient: any, step: string, status: string, message: string, data: any = null) {
  try {
    await supabaseClient
      .from('function_execution_logs')
      .insert({
        function_name: 'event-reminders',
        step,
        status,
        message,
        data: data ? JSON.parse(JSON.stringify(data)) : null
      })
    console.log(`[DB LOG] ${step}: ${message}`)
  } catch (error) {
    console.error('Failed to write to DB log:', error)
  }
}

// Helper function to get current hour in a given timezone
function getHourInTimezone(timezone: string): number {
  try {
    const now = new Date()
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      hour: 'numeric',
      hour12: false
    })
    const hour = parseInt(formatter.format(now))
    return hour
  } catch (error) {
    console.error(`Error getting hour for timezone ${timezone}:`, error)
    return -1
  }
}

// Helper to check if a date is today in a given timezone
function isToday(dateString: string, timezone: string): boolean {
  try {
    const date = new Date(dateString)
    const now = new Date()

    const dateFormatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    })

    const dateInTz = dateFormatter.format(date)
    const nowInTz = dateFormatter.format(now)

    return dateInTz === nowInTz
  } catch (error) {
    console.error(`Error checking if date is today:`, error)
    return false
  }
}

serve(async (req) => {
  const now = new Date()
  let supabaseClient: any = null

  try {
    // Create Supabase client
    supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    await logToDB(supabaseClient, 'startup', 'info', 'Function started', {
      utc_time: now.toISOString(),
      utc_hour: now.getUTCHours()
    })

    // Get all users with reminders enabled
    const { data: usersWithReminders, error: usersError } = await supabaseClient
      .from('profiles')
      .select('id, name, timezone, onesignal_player_id')
      .eq('event_reminders_enabled', true)
      .not('onesignal_player_id', 'is', null)

    if (usersError) {
      await logToDB(supabaseClient, 'query_users', 'error', 'Failed to query users', { error: usersError.message })
      throw usersError
    }

    await logToDB(supabaseClient, 'query_users', 'success', `Found ${usersWithReminders?.length || 0} users`, {
      count: usersWithReminders?.length || 0,
      users: usersWithReminders?.map(u => ({ id: u.id, name: u.name, timezone: u.timezone }))
    })

    if (!usersWithReminders || usersWithReminders.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'No users with reminders enabled' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200
      })
    }

    // Filter users in their 9am hour
    const usersAt9am = usersWithReminders.filter(user => {
      const userTimezone = user.timezone || 'America/Los_Angeles'
      const hour = getHourInTimezone(userTimezone)
      return hour === 9
    })

    await logToDB(supabaseClient, 'filter_9am', 'info', `${usersAt9am.length} users in 9am hour`, {
      users_at_9am: usersAt9am.map(u => ({ name: u.name, timezone: u.timezone })),
      all_users_hours: usersWithReminders.map(u => ({
        name: u.name,
        timezone: u.timezone || 'America/Los_Angeles',
        current_hour: getHourInTimezone(u.timezone || 'America/Los_Angeles')
      }))
    })

    if (usersAt9am.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'No users in 9am hour' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200
      })
    }

    // Get events for these users
    const userIds = usersAt9am.map(u => u.id)

    const { data: userEvents, error: eventsError } = await supabaseClient
      .from('event_participants')
      .select(`
        profile_id,
        events!inner(
          id,
          scheduled_date,
          match_id,
          status,
          activities(name)
        )
      `)
      .in('profile_id', userIds)
      .eq('events.status', 'scheduled')

    if (eventsError) {
      await logToDB(supabaseClient, 'query_events', 'error', 'Failed to query events', { error: eventsError.message })
      throw eventsError
    }

    await logToDB(supabaseClient, 'query_events', 'success', `Found ${userEvents?.length || 0} events`, {
      count: userEvents?.length || 0,
      events: userEvents?.map(ep => ({
        user_id: ep.profile_id,
        event_id: ep.events.id,
        activity_name: ep.events.activities?.name,
        scheduled_date: ep.events.scheduled_date
      }))
    })

    if (!userEvents || userEvents.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'No events found' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200
      })
    }

    // Filter events for today
    const remindersToSend: any[] = []

    for (const participation of userEvents) {
      const user = usersAt9am.find(u => u.id === participation.profile_id)
      if (!user) continue

      const event = participation.events
      const userTimezone = user.timezone || 'America/Los_Angeles'
      const activityName = event.activities?.name || 'Unknown Activity'

      if (isToday(event.scheduled_date, userTimezone)) {
        // Check if muted
        const { data: mutedChat } = await supabaseClient
          .from('muted_chats')
          .select('id')
          .eq('profile_id', user.id)
          .eq('event_id', event.id)
          .maybeSingle()

        if (!mutedChat) {
          remindersToSend.push({
            event_id: event.id,
            event_name: activityName,
            profile_id: user.id,
            profile_name: user.name,
            onesignal_player_id: user.onesignal_player_id,
            match_id: event.match_id,
            timezone: userTimezone
          })
        }
      }
    }

    await logToDB(supabaseClient, 'filter_today', 'info', `${remindersToSend.length} reminders to send`, {
      reminders: remindersToSend.map(r => ({
        user: r.profile_name,
        event: r.event_name,
        player_id: r.onesignal_player_id
      }))
    })

    if (remindersToSend.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'No reminders to send' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200
      })
    }

    // Send notifications
    const remindersByUser = new Map()
    for (const reminder of remindersToSend) {
      if (!remindersByUser.has(reminder.profile_id)) {
        remindersByUser.set(reminder.profile_id, [])
      }
      remindersByUser.get(reminder.profile_id)!.push(reminder)
    }

    let successCount = 0
    let failureCount = 0

    for (const [profileId, reminders] of remindersByUser.entries()) {
      const eventCount = reminders.length
      const firstEvent = reminders[0]

      const heading = eventCount === 1 ? 'Event Today!' : `${eventCount} Events Today!`
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

        const responseData = await response.json()

        if (!response.ok) {
          failureCount++
          await logToDB(supabaseClient, 'send_notification', 'error', `Failed for ${firstEvent.profile_name}`, {
            user: firstEvent.profile_name,
            status: response.status,
            error: responseData
          })
        } else {
          successCount++
          await logToDB(supabaseClient, 'send_notification', 'success', `Sent to ${firstEvent.profile_name}`, {
            user: firstEvent.profile_name,
            onesignal_id: responseData.id,
            recipients: responseData.recipients
          })
        }
      } catch (notifError: any) {
        failureCount++
        await logToDB(supabaseClient, 'send_notification', 'error', `Exception for ${firstEvent.profile_name}`, {
          user: firstEvent.profile_name,
          error: notifError.message
        })
      }
    }

    await logToDB(supabaseClient, 'complete', 'success', 'Function completed', {
      success_count: successCount,
      failure_count: failureCount,
      total_users: usersWithReminders.length,
      users_at_9am: usersAt9am.length
    })

    return new Response(JSON.stringify({
      success: true,
      message: 'Event reminders processed',
      stats: {
        notificationsSent: successCount,
        notificationsFailed: failureCount,
        usersAt9am: usersAt9am.length
      }
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (error: any) {
    if (supabaseClient) {
      await logToDB(supabaseClient, 'fatal_error', 'error', 'Function crashed', {
        error: error.message,
        stack: error.stack
      })
    }

    console.error('Fatal error:', error)

    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500
    })
  }
})
