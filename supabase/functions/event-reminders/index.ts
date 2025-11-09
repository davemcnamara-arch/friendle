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
    console.log('========================================')
    console.log('Starting timezone-aware event reminders job')
    console.log('========================================')
    console.log('Current UTC time:', now.toISOString())
    console.log('Current UTC hour:', now.getUTCHours())
    console.log('OneSignal App ID:', ONESIGNAL_APP_ID)
    console.log('OneSignal API Key configured:', !!ONESIGNAL_API_KEY)

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
      console.log('⚠️  No users with event reminders enabled')
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

    console.log(`✓ Found ${usersWithReminders.length} users with reminders enabled`)
    console.log('Users with reminders:', usersWithReminders.map(u => ({
      id: u.id,
      name: u.name,
      timezone: u.timezone,
      has_player_id: !!u.onesignal_player_id
    })))

    // ==========================================
    // Step 2: Filter users who are currently in their 9am hour
    // ==========================================

    console.log('\n--- Checking which users are in their 9am hour ---')
    const usersAt9am = usersWithReminders.filter(user => {
      const userTimezone = user.timezone || 'America/Los_Angeles'
      const hour = getHourInTimezone(userTimezone)
      const isNineAm = hour === 9

      console.log(`User: ${user.name} (${user.id})`)
      console.log(`  Timezone: ${userTimezone}`)
      console.log(`  Current hour in timezone: ${hour}`)
      console.log(`  Is 9am? ${isNineAm ? '✓ YES' : '✗ NO'}`)

      return isNineAm
    })

    if (usersAt9am.length === 0) {
      console.log('\n⚠️  No users currently in their 9am hour')
      console.log('Timezone hour breakdown:')
      usersWithReminders.forEach(u => {
        const tz = u.timezone || 'America/Los_Angeles'
        const hr = getHourInTimezone(tz)
        console.log(`  ${u.name}: ${tz} = ${hr}:00`)
      })
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No users in 9am hour',
          timestamp: now.toISOString(),
          debug: {
            totalUsersWithReminders: usersWithReminders.length,
            userTimezones: usersWithReminders.map(u => ({
              name: u.name,
              timezone: u.timezone || 'America/Los_Angeles',
              currentHour: getHourInTimezone(u.timezone || 'America/Los_Angeles')
            }))
          }
        }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

    console.log(`\n✓ Found ${usersAt9am.length} users in their 9am hour:`, usersAt9am.map(u => u.name))

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
          scheduled_date,
          match_id,
          status,
          activities(name)
        )
      `)
      .in('profile_id', userIds)
      .eq('events.status', 'scheduled')

    if (eventsError) {
      console.error('Error fetching events:', eventsError)
      throw eventsError
    }

    if (!userEvents || userEvents.length === 0) {
      console.log('\n⚠️  No scheduled events found for users in 9am hour')
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

    console.log(`\n✓ Found ${userEvents.length} event participations (status=scheduled)`)
    console.log('Events found:', userEvents.map(ep => ({
      user_id: ep.profile_id,
      event_id: ep.events.id,
      activity_name: ep.events.activities?.name || 'Unknown Activity',
      scheduled_date: ep.events.scheduled_date,
      status: ep.events.status
    })))

    // ==========================================
    // Step 4: Filter events that are today in each user's timezone
    // ==========================================

    console.log('\n--- Checking which events are scheduled for today ---')
    const remindersToSend: EventReminder[] = []

    for (const participation of userEvents) {
      const user = usersAt9am.find(u => u.id === participation.profile_id)
      if (!user) continue

      const event = participation.events
      const userTimezone = user.timezone || 'America/Los_Angeles'

      // Get today's date in the user's timezone for comparison
      const dateFormatter = new Intl.DateTimeFormat('en-US', {
        timeZone: userTimezone,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit'
      })
      const todayInUserTz = dateFormatter.format(now)
      const eventDateInUserTz = dateFormatter.format(new Date(event.scheduled_date))

      const activityName = event.activities?.name || 'Unknown Activity'

      console.log(`\nEvent: "${activityName}" (${event.id})`)
      console.log(`  User: ${user.name} (${userTimezone})`)
      console.log(`  Event scheduled_date (UTC): ${event.scheduled_date}`)
      console.log(`  Event date in user TZ: ${eventDateInUserTz}`)
      console.log(`  Today in user TZ: ${todayInUserTz}`)

      // Check if event is scheduled for today in user's timezone
      const eventIsToday = isToday(event.scheduled_date, userTimezone)
      console.log(`  Is today? ${eventIsToday ? '✓ YES' : '✗ NO'}`)

      if (eventIsToday) {
        // Check if user has muted this event
        const { data: mutedChat } = await supabaseClient
          .from('muted_chats')
          .select('id')
          .eq('profile_id', user.id)
          .eq('event_id', event.id)
          .maybeSingle()

        if (mutedChat) {
          console.log(`  ⚠️  Skipped - user has muted this event`)
          continue
        }

        console.log(`  ✓ Will send reminder`)
        remindersToSend.push({
          event_id: event.id,
          event_name: activityName,
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
      console.log('\n⚠️  No events scheduled for today for any users in 9am hour')
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

    console.log(`\n✓ Preparing to send ${remindersToSend.length} event reminders`)

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

    console.log(`\n--- Sending notifications to ${remindersByUser.size} unique users ---`)

    // Send individual notifications (each user gets a personalized message)
    let successCount = 0
    let failureCount = 0

    for (const [profileId, reminders] of remindersByUser.entries()) {
      const eventCount = reminders.length
      const firstEvent = reminders[0]

      const heading = eventCount === 1
        ? 'Event Today!'
        : `${eventCount} Events Today!`

      const content = eventCount === 1
        ? `Reminder: "${firstEvent.event_name}" is scheduled for today`
        : `You have ${eventCount} events scheduled for today`

      const notificationPayload = {
        app_id: ONESIGNAL_APP_ID,
        include_player_ids: [firstEvent.onesignal_player_id],
        headings: { en: heading },
        contents: { en: content },
        data: {
          type: 'event_reminder',
          event_id: firstEvent.event_id,
          match_id: firstEvent.match_id,
          event_count: eventCount,
          chatType: 'event',
          chatId: firstEvent.event_id
        }
      }

      console.log(`\nSending to: ${firstEvent.profile_name}`)
      console.log(`  Player ID: ${firstEvent.onesignal_player_id}`)
      console.log(`  Timezone: ${firstEvent.timezone}`)
      console.log(`  Event count: ${eventCount}`)
      console.log(`  Notification: "${heading}" - "${content}"`)

      try {
        const response = await fetch('https://onesignal.com/api/v1/notifications', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Basic ${ONESIGNAL_API_KEY}`
          },
          body: JSON.stringify(notificationPayload)
        })

        const responseData = await response.json()

        if (!response.ok) {
          failureCount++
          console.error(`  ✗ OneSignal API error (${response.status}):`, responseData)
        } else {
          successCount++
          console.log(`  ✓ Successfully sent (OneSignal ID: ${responseData.id})`)
          console.log(`  Recipients: ${responseData.recipients || 'unknown'}`)
        }
      } catch (notifError) {
        failureCount++
        console.error(`  ✗ Exception sending notification:`, notifError)
      }
    }

    console.log('\n========================================')
    console.log('Event reminders job completed')
    console.log('========================================')
    console.log(`✓ Success: ${successCount}`)
    console.log(`✗ Failed: ${failureCount}`)
    console.log(`Total users with reminders enabled: ${usersWithReminders.length}`)
    console.log(`Users in 9am hour: ${usersAt9am.length}`)
    console.log(`Total reminders processed: ${remindersToSend.length}`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Event reminders sent',
        timestamp: now.toISOString(),
        stats: {
          usersChecked: usersWithReminders.length,
          usersAt9am: usersAt9am.length,
          eventsChecked: userEvents?.length || 0,
          remindersToSend: remindersToSend.length,
          notificationsSent: successCount,
          notificationsFailed: failureCount,
          uniqueUsers: remindersByUser.size
        },
        debug: {
          utcTime: now.toISOString(),
          utcHour: now.getUTCHours(),
          usersAt9am: usersAt9am.map(u => ({
            name: u.name,
            timezone: u.timezone,
            hasPlayerId: !!u.onesignal_player_id
          }))
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
