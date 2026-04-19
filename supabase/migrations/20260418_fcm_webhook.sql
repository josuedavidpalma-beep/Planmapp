-- Migration: Connect public.messages to fcm-dispatcher webhook
-- Created at: 2026-04-18

CREATE OR REPLACE FUNCTION public.trigger_fcm_webhook()
RETURNS trigger AS $$
DECLARE
    webhook_url TEXT;
BEGIN
    -- Hardcoded URL para tu Edge Function
    webhook_url := 'https://pthiaalrizufhlplbjht.supabase.co/functions/v1/fcm-dispatcher';
    
    perform net.http_post(
        url := webhook_url,
        headers := jsonb_build_object(
            'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
            'type', TG_OP,
            'table', TG_TABLE_NAME,
            'schema', TG_TABLE_SCHEMA,
            'record', row_to_json(NEW),
            'old_record', null
        )
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- If pg_net is not enabled or fails, do not block the insert!
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS on_message_insert_fcm ON public.messages;
DROP TRIGGER IF EXISTS on_plan_members_insert_fcm ON public.plan_members;

-- Create Trigger for INSERTS on messages
CREATE TRIGGER on_message_insert_fcm
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.trigger_fcm_webhook();

-- Create Trigger for INSERTS on plan_members (for internal invitations)
CREATE TRIGGER on_plan_members_insert_fcm
AFTER INSERT ON public.plan_members
FOR EACH ROW
EXECUTE FUNCTION public.trigger_fcm_webhook();

-- Create Trigger for INSERTS on notifications (for in-app pinging)
DROP TRIGGER IF EXISTS on_notifications_insert_fcm ON public.notifications;
CREATE TRIGGER on_notifications_insert_fcm
AFTER INSERT ON public.notifications
FOR EACH ROW
EXECUTE FUNCTION public.trigger_fcm_webhook();

