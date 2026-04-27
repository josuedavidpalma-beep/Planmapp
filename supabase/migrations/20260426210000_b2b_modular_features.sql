-- Migración: Añadir campos para modularidad A la Carta y Google Maps Harvester

ALTER TABLE public.restaurants 
ADD COLUMN IF NOT EXISTS maps_url TEXT,
ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '{
  "google_maps_reviews": false, 
  "menu_engineering": false, 
  "ai_insights": false, 
  "advanced_nps": false, 
  "date_filters": false
}'::jsonb;
