// Edge Function: Send Report Alert Email
// Sends email notification to admin when a new report is created
// Triggered automatically via database webhook

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform',
}

// Admin email (configure in Supabase environment variables)
const ADMIN_EMAIL = Deno.env.get('ADMIN_EMAIL') || 'admin@example.com'

// Email service configuration (using Resend as example)
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

interface ReportAlert {
  reportId: string
  reporterName: string
  reportedType: string
  reportedId: string
  reasonCategory: string
  reasonDetails?: string
  createdAt: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    // Parse request body
    const { record } = await req.json()

    if (!record) {
      return new Response(
        JSON.stringify({ success: false, error: 'No record provided' }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400
        }
      )
    }

    console.log('[send-report-alert] New report:', record.id)

    // Create Supabase client to fetch reporter details
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get reporter profile
    const { data: reporter, error: reporterError } = await supabaseClient
      .from('profiles')
      .select('name, email')
      .eq('id', record.reporter_id)
      .single()

    if (reporterError) {
      console.error('Error fetching reporter:', reporterError)
    }

    const reporterName = reporter?.name || 'Unknown User'

    // Get context about what was reported
    let reportedContext = ''
    if (record.reported_type === 'user') {
      const { data: reportedUser } = await supabaseClient
        .from('profiles')
        .select('name')
        .eq('id', record.reported_id)
        .single()

      reportedContext = reportedUser?.name || record.reported_id
    } else {
      reportedContext = `${record.reported_type} (ID: ${record.reported_id})`
    }

    // Build email content
    const emailSubject = `🚨 New Report: ${record.reason_category}`

    const emailBody = `
A new report has been submitted in Friendle.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 REPORT DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Report ID: ${record.id}
Status: ${record.status}
Created: ${new Date(record.created_at).toLocaleString()}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 REPORTER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Name: ${reporterName}
ID: ${record.reporter_id}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 REPORTED CONTENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Type: ${record.reported_type}
Target: ${reportedContext}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ REASON
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Category: ${record.reason_category}
${record.reason_details ? `Details: ${record.reason_details}` : '(No additional details provided)'}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 REVIEW IN SUPABASE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

View report in Supabase Dashboard:
${Deno.env.get('SUPABASE_URL')}/project/_/editor

Or run this SQL to get full context:
SELECT get_report_context('${record.id}');

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

To update this report's status:

UPDATE reports
SET status = 'under_review',
    admin_notes = 'Your notes here',
    reviewed_by = 'your-admin-id',
    reviewed_at = NOW()
WHERE id = '${record.id}';
`

    // Send email via Resend (you can swap for SendGrid, Postmark, etc.)
    if (RESEND_API_KEY) {
      console.log('[send-report-alert] Sending email via Resend...')

      const resendResponse = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${RESEND_API_KEY}`
        },
        body: JSON.stringify({
          from: 'Friendle Reports <onboarding@resend.dev>',
          to: [ADMIN_EMAIL],
          subject: emailSubject,
          text: emailBody,
        })
      })

      if (!resendResponse.ok) {
        const errorText = await resendResponse.text()
        console.error('Resend API error:', errorText)
        throw new Error(`Failed to send email: ${errorText}`)
      }

      const resendResult = await resendResponse.json()
      console.log('[send-report-alert] Email sent:', resendResult.id)

      return new Response(
        JSON.stringify({
          success: true,
          message: 'Report alert sent',
          emailId: resendResult.id
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        }
      )
    } else {
      // No email service configured, just log
      console.log('[send-report-alert] No RESEND_API_KEY configured, email not sent')
      console.log('Email would have been:', emailSubject, emailBody)

      return new Response(
        JSON.stringify({
          success: true,
          message: 'Report alert logged (email service not configured)',
          report: record
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

  } catch (error) {
    console.error('[send-report-alert] Fatal error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Unknown error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})
