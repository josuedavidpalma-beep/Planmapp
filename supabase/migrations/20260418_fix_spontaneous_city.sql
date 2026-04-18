-- Actualiza todas las ciudades de local_events para que puedan aparecer en tu ciudad de prueba actual
-- Nota: En un futuro, el web scraper o API proveerá ciudades precisas, esto es para tu pruebas actuales

UPDATE public.local_events 
SET city = 'Barranquilla';

-- Si la fecha de algún evento es menor a hoy, empújala 10 días hacia adelante 
-- para evitar que el filtro de "eventos futuros" los oculte:
UPDATE public.local_events 
SET date = (CURRENT_DATE + interval '10 days')::date
WHERE date < CURRENT_DATE;
