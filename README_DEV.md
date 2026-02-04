# Planmapp Project - Developer Guide

## 1. Flutter Setup (App)
1.  **Install Flutter:** Ensure you have the Flutter SDK installed on your machine.
2.  **Dependencies:** Run the following command in this folder:
    ```bash
    flutter pub get
    ```
3.  **Run:**
    ```bash
    flutter run -d chrome  # For Web
    flutter run -d windows # For Windows
    ```

## 2. Environment Variables & Keys
The project connects to **Supabase** (Database) and **Google Gemini** (AI).
You need to ensure these keys are configured.

### Supabase
Used in: `lib/core/config/supabase_config.dart` (or `main.dart`) AND Python scripts.
- **URL:** [Insert your SUPABASE_URL here or share securely]
- **Anon Key:** [Insert your SUPABASE_KEY here or share securely]

### Gemini AI
Used in: `scripts/daily_events/scrape_events.py`
- **Key:** [Insert your GEMINI_API_KEY]

## 3. Automation (Event Scraper)
The script `scripts/daily_events/scrape_events.py` fetches events from the web.

**Setup Python:**
1. Install Python (checking "Add to PATH").
2. Install libraries:
   ```bash
   pip install requests beautifulsoup4 google-generativeai supabase
   ```

**Run Script:**
   ```bash
   # Set keys first (PowerShell example):
   $env:SUPABASE_URL="YOUR_URL"
   $env:SUPABASE_KEY="YOUR_KEY"
   $env:GEMINI_API_KEY="YOUR_KEY"

   python scripts/daily_events/scrape_events.py
   ```

## 4. Database Seeding (If starting fresh)
If the database is empty, run the SQL files in `supabase/migrations/` in the Supabase SQL Editor:
1. `create_events_table.sql`
2. `add_city_column.sql`
3. `seed_events.sql`
