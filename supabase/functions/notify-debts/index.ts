import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

console.log("Notify-Debts CRON Trigger Active")

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })
  
  const authHeader = req.headers.get('Authorization');
  if (authHeader !== `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`) {
      console.warn("Unauthorized attempt to trigger CRON");
      return new Response('Unauthorized', { status: 403 });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Fetch pending debts from the unifide ledger (payment_trackers)
    // We join with `plans` to check the reminder configuration (frequency & channel)
    // We also join with `expenses` to know the title if it belongs to a split bill
    const { data: debts, error } = await supabaseClient
      .from('payment_trackers')
      .select(`
        id,
        amount_owe, 
        amount_paid,
        user_id, 
        description,
        created_at,
        last_notified_at,
        plans!inner (
           id,
           reminder_frequency_days,
           reminder_channel,
           creator_id
        )
      `)
      .eq('status', 'pending')
      .not('user_id', 'is', null) // Only actual registered users receive push
      .gt('amount_owe', 0) // Strictly debts with some amount

    if (error) throw error
    if (!debts || debts.length === 0) return new Response("No pending debts", { status: 200 })

    const notificationsToInsert = []
    const updatedDebtIds = []

    const now = new Date()

    for (const debt of debts) {
         const plan = debt.plans;
         // Ensure plan has activated push notifications
         if (plan.reminder_channel !== 'push' || !plan.reminder_frequency_days || plan.reminder_frequency_days <= 0) {
             continue;
         }

         // Calculate days elapsed since last notification (or creation date)
         const lastNotifiedDate = debt.last_notified_at ? new Date(debt.last_notified_at) : new Date(debt.created_at);
         const diffTime = Math.abs(now.getTime() - lastNotifiedDate.getTime());
         const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

         // If the required days have passed, queue the notification!
         if (diffDays >= plan.reminder_frequency_days) {
             const amountMissing = debt.amount_owe - (debt.amount_paid || 0);
             const debtTitle = debt.description && debt.description.trim() !== '' ? debt.description : "Gasto Unificado";
             
             notificationsToInsert.push({
                 user_id: debt.user_id,
                 title: '💸 Recordatorio de Pago',
                 body: `Tienes un saldo pendiente por Pagar de $${amountMissing.toLocaleString()} en "${debtTitle}". Por favor, revisa tu Dashboard Financiero para quedar al día.`,
                 type: 'general',
                 data: { action: 'debt_reminder', plan_id: plan.id, org_id: plan.creator_id, expense_id: debt.id }
             })
             
             updatedDebtIds.push(debt.id)
         }
    }

    // 2. Insert into notifications table (Trigger will auto-call FCM dispatcher)
    if (notificationsToInsert.length > 0) {
        const { error: insertErr } = await supabaseClient.from('notifications').insert(notificationsToInsert)
        if (insertErr) {
            console.error("Insertion error:", insertErr)
            throw insertErr
        }

        // 3. Mark the payment_trackers with the current timestamp so we don't spam them tomorrow if they haven't paid but the frequency is weekly!
        const { error: updateErr } = await supabaseClient
            .from('payment_trackers')
            .update({ last_notified_at: now.toISOString() })
            .in('id', updatedDebtIds)
            
        if (updateErr) {
            console.error("Failed to update last_notified_at:", updateErr)
        }
    }

    return new Response(JSON.stringify({ success: true, count: notificationsToInsert.length }), {
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error(error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
