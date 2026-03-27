import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

// Constants
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
// GCP Service Account for FCM (You must add this to Supabase Vault/Secrets)
const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')!

serve(async (req) => {
  try {
    const payload = await req.json();
    console.log("Processing time-reminder:", payload);

    const { target_user_id, title, body, data } = payload;
    
    if (!target_user_id) throw new Error("target_user_id is required");

    // 1. Initialize Supabase Admin Client
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 2. Fetch User FCM Token
    const { data: tokens, error } = await supabaseAdmin
        .from('fcm_tokens')
        .select('token')
        .eq('user_id', target_user_id);

    if (error || !tokens || tokens.length === 0) {
        console.log(`No tokens found for user ${target_user_id}`);
        return new Response(JSON.stringify({ message: "No tokens found" }), { headers: { "Content-Type": "application/json" } });
    }

    // 3. Send via Legacy HTTP or HTTP v1 (Simplified Legacy for demo if FCM_SERVER_KEY is used)
    let successCount = 0;
    for (const row of tokens) {
        const fcmRes = await fetch('https://fcm.googleapis.com/fcm/send', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `key=${FCM_SERVER_KEY}`
            },
            body: JSON.stringify({
                to: row.token,
                notification: {
                    title: title || "Planmapp",
                    body: body || "Tienes una nueva actualización en tu plan.",
                    sound: "default"
                },
                data: data || {}
            })
        });

        if (fcmRes.ok) successCount++;
    }

    return new Response(
      JSON.stringify({ success: true, sent: successCount }),
      { headers: { "Content-Type": "application/json" } },
    )
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 400,
    })
  }
})
