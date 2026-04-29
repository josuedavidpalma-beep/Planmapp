-- =============================================================================
-- SCRIPT: Retroactive Auto-Link Places Images to Existing Plans
-- Description: Ejecuta este script en el SQL Editor de Supabase para forzar
-- a que los planes ANTIGUOS busquen su imagen de Google Places.
-- =============================================================================

UPDATE public.plans p
SET image_url = (
    SELECT photo_reference 
    FROM public.cached_places cp
    WHERE (cp.name ILIKE p.location_name OR cp.name ILIKE '%' || p.location_name || '%' OR cp.name ILIKE '%' || p.title || '%')
    AND cp.photo_reference IS NOT NULL
    LIMIT 1
)
WHERE p.image_url IS NULL OR trim(p.image_url) = '';
