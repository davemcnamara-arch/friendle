// Edge Function: Inactivity Cleanup
// Runs daily via cron job to:
// - Day 5: Send "Still interested?" warning notifications
// - Day 7: Auto-remove inactive participants (unless they have upcoming events)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ONESIGNAL_APP_ID = '67c70940-dc92-4d95-9072-503b2f5d84c8'
const ONESIGNAL_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')

interface InactiveParticipant {
  match_id: string
  profile_id: string
  profile_name: string
  onesignal_player_id: string | null
  last_interaction_at: string
  days_inactive: number
  has_upcoming_events: boolean
}

serve(async (req) => {
  try {
    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const now = new Date()
    const fiveDaysAgo = new Date(now.getTime() - 5 * 24 * 60 * 60 * 1000)
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)

    console.log('Starting inactivity cleanup job', {
      now: now.toISOString(),
      fiveDaysAgo: fiveDaysAgo.toISOString(),
      sevenDaysAgo: sevenDaysAgo.toISOString()
    })

    // ==========================================
    // PHASE 1: Day 5 Warnings
    // ==========================================

    // Find participants inactive for 5+ days who haven't been warned yet
    const { data: day5Participants, error: day5Error } = await supabaseClient
      .from('match_participants')
      .select(`
        match_id,
        profile_id,
        last_interaction_at,
        profiles!inner(id, name, onesignal_player_id, notify_inactivity_warnings),
        matches!inner(id, activity_id, circle_id)
      `)
      .lte('last_interaction_at', fiveDaysAgo.toISOString())
      .not('profiles.onesignal_player_id', 'is', null) // Has push notification enabled
      .eq('profiles.notify_inactivity_warnings', true) // Check user preference

    if (day5Error) {
      console.error('Error fetching day 5 participants:', day5Error)
    } else if (day5Participants && day5Participants.length > 0) {
      console.log(`Found ${day5Participants.length} participants to warn`)

      // Get all user preferences to filter out matches they're no longer interested in
      const uniqueProfileIds = [...new Set(day5Participants.map((p: any) => p.profile_id))]
      const { data: userPreferences } = await supabaseClient
        .from('preferences')
        .select('profile_id, activity_id, circle_id')
        .in('profile_id', uniqueProfileIds)

      // Create a map of profile_id -> Set of "circle_id|activity_id"
      const preferenceMap = new Map<string, Set<string>>()
      userPreferences?.forEach(pref => {
        if (!preferenceMap.has(pref.profile_id)) {
          preferenceMap.set(pref.profile_id, new Set())
        }
        preferenceMap.get(pref.profile_id)!.add(`${pref.circle_id}|${pref.activity_id}`)
      })

      // Filter out participants who no longer have that preference active
      const participantsWithActivePreferences = day5Participants.filter((p: any) => {
        const userPrefs = preferenceMap.get(p.profile_id)
        if (!userPrefs) {
          console.log(`No preferences found for ${p.profile_id} - skipping warning`)
          return false
        }
        const prefKey = `${p.matches.circle_id}|${p.matches.activity_id}`
        const hasActivePreference = userPrefs.has(prefKey)
        if (!hasActivePreference) {
          console.log(`User ${p.profile_id} no longer has preference for ${prefKey} - skipping warning`)
        }
        return hasActivePreference
      })

      console.log(`${participantsWithActivePreferences.length} participants with active preferences`)

      // Filter out those who already have pending warnings
      const { data: existingWarnings } = await supabaseClient
        .from('inactivity_warnings')
        .select('match_id, profile_id')
        .eq('status', 'pending')

      const warningSet = new Set(
        existingWarnings?.map(w => `${w.match_id}:${w.profile_id}`) || []
      )

      const participantsToWarn = participantsWithActivePreferences.filter((p: any) => {
        const key = `${p.match_id}:${p.profile_id}`
        return !warningSet.has(key)
      })

      if (participantsToWarn.length > 0) {
        console.log(`Sending warnings to ${participantsToWarn.length} participants`)

        // Send individual notifications with match-specific data for proper navigation
        const warningsToInsert: Array<{ match_id: string; profile_id: string; status: string }> = []

        for (const participant of participantsToWarn) {
          const playerId = participant.profiles.onesignal_player_id

          if (playerId) {
            // Send push notification via OneSignal with match_id for navigation
            try {
              const response = await fetch('https://onesignal.com/api/v1/notifications', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': `Basic ${ONESIGNAL_API_KEY}`
                },
                body: JSON.stringify({
                  app_id: ONESIGNAL_APP_ID,
                  include_player_ids: [playerId],
                  headings: { en: 'Still interested?' },
                  contents: {
                    en: "We noticed you haven't been active in your match lately. Tap to let us know you're still interested!"
                  },
                  data: {
                    type: 'inactivity_warning',
                    action: 'stay_interested',
                    chatType: 'match',
                    chatId: participant.match_id,
                    match_id: participant.match_id
                  }
                })
              })

              if (!response.ok) {
                console.error(`OneSignal API error for ${participant.profile_id}:`, await response.text())
              } else {
                console.log(`Sent notification to ${participant.profiles.name}`)
              }
            } catch (notifError) {
              console.error(`Error sending notification to ${participant.profile_id}:`, notifError)
            }
          }

          // Add to warnings batch
          warningsToInsert.push({
            match_id: participant.match_id,
            profile_id: participant.profile_id,
            status: 'pending'
          })
        }

        // Record all warnings in database (upsert to handle UNIQUE constraint)
        if (warningsToInsert.length > 0) {
          // Add warned_at timestamp for upsert
          const warningsWithTimestamp = warningsToInsert.map(w => ({
            ...w,
            warned_at: new Date().toISOString()
          }))

          const { error: upsertError } = await supabaseClient
            .from('inactivity_warnings')
            .upsert(warningsWithTimestamp, {
              onConflict: 'match_id,profile_id',
              ignoreDuplicates: false  // Update existing rows
            })

          if (upsertError) {
            console.error('Error upserting warnings:', upsertError)
          } else {
            console.log(`Upserted ${warningsToInsert.length} warnings (inserted new or updated existing)`)
          }
        }
      }
    }

    // ==========================================
    // CLEANUP: Remove stale pending warnings
    // ==========================================
    // Clean up pending warnings for matches where users no longer have that preference
    console.log('Cleaning up stale pending warnings...')

    const { data: allPendingWarnings } = await supabaseClient
      .from('inactivity_warnings')
      .select(`
        match_id,
        profile_id,
        matches!inner(activity_id, circle_id)
      `)
      .eq('status', 'pending')

    if (allPendingWarnings && allPendingWarnings.length > 0) {
      console.log(`Found ${allPendingWarnings.length} pending warnings to check`)

      // Get all user preferences
      const warningProfileIds = [...new Set(allPendingWarnings.map((w: any) => w.profile_id))]
      const { data: allUserPrefs } = await supabaseClient
        .from('preferences')
        .select('profile_id, activity_id, circle_id')
        .in('profile_id', warningProfileIds)

      // Create preference map
      const userPrefMap = new Map<string, Set<string>>()
      allUserPrefs?.forEach(pref => {
        if (!userPrefMap.has(pref.profile_id)) {
          userPrefMap.set(pref.profile_id, new Set())
        }
        userPrefMap.get(pref.profile_id)!.add(`${pref.circle_id}|${pref.activity_id}`)
      })

      // Find warnings where user no longer has the preference
      const warningsToRemove: Array<{ match_id: string; profile_id: string }> = []

      for (const warning of allPendingWarnings) {
        const userPrefs = userPrefMap.get(warning.profile_id)
        const prefKey = `${warning.matches.circle_id}|${warning.matches.activity_id}`

        if (!userPrefs || !userPrefs.has(prefKey)) {
          warningsToRemove.push({
            match_id: warning.match_id,
            profile_id: warning.profile_id
          })
          console.log(`Removing stale warning for ${warning.profile_id} - no longer has preference ${prefKey}`)
        }
      }

      // Remove stale warnings
      if (warningsToRemove.length > 0) {
        for (const warning of warningsToRemove) {
          const { error: deleteError } = await supabaseClient
            .from('inactivity_warnings')
            .delete()
            .eq('match_id', warning.match_id)
            .eq('profile_id', warning.profile_id)
            .eq('status', 'pending')

          if (deleteError) {
            console.error('Error removing stale warning:', deleteError)
          }
        }
        console.log(`Removed ${warningsToRemove.length} stale pending warnings`)
      } else {
        console.log('No stale warnings to remove')
      }
    }

    // ==========================================
    // PHASE 2: Day 7 Auto-Removal
    // ==========================================

    // Find participants inactive for 7+ days with pending warnings
    const { data: day7Participants, error: day7Error } = await supabaseClient
      .from('match_participants')
      .select(`
        match_id,
        profile_id,
        last_interaction_at,
        matches!inner(id, activity_id, circle_id)
      `)
      .lte('last_interaction_at', sevenDaysAgo.toISOString())

    if (day7Error) {
      console.error('Error fetching day 7 participants:', day7Error)
    } else if (day7Participants && day7Participants.length > 0) {
      console.log(`Found ${day7Participants.length} participants to potentially remove`)

      // Check which ones have pending warnings
      const { data: pendingWarnings } = await supabaseClient
        .from('inactivity_warnings')
        .select('match_id, profile_id')
        .eq('status', 'pending')

      const pendingWarningSet = new Set(
        pendingWarnings?.map(w => `${w.match_id}:${w.profile_id}`) || []
      )

      const participantsWithWarnings = day7Participants.filter((p: any) => {
        const key = `${p.match_id}:${p.profile_id}`
        return pendingWarningSet.has(key)
      })

      console.log(`${participantsWithWarnings.length} have pending warnings`)

      // For each participant, check if they have upcoming events
      const participantsToRemove: Array<{ match_id: string; profile_id: string }> = []

      for (const participant of participantsWithWarnings) {
        // Check for upcoming events in this match where this person is a participant
        const { data: upcomingEvents, error: eventsError } = await supabaseClient
          .from('events')
          .select(`
            id,
            scheduled_date,
            event_participants!inner(profile_id)
          `)
          .eq('match_id', participant.match_id)
          .eq('event_participants.profile_id', participant.profile_id)
          .gte('scheduled_date', now.toISOString())
          .eq('status', 'scheduled')

        if (eventsError) {
          console.error('Error checking events:', eventsError)
          continue
        }

        const hasUpcomingEvents = upcomingEvents && upcomingEvents.length > 0

        if (!hasUpcomingEvents) {
          participantsToRemove.push({
            match_id: participant.match_id,
            profile_id: participant.profile_id
          })
        } else {
          console.log(
            `Skipping removal for ${participant.profile_id} - has ${upcomingEvents.length} upcoming events`
          )
        }
      }

      if (participantsToRemove.length > 0) {
        console.log(`Removing ${participantsToRemove.length} inactive participants`)

        // Remove participants from matches
        for (const participant of participantsToRemove) {
          // First, get all events for this match that this user is participating in
          const { data: userEvents } = await supabaseClient
            .from('event_participants')
            .select('event_id, events!inner(match_id)')
            .eq('profile_id', participant.profile_id)
            .eq('events.match_id', participant.match_id)

          // Remove from event_participants for all events in this match
          if (userEvents && userEvents.length > 0) {
            const eventIds = userEvents.map((e: any) => e.event_id)
            const { error: eventDeleteError } = await supabaseClient
              .from('event_participants')
              .delete()
              .eq('profile_id', participant.profile_id)
              .in('event_id', eventIds)

            if (eventDeleteError) {
              console.error('Error removing from event_participants:', eventDeleteError)
            } else {
              console.log(`Removed participant ${participant.profile_id} from ${eventIds.length} events`)
            }
          }

          // Delete from match_participants
          const { error: deleteError } = await supabaseClient
            .from('match_participants')
            .delete()
            .eq('match_id', participant.match_id)
            .eq('profile_id', participant.profile_id)

          if (deleteError) {
            console.error('Error removing participant:', deleteError)
          } else {
            // Update warning status to 'removed'
            await supabaseClient
              .from('inactivity_warnings')
              .update({ status: 'removed' })
              .eq('match_id', participant.match_id)
              .eq('profile_id', participant.profile_id)
              .eq('status', 'pending')

            console.log(`Removed participant ${participant.profile_id} from match ${participant.match_id}`)
          }
        }
      } else {
        console.log('No participants to remove')
      }
    }

    // Clean up old resolved/removed warnings (older than 30 days)
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
    const { error: cleanupError } = await supabaseClient
      .from('inactivity_warnings')
      .delete()
      .in('status', ['resolved', 'removed'])
      .lt('created_at', thirtyDaysAgo.toISOString())

    if (cleanupError) {
      console.error('Error cleaning up old warnings:', cleanupError)
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Inactivity cleanup completed',
        timestamp: now.toISOString()
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Fatal error in inactivity cleanup:', error)
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
