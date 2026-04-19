-- Primero eliminamos los eventos ficticios anteriores por si las moscas
DELETE FROM public.local_events 
WHERE event_name IN (
  'Central Park Café', 'Café de las Letras', 'El Gran Asador', 'Pueblito Paisa Food',
  'Neon Club', 'La Playa Rumbera', 'Sendero Ecológico', 'Rafting del Río',
  'Museo de Arte Moderno', 'Teatro Clásico'
);

-- Y los reinsertamos pero obligatoriamente en Barranquilla y con fecha en el futuro
INSERT INTO public.local_events (event_name, description, vibe_tag, city, latitude, longitude, image_url, visual_keyword, price_level, status, date)
VALUES 
  ('Central Park Café', 'Un rincón tranquilo ideal para leer un buen libro y probar café.', 'Chill/Café', 'Barranquilla', 11.0000, -74.8000, 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&q=80&w=800', 'cafe espresso', '$$', 'active', CURRENT_DATE + interval '10 days'),
  ('Café de las Letras', 'Música suave, ambiente relajado y una selección increíble de repostería.', 'Chill/Café', 'Barranquilla', 11.0010, -74.8010, 'https://images.unsplash.com/photo-1600093463592-8e36ae95ef56?auto=format&fit=crop&q=80&w=800', 'chill cafe', '$', 'active', CURRENT_DATE + interval '10 days'),
  ('El Gran Asador', 'Los mejores cortes de carne a la parrilla, con un ambiente familiar.', 'Comida/Gastro', 'Barranquilla', 11.0020, -74.8020, 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&q=80&w=800', 'grill meat food', '$$$', 'active', CURRENT_DATE + interval '10 days'),
  ('Pueblito Paisa Food', 'Cocina tradicional de la región, empanadas y mucho sabor.', 'Comida/Gastro', 'Barranquilla', 11.0030, -74.8030, 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&q=80&w=800', 'latin food', '$$', 'active', CURRENT_DATE + interval '10 days'),
  ('Neon Club', 'La mejor fiesta de la ciudad. Luces de neón y baile.', 'Rumba/Party', 'Barranquilla', 11.0040, -74.8040, 'https://images.unsplash.com/photo-1566737236500-c8ac43014a67?auto=format&fit=crop&q=80&w=800', 'neon nightclub', '$$', 'active', CURRENT_DATE + interval '10 days'),
  ('La Playa Rumbera', 'Ambiente tropical, música en vivo y fiesta playera.', 'Rumba/Party', 'Barranquilla', 11.0050, -74.8050, 'https://images.unsplash.com/photo-1545128485-c400e7702796?auto=format&fit=crop&q=80&w=800', 'beach party', '$$', 'active', CURRENT_DATE + interval '10 days'),
  ('Sendero Ecológico', 'Ruta de senderismo perfecto para actividad física.', 'Aventura/Outdoor', 'Barranquilla', 11.0060, -74.8060, 'https://images.unsplash.com/photo-1501504905252-473c47e087f8?auto=format&fit=crop&q=80&w=800', 'hiking trail', '$', 'active', CURRENT_DATE + interval '10 days'),
  ('Rafting del Río', 'Aventura acuática con instructores profesionales.', 'Aventura/Outdoor', 'Barranquilla', 11.0070, -74.8070, 'https://images.unsplash.com/photo-1537237858032-411bd1f5a5e3?auto=format&fit=crop&q=80&w=800', 'river rafting', '$$', 'active', CURRENT_DATE + interval '10 days'),
  ('Museo de Arte Moderno', 'Exposiciones interactivas de artistas.', 'Cine/Cultura', 'Barranquilla', 11.0080, -74.8080, 'https://images.unsplash.com/photo-1518998053901-5348d3961a04?auto=format&fit=crop&q=80&w=800', 'modern art museum', '$', 'active', CURRENT_DATE + interval '10 days'),
  ('Teatro Clásico', 'Obras de teatro clásicas y dramas intensos.', 'Cine/Cultura', 'Barranquilla', 11.0090, -74.8090, 'https://images.unsplash.com/photo-1507676184212-d0330a156f97?auto=format&fit=crop&q=80&w=800', 'theatre stage', '$$', 'active', CURRENT_DATE + interval '10 days')
ON CONFLICT DO NOTHING;
