// ULTRA MINIMAL - Logs FIRST, before anything else
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const startTime = new Date()
  let supabaseClient: any = null

  try {
    // Step 1: Create client FIRST (must succeed for logging)
    supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Step 2: IMMEDIATELY log that we started
    await supabaseClient
      .from('function_execution_logs')
      .insert({
        function_name: 'event-reminders',
        step: 'STARTUP',
        status: 'SUCCESS',
        message: 'Function started successfully!',
        data: {
          utc_time: startTime.toISOString(),
          utc_hour: startTime.getUTCHours(),
          env_check: {
            has_supabase_url: !!Deno.env.get('SUPABASE_URL'),
            has_service_key: !!Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
            has_onesignal_key: !!Deno.env.get('ONESIGNAL_REST_API_KEY')
          }
        }
      })

    console.log('✓ Startup log written to database')

    // Step 3: Return immediately (don't do anything else yet)
    return new Response(JSON.stringify({
      success: true,
      message: 'Ultra minimal test - check function_execution_logs table!',
      timestamp: startTime.toISOString()
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (error: any) {
    console.error('FATAL ERROR:', error)

    // Try to log the error if we have a client
    if (supabaseClient) {
      try {
        await supabaseClient
          .from('function_execution_logs')
          .insert({
            function_name: 'event-reminders',
            step: 'FATAL_ERROR',
            status: 'ERROR',
            message: 'Function crashed: ' + error.message,
            data: {
              error: error.message,
              stack: error.stack
            }
          })
      } catch (logError) {
        console.error('Could not log error:', logError)
      }
    }

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
