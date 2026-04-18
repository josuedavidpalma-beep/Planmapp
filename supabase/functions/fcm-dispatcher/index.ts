import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import * as admin from "npm:firebase-admin@11.11.0"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"

// Setup Firebase Admin using the Service Account injected as an Environment Variable
let initialized = false;
try {
  const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}');
  if (serviceAccount.project_id) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    initialized = true;
    console.log("Firebase Admin Initialized successfully.");
  } else {
    console.error("FIREBASE_SERVICE_ACCOUNT is invalid or missing project_id.");
  }
} catch (error) {
  console.error("Failed to parse FIREBASE_SERVICE_ACCOUNT:", error);
}

const reqCorsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: reqCorsHeaders })
  }

  if (!initialized) {
    return new Response(JSON.stringify({ error: "Firebase not configured on server" }), { 
       headers: { ...reqCorsHeaders, 'Content-Type': 'application/json' },
       status: 500 
    });
  }

  try {
    const payload = await req.json()
    console.log("Webhook Payload Received:", payload);

    // This webhook expects an insertion mapped from the messages table
    const { record, old_record, type } = payload;
    
    // Safety check: only handle INSERTS
    if (type !== 'INSERT' || !record) {
       return new Response(JSON.stringify({ status: "ignored", reason: "not an insert" }), { headers: reqCorsHeaders })
    }

    const planId = record.plan_id;
    const senderId = record.user_id;
    const content = record.content;
    const senderName = record.metadata?.sender_name || 'Alguien';
    const isSystem = record.is_system_message || false;

    if (isSystem) {
       return new Response(JSON.stringify({ status: "ignored", reason: "system message" }), { headers: reqCorsHeaders })
    }

    // Connect to Supabase to fetch FCM tokens of members in this plan
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Get all members of the plan EXCEPT the sender
    const { data: members, error: memError } = await supabaseClient
       .from('plan_members')
       .select('user_id')
       .eq('plan_id', planId)
       .neq('user_id', senderId);

    if (memError || !members || members.length === 0) {
       console.log("No other members found to notify.");
       return new Response(JSON.stringify({ status: "ok", notified: 0 }), { headers: reqCorsHeaders });
    }

    const memberIds = members.map(m => m.user_id);

    // 2. Fetch FCM Tokens for these members
    const { data: tokens, error: tokError } = await supabaseClient
       .from('fcm_tokens')
       .select('token')
       .in('user_id', memberIds);

    if (tokError || !tokens || tokens.length === 0) {
       console.log("No FCM tokens found for members.");
       return new Response(JSON.stringify({ status: "ok", notified: 0 }), { headers: reqCorsHeaders });
    }

    const fcmTokensArray = tokens.map(t => t.token);
    
    // Fetch plan title for notification context
    const { data: planData } = await supabaseClient.from('plans').select('title').eq('id', planId).single();
    const planTitle = planData?.title || 'Un plan';

    // 3. Dispatch to Firebase Cloud Messaging using proper Multicast payload
    const messagePayload = {
      notification: {
        title: `${senderName} en ${planTitle}`,
        body: content,
      },
      data: {
        route: `/plan/${planId}`,
        type: 'chat_message'
      },
      tokens: fcmTokensArray,
    };

    const response = await admin.messaging().sendEachForMulticast(messagePayload);
    console.log(`Successfully sent message: ${response.successCount} successes, ${response.failureCount} failures.`);

    return new Response(JSON.stringify({ 
       status: "ok", 
       successCount: response.successCount,
       failureCount: response.failureCount 
    }), { headers: { ...reqCorsHeaders, 'Content-Type': 'application/json' }})

  } catch (err) {
    console.error("FCM Dispatcher Error:", err);
    return new Response(JSON.stringify({ error: err.message }), { 
       headers: { ...reqCorsHeaders, 'Content-Type': 'application/json' },
       status: 400 
    })
  }
})
