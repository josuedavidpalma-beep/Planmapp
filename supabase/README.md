# Supabase Configuration & Edge Functions

This directory contains the server-side logic for PlanMapp using Supabase Edge Functions.

## 1. Prerequisites
- [Supabase CLI](https://supabase.com/docs/guides/cli) installed on your machine.
- A Supabase project created.

## 2. Setup

### Login and Link
Run these commands in your terminal (root of the project):

```bash
supabase login
supabase link --project-ref <YOUR_PROJECT_ID>
```

*(You can find your Project ID in the Supabase Dashboard URL: https://supabase.com/dashboard/project/<PROJECT_ID>)*

### Set Environment Variables (Secrets)
You must set the Gemini API Key for the OCR function to work:

```bash
supabase secrets set GEMINI_API_KEY=AIzaSy...
```

## 3. Deployment

### Deploy Edge Functions
To deploy the `analyze-receipt` function:

```bash
supabase functions deploy analyze-receipt --no-verify-jwt
```
*Note: We use `--no-verify-jwt` if you want to allow unauthenticated calls during testing, but ideally, you should enforce JWT verification (the default) and pass the user's token from the app.*

### Database Migrations
To apply the database schema changes (Notifications table, etc.), copy the content of `lib/features/notifications/data/schemas/01_notifications_schema.sql` into the Supabase Dashboard's **SQL Editor** and run it.

## 4. Usage in App
The app calls this function using:
```dart
Supabase.instance.client.functions.invoke('analyze-receipt', body: { ... });
```
