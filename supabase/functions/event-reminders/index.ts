// Edge Function: Event Reminders
// Runs hourly via cron job to send timezone-specific 9am reminders for events scheduled today

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
  timezone: string
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

// Helper function to get start and end of today in a given timezone
function getTodayInTimezone(timezone: string): { start: Date, end: Date } | null {
  try {
    const now = new Date()

    // Get the date string in the target timezone (e.g., "12/25/2023")
    const dateFormatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    })

    const parts = dateFormatter.formatToParts(now)
    const month = parts.find(p => p.type === 'month')?.value
    const day = parts.find(p => p.type === 'day')?.value
    const year = parts.find(p => p.type === 'year')?.value

    if (!month || !day || !year) return null

    // Create start of day in target timezone
    const startOfDayLocal = new Date(`${year}-${month}-${day}T00:00:00`)
    const endOfDayLocal = new Date(`${year}-${month}-${day}T23:59:59`)

    // Convert to UTC for database queries
    // Get the offset for this timezone
    const offsetFormatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      timeZoneName: 'short'
    })

    // This is a simplified approach - we'll use the date string to construct UTC boundaries
    // Get midnight in the target timezone as a UTC timestamp
    const localMidnightString = `${year}-${month}-${day}T00:00:00`
    const localEndOfDayString = `${year}-${month}-${day}T23:59:59.999`

    // Parse these as if they were in the local timezone, then adjust
    const tempDate = new Date(localMidnightString)
    const utcString = tempDate.toLocaleString('en-US', { timeZone: timezone })

    // Better approach: calculate the actual UTC boundaries
    // Get current time in both UTC and target timezone to calculate offset
    const utcTime = new Date().getTime()
    const utcDate = new Date(utcTime)

    const localTimeString = utcDate.toLocaleString('en-US', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    })

    // For simplicity, let's use a different approach
    // We'll check if events.scheduled_date falls on the same calendar date when converted to the user's timezone
    // This requires checking in the application logic rather than pure SQL

    return { start: startOfDayLocal, end: endOfDayLocal }
  } catch (error) {
    console.error(`Error calculating today for timezone ${timezone}:`, error)
    return null
  }
}

// Helper to check if a date is today in a given timezone
function isToday(dateString: string, timezone: string): boolean {
  try {
    const date = new Date(dateString)
    const now = new Date()

    // Format both dates in the target timezone
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
  try {
    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const now = new Date()
    console.log('Starting timezone-aware event reminders job', {
      now: now.toISOString()
    })

    // ==========================================
    // Step 1: Get all users with reminders enabled and their timezones
    // ==========================================

    const { data: usersWithReminders, error: usersError } = await supabaseClient
      .from('profiles')
      .select('id, name, timezone, onesignal_player_id')
      .eq('event_reminders_enabled', true)
      .not('onesignal_player_id', 'is', null)

    if (usersError) {
      console.error('Error fetching users:', usersError)
      throw usersError
    }

    if (!usersWithReminders || usersWithReminders.length === 0) {
      console.log('No users with event reminders enabled')
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No users with reminders enabled',
          timestamp: now.toISOString()
        }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

    console.log(`Found ${usersWithReminders.length} users with reminders enabled`)

    // ==========================================
    // Step 2: Filter users who are currently in their 9am hour
    // ==========================================

    const usersAt9am = usersWithReminders.filter(user => {
      const hour = getHourInTimezone(user.timezone || 'America/Los_Angeles')
      return hour === 9
    })

    if (usersAt9am.length === 0) {
      console.log('No users currently in their 9am hour')
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No users in 9am hour',
          timestamp: now.toISOString()
        }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

    console.log(`Found ${usersAt9am.length} users in their 9am hour`)

    // ==========================================
    // Step 3: Get all events for these users
    // ==========================================

    const userIds = usersAt9am.map(u => u.id)

    const { data: userEvents, error: eventsError } = await supabaseClient
      .from('event_participants')
      .select(`
        profile_id,
        events!inner(
          id,
          name,
          scheduled_date,
          match_id,
          status
        )
      `)
      .in('profile_id', userIds)
      .eq('events.status', 'scheduled')

    if (eventsError) {
      console.error('Error fetching events:', eventsError)
      throw eventsError
    }

    if (!userEvents || userEvents.length === 0) {
      console.log('No events found for users')
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No events found',
          timestamp: now.toISOString()
        }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

    console.log(`Found ${userEvents.length} event participations`)

    // ==========================================
    // Step 4: Filter events that are today in each user's timezone
    // ==========================================

    const remindersToSend: EventReminder[] = []

    for (const participation of userEvents) {
      const user = usersAt9am.find(u => u.id === participation.profile_id)
      if (!user) continue

      const event = participation.events
      const userTimezone = user.timezone || 'America/Los_Angeles'

      // Check if event is scheduled for today in user's timezone
      if (isToday(event.scheduled_date, userTimezone)) {
        // Check if user has muted this event
        const { data: mutedChat } = await supabaseClient
          .from('muted_chats')
          .select('id')
          .eq('profile_id', user.id)
          .eq('event_id', event.id)
          .maybeSingle()

        if (mutedChat) {
          console.log(`Skipping ${user.name} - has muted event ${event.id}`)
          continue
        }

        remindersToSend.push({
          event_id: event.id,
          event_name: event.name,
          event_scheduled_date: event.scheduled_date,
          profile_id: user.id,
          profile_name: user.name,
          onesignal_player_id: user.onesignal_player_id,
          match_id: event.match_id,
          timezone: userTimezone
        })
      }
    }

    if (remindersToSend.length === 0) {
      console.log('No events scheduled for today for any users in 9am hour')
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

    console.log(`Sending ${remindersToSend.length} event reminders`)

    // ==========================================
    // Step 5: Group by user and send notifications
    // ==========================================

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
          console.log(`Sent notification to ${firstEvent.profile_name} (${firstEvent.timezone})`)
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
          usersChecked: usersWithReminders.length,
          usersAt9am: usersAt9am.length,
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
