// Edge Function: Stay Interested
// Called when a user clicks the "Stay Interested" button
// Updates last_interaction_at and resolves inactivity warnings

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface StayInterestedRequest {
  matchId: string
  profileId: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

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
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400
        }
      )
    }

    // SECURITY: Verify JWT and ensure user can only update their own data
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing Authorization header'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 401
        }
      )
    }

    // Create Supabase client with service role for admin operations
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Create a client with the user's JWT to verify authentication
    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader }
        }
      }
    )

    // Verify the user from JWT
    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser()

    if (authError || !user) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Invalid or expired authentication token'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 401
        }
      )
    }

    // SECURITY: Ensure the authenticated user matches the profileId
    if (user.id !== profileId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Unauthorized: You can only update your own interaction status'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 403
        }
      )
    }

    console.log('Stay interested request:', { matchId, profileId, authenticatedUser: user.id })

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
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
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
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
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
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})
