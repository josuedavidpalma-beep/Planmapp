-- INSTRUCCIONES:
-- Copia y pega este código en el Editor SQL de Supabase y ejecútalo (Run).
-- Si funciona, deberías ver este evento en la app inmediatamente.

INSERT INTO public.events (
  title, 
  description, 
  date, 
  location, 
  category, 
  image_url, 
  source_url
) VALUES (
  'Evento de Prueba: ¡Fiesta en Bogotá!', 
  'Este es un evento de prueba para verificar que la app conecta correctamente con la base de datos.', 
  '2026-02-01', 
  'Bogotá, Zona T', 
  'party', 
  'https://images.unsplash.com/photo-1566737236500-c8ac43014a67?auto=format&fit=crop&q=80&w=800', 
  'https://google.com'
);
