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
        profiles!inner(id, name, onesignal_player_id),
        matches!inner(id, activity_id, circle_id)
      `)
      .lte('last_interaction_at', fiveDaysAgo.toISOString())
      .not('profiles.onesignal_player_id', 'is', null) // Has push notification enabled

    if (day5Error) {
      console.error('Error fetching day 5 participants:', day5Error)
    } else if (day5Participants && day5Participants.length > 0) {
      console.log(`Found ${day5Participants.length} participants to warn`)

      // Filter out those who already have pending warnings
      const { data: existingWarnings } = await supabaseClient
        .from('inactivity_warnings')
        .select('match_id, profile_id')
        .eq('status', 'pending')

      const warningSet = new Set(
        existingWarnings?.map(w => `${w.match_id}:${w.profile_id}`) || []
      )

      // Filter out participants who don't have matching preferences (removed activity from that circle)
      const participantsWithPreferences = []
      for (const participant of day5Participants) {
        const key = `${participant.match_id}:${participant.profile_id}`

        // Skip if already has pending warning
        if (warningSet.has(key)) {
          continue
        }

        // Check if user still has this activity in their preferences for this circle
        const { data: preference } = await supabaseClient
          .from('preferences')
          .select('id')
          .eq('profile_id', participant.profile_id)
          .eq('activity_id', participant.matches.activity_id)
          .eq('circle_id', participant.matches.circle_id)
          .limit(1)

        // Only warn if they still have the preference (match is visible to them)
        if (preference && preference.length > 0) {
          participantsWithPreferences.push(participant)
        } else {
          console.log(`Skipping warning for ${participant.profile_id} - no longer has preference for match ${participant.match_id}`)
        }
      }

      const participantsToWarn = participantsWithPreferences

      if (participantsToWarn.length > 0) {
        console.log(`Sending warnings to ${participantsToWarn.length} participants`)

        // Batch send notifications (max 2000 at a time per OneSignal docs)
        const batchSize = 2000
        for (let i = 0; i < participantsToWarn.length; i += batchSize) {
          const batch = participantsToWarn.slice(i, i + batchSize)
          const playerIds = batch
            .map((p: any) => p.profiles.onesignal_player_id)
            .filter((id: string | null) => id !== null)

          if (playerIds.length > 0) {
            // Send push notification via OneSignal
            try {
              const response = await fetch('https://onesignal.com/api/v1/notifications', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': `Basic ${ONESIGNAL_API_KEY}`
                },
                body: JSON.stringify({
                  app_id: ONESIGNAL_APP_ID,
                  include_player_ids: playerIds,
                  headings: { en: 'Still interested?' },
                  contents: {
                    en: "We noticed you haven't been active in your match lately. Tap to let us know you're still interested!"
                  },
                  data: {
                    type: 'inactivity_warning',
                    action: 'stay_interested'
                  }
                })
              })

              if (!response.ok) {
                console.error('OneSignal API error:', await response.text())
              } else {
                console.log(`Sent ${playerIds.length} notifications successfully`)
              }
            } catch (notifError) {
              console.error('Error sending notifications:', notifError)
            }
          }

          // Record warnings in database
          const warningsToInsert = batch.map((p: any) => ({
            match_id: p.match_id,
            profile_id: p.profile_id,
            status: 'pending'
          }))

          const { error: insertError } = await supabaseClient
            .from('inactivity_warnings')
            .insert(warningsToInsert)

          if (insertError) {
            console.error('Error inserting warnings:', insertError)
          }
        }
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
