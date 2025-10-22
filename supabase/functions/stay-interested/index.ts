// Edge Function: Stay Interested
// Called when a user clicks the "Stay Interested" button
// Updates last_interaction_at and resolves inactivity warnings

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface StayInterestedRequest {
  matchId: string
  profileId: string
}

serve(async (req) => {
  try {
    // Parse request body
    const { matchId, profileId }: StayInterestedRequest = await req.json()

    if (!matchId || !profileId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required fields: matchId and profileId'
        }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 400
        }
      )
    }

    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log('Stay interested request:', { matchId, profileId })

    // Update last_interaction_at in match_participants
    const { error: updateError } = await supabaseClient
      .from('match_participants')
      .update({
        last_interaction_at: new Date().toISOString()
      })
      .eq('match_id', matchId)
      .eq('profile_id', profileId)

    if (updateError) {
      console.error('Error updating last_interaction_at:', updateError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to update interaction timestamp'
        }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 500
        }
      )
    }

    // Resolve any pending inactivity warnings
    const { error: warningError } = await supabaseClient
      .from('inactivity_warnings')
      .update({
        status: 'resolved'
      })
      .eq('match_id', matchId)
      .eq('profile_id', profileId)
      .eq('status', 'pending')

    if (warningError) {
      console.error('Error resolving warning:', warningError)
      // Don't fail the request if warning update fails
    }

    console.log('Successfully updated interaction timestamp and resolved warnings')

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Interaction timestamp updated successfully'
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in stay-interested function:', error)
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
