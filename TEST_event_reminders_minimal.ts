// MINIMAL TEST VERSION - Event Reminders
// This version will ALWAYS log something, even if it crashes
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  console.log('========================================')
  console.log('TEST: Function started!')
  console.log('Current time:', new Date().toISOString())
  console.log('========================================')

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log('✓ Supabase client created')

    // Test 1: Can we query profiles at all?
    console.log('\nTest 1: Querying profiles...')
    const { data: allProfiles, error: profilesError } = await supabaseClient
      .from('profiles')
      .select('id, name, event_reminders_enabled, timezone')
      .limit(5)

    if (profilesError) {
      console.error('✗ Profiles query error:', profilesError)
      throw profilesError
    }

    console.log('✓ Found profiles:', allProfiles?.length || 0)
    console.log('Profiles:', allProfiles)

    // Test 2: Can we query events?
    console.log('\nTest 2: Querying events...')
    const { data: allEvents, error: eventsError } = await supabaseClient
      .from('events')
      .select('id, scheduled_date, status')
      .limit(5)

    if (eventsError) {
      console.error('✗ Events query error:', eventsError)
      throw eventsError
    }

    console.log('✓ Found events:', allEvents?.length || 0)
    console.log('Events:', allEvents)

    // Test 3: Can we query activities?
    console.log('\nTest 3: Querying activities...')
    const { data: allActivities, error: activitiesError } = await supabaseClient
      .from('activities')
      .select('id, name')
      .limit(5)

    if (activitiesError) {
      console.error('✗ Activities query error:', activitiesError)
      throw activitiesError
    }

    console.log('✓ Found activities:', allActivities?.length || 0)
    console.log('Activities:', allActivities)

    // Test 4: Can we join events with activities?
    console.log('\nTest 4: Joining events with activities...')
    const { data: eventsWithActivities, error: joinError } = await supabaseClient
      .from('events')
      .select(`
        id,
        scheduled_date,
        status,
        activities (
          name
        )
      `)
      .limit(5)

    if (joinError) {
      console.error('✗ Join query error:', joinError)
      throw joinError
    }

    console.log('✓ Joined events with activities:', eventsWithActivities?.length || 0)
    console.log('Result:', eventsWithActivities)

    console.log('\n========================================')
    console.log('ALL TESTS PASSED!')
    console.log('========================================')

    return new Response(JSON.stringify({
      success: true,
      message: 'All tests passed!',
      results: {
        profiles: allProfiles?.length || 0,
        events: allEvents?.length || 0,
        activities: allActivities?.length || 0,
        joined: eventsWithActivities?.length || 0
      }
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (error) {
    console.error('\n========================================')
    console.error('FATAL ERROR:', error)
    console.error('Error message:', error.message)
    console.error('Error stack:', error.stack)
    console.error('========================================')

    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      stack: error.stack
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500
    })
  }
})
