import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

console.log("Notify-Debts CRON Trigger Active")

serve(async (req) => {
  try {
    // This function can be triggered via pg_cron or pg_net inside supabase or via an external trigger.
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Find all 'pending' debts from active plans
    // Needs complex join to check if Plan's reminder setup is active
    const { data: debts, error } = await supabaseClient
      .from('expense_participant_status')
      .select(`
        amount_owed, 
        user_id, 
        expense_id,
        expenses!inner (
           title, 
           plan_id,
           plans ( reminderFrequencyDays )
        )
      `)
      .eq('status', 'pending')
      .is('is_paid', false)
      .not('user_id', 'is', null)

    if (error) throw error
    if (!debts || debts.length === 0) return new Response("No pending debts", { status: 200 })

    // In a production scenario, we'd check 'last_reminded_at' against 'reminderFrequencyDays'.
    // For this module, we simulate the grouping of push notifications.
    const notificationsToInsert = []

    for (const debt of debts) {
         notificationsToInsert.push({
             user_id: debt.user_id,
             title: '⚠️ Recordatorio de Pago',
             body: `Tienes un saldo pendiente por Pagar en "${debt.expenses.title}". Por favor, revisa tu Dashboard Financiero.`,
             type: 'general',
             data: { action: 'debt_reminder', expense_id: debt.expense_id }
         })
    }

    // Insert into notifications table (which the App will subscribe to or use as trigger for FCM)
    if (notificationsToInsert.length > 0) {
        const { error: insertErr } = await supabaseClient.from('notifications').insert(notificationsToInsert)
        if (insertErr) {
            console.error(insertErr)
            throw insertErr
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
