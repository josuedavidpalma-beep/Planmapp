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

    const { record, old_record, type, table } = payload;
    
    // Safety check: only handle INSERTS
    if (type !== 'INSERT' || !record) {
       return new Response(JSON.stringify({ status: "ignored", reason: "not an insert" }), { headers: reqCorsHeaders })
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let fcmTokensArray: string[] = [];
    let notificationPayload: any = null;

    if (table === 'messages') {
        const planId = record.plan_id;
        const senderId = record.user_id;
        const content = record.content;
        const senderName = record.metadata?.sender_name || 'Alguien';
        const isSystem = record.is_system_message || false;

        if (isSystem) {
           return new Response(JSON.stringify({ status: "ignored", reason: "system message" }), { headers: reqCorsHeaders })
        }

        const { data: members } = await supabaseClient.from('plan_members').select('user_id').eq('plan_id', planId).neq('user_id', senderId);
        if (!members || members.length === 0) return new Response(JSON.stringify({ status: "ok", notified: 0 }), { headers: reqCorsHeaders });
        
        const memberIds = members.map(m => m.user_id);
        const { data: tokens } = await supabaseClient.from('fcm_tokens').select('token').in('user_id', memberIds);
        if (!tokens || tokens.length === 0) return new Response(JSON.stringify({ status: "ok", notified: 0 }), { headers: reqCorsHeaders });
        
        fcmTokensArray = tokens.map(t => t.token);
        
        const { data: planData } = await supabaseClient.from('plans').select('title').eq('id', planId).single();
        const planTitle = planData?.title || 'Un plan';

        notificationPayload = {
          notification: { title: `${senderName} en ${planTitle}`, body: content },
          data: { route: `/plan/${planId}`, type: 'chat_message' },
          tokens: fcmTokensArray,
        };

    } else if (table === 'plan_members') {
        // Internal Invitations (or direct additions)
        const recipientId = record.user_id;
        const planId = record.plan_id;
        const status = record.status;
        
        // Only notify if they are truly invited (pending)
        if (status !== 'pending') {
             return new Response(JSON.stringify({ status: "ignored", reason: "Not a pending invite" }), { headers: reqCorsHeaders })
        }

        // Fetch tokens for this SPECIFIC recipient
        const { data: tokens } = await supabaseClient.from('fcm_tokens').select('token').eq('user_id', recipientId);
        if (!tokens || tokens.length === 0) return new Response(JSON.stringify({ status: "ok", notified: 0 }), { headers: reqCorsHeaders });
        fcmTokensArray = tokens.map(t => t.token);

        // Fetch plan title
        const { data: planData } = await supabaseClient.from('plans').select('title').eq('id', planId).single();
        const planTitle = planData?.title || 'Planmapp';

        notificationPayload = {
          notification: { title: `¡Nueva Invitación! 🎉`, body: `Te han invitado al plan '${planTitle}'` },
          data: { route: `/`, type: 'plan_invite' }, // Send them home to see the mailbox
          tokens: fcmTokensArray,
        };
    } else if (table === 'notifications') {
        const recipientId = record.user_id;
        const title = record.title || 'Nueva Notificación';
        const body = record.body || 'Tienes una nueva actualización en Planmapp.';
        const route = record.route || '/';
        const typeNotif = record.type || 'general';

        // Fetch tokens for this recipient
        const { data: tokens } = await supabaseClient.from('fcm_tokens').select('token').eq('user_id', recipientId);
        if (!tokens || tokens.length === 0) return new Response(JSON.stringify({ status: "ok", notified: 0 }), { headers: reqCorsHeaders });
        fcmTokensArray = tokens.map(t => t.token);

        notificationPayload = {
          notification: { title: title, body: body },
          data: { route: route, type: typeNotif },
          tokens: fcmTokensArray,
        };
    } else if (table === 'polls') {
        const planId = record.plan_id;
        const creatorId = record.creator_id;
        const question = record.question || 'Nueva encuesta';
        
        const { data: members } = await supabaseClient.from('plan_members').select('user_id').eq('plan_id', planId).neq('user_id', creatorId);
        if (!members || members.length === 0) return new Response(JSON.stringify({ status: "ok", notified: 0 }), { headers: reqCorsHeaders });
        
        const memberIds = members.map(m => m.user_id);
        const { data: tokens } = await supabaseClient.from('fcm_tokens').select('token').in('user_id', memberIds);
        if (!tokens || tokens.length === 0) return new Response(JSON.stringify({ status: "ok", notified: 0 }), { headers: reqCorsHeaders });
        fcmTokensArray = tokens.map(t => t.token);

        const { data: planData } = await supabaseClient.from('plans').select('title').eq('id', planId).single();
        const planTitle = planData?.title || 'Un plan';

        notificationPayload = {
          notification: { title: `Nueva Encuesta en ${planTitle} 📊`, body: question },
          data: { route: `/plan/${planId}`, type: 'new_poll' },
          tokens: fcmTokensArray,
        };
    } else {
        return new Response(JSON.stringify({ status: "ignored", reason: "Unsupported table: " + table }), { headers: reqCorsHeaders })
    }

    if (!notificationPayload || fcmTokensArray.length === 0) {
         return new Response(JSON.stringify({ status: "ok", notified: 0 }), { headers: reqCorsHeaders });
    }

    const response = await admin.messaging().sendEachForMulticast(notificationPayload);
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
