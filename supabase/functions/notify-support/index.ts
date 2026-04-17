import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { ticket_id } = await req.json();

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const resendApiKey = Deno.env.get("RESEND_API_KEY");

    if (!resendApiKey) {
      throw new Error("Missing RESEND_API_KEY in Edge Function secrets.");
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Fetch the ticket
    const { data: ticket, error: ticketError } = await supabase
      .from("support_tickets")
      .select(`*, user:auth.users(email)`) // Fetch user email from auth schema
      .eq("id", ticket_id)
      .single();

    if (ticketError || !ticket) {
      throw new Error(`Ticket not found: ${ticketError?.message}`);
    }

    // Try to get user profile name
    const { data: profile } = await supabase
        .from("profiles")
        .select("display_name, full_name")
        .eq("id", ticket.user_id)
        .maybeSingle();

    const userName = profile?.display_name || profile?.full_name || "Un usuario";
    // WARNING: 'user' might be null depending on how the cross-schema join went, usually auth joins in supabase require special config or we just trust the profile email 
    // Wait, the auth schema join `auth.users(email)` will work with Service Role.
    // If it fails, fallback.
    const userEmail = ticket.user?.email || "Email Desconocido";

    const subject = `🚨 Planmapp Soporte: ${ticket.subject}`;
    const imageHtml = ticket.image_url 
      ? `<br><br><p><b>Imagen Adjunta:</b></p><img src="${ticket.image_url}" alt="Screenshot del error" style="max-width: 100%; border: 1px solid #ccc; border-radius: 8px;" />` 
      : "";

    const htmlBody = `
      <div style="font-family: sans-serif; padding: 20px; color: #333;">
        <h2>Ticket de Soporte ID: ${ticket.id}</h2>
        <p><strong>De:</strong> ${userName} (${userEmail} / ${ticket.user_id})</p>
        <p><strong>Fecha:</strong> ${new Date(ticket.created_at).toLocaleString()}</p>
        <hr />
        <h3>${ticket.subject}</h3>
        <p style="white-space: pre-wrap; background: #f9f9f9; padding: 15px; border-radius: 8px;">${ticket.description}</p>
        ${imageHtml}
      </div>
    `;

    // Dispatch via Resend API
    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${resendApiKey}`,
      },
      body: JSON.stringify({
        from: "Planmapp Support <noreply@planmapp.app>", // Ensure your Resend domain is verified or use onboarding@resend.dev
        to: ["josuedavidpalma@gmail.com"],
        reply_to: userEmail !== "Email Desconocido" ? userEmail : undefined,
        subject: subject,
        html: htmlBody,
      }),
    });

    if (!resendResponse.ok) {
        const errJson = await resendResponse.text();
        throw new Error(`Resend Error: ${errJson}`);
    }

    return new Response(JSON.stringify({ status: "success", ticket_id }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("Support Edge Function Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
