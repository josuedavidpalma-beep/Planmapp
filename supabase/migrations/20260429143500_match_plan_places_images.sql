-- =============================================================================
-- MIGRATION: Auto-Link Places Images to Plans
-- Description: Creates a trigger to automatically populate plan.image_url 
-- with a high-quality Google Places photo if the location name matches a 
-- known cached_place.
-- =============================================================================

-- 1. Create the matching function
CREATE OR REPLACE FUNCTION public.match_plan_image_from_places()
RETURNS TRIGGER AS $$
DECLARE
    matched_photo_ref text;
BEGIN
    -- Only attempt to match if the user didn't explicitly provide an image URL
    IF NEW.image_url IS NULL OR trim(NEW.image_url) = '' THEN
        
        -- Try to find an exact or fuzzy match in cached_places based on location_name
        -- Priority 1: Exact match on location_name
        SELECT photo_reference INTO matched_photo_ref
        FROM public.cached_places
        WHERE name ILIKE NEW.location_name 
        AND photo_reference IS NOT NULL
        LIMIT 1;

        -- Priority 2: Fuzzy match on location_name (contains)
        IF matched_photo_ref IS NULL AND NEW.location_name IS NOT NULL AND trim(NEW.location_name) != '' THEN
            SELECT photo_reference INTO matched_photo_ref
            FROM public.cached_places
            WHERE (name ILIKE '%' || NEW.location_name || '%' OR NEW.location_name ILIKE '%' || name || '%')
            AND photo_reference IS NOT NULL
            LIMIT 1;
        END IF;

        -- Priority 3: Fuzzy match on title
        IF matched_photo_ref IS NULL AND NEW.title IS NOT NULL AND trim(NEW.title) != '' THEN
            SELECT photo_reference INTO matched_photo_ref
            FROM public.cached_places
            WHERE (name ILIKE '%' || NEW.title || '%' OR NEW.title ILIKE '%' || name || '%')
            AND photo_reference IS NOT NULL
            LIMIT 1;
        END IF;

        -- If a photo reference was found, inject it into the plan
        IF matched_photo_ref IS NOT NULL THEN
            NEW.image_url := matched_photo_ref;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Attach the trigger to the plans table
DROP TRIGGER IF EXISTS trigger_match_plan_image ON public.plans;

CREATE TRIGGER trigger_match_plan_image
BEFORE INSERT OR UPDATE OF location_name, title, image_url ON public.plans
FOR EACH ROW
EXECUTE FUNCTION public.match_plan_image_from_places();
