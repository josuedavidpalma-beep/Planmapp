-- Dummy events for Barranquilla to test Multi-City support
INSERT INTO public.events (title, description, date, end_date, location, address, category, image_url, source_url, contact_info, city)
VALUES 
(
  'Carnaval de las Artes', 
  'Un encuentro cultural con escritores, músicos y artistas internacionales.',
  '2026-02-12', 
  '2026-02-15', 
  'La Cueva', 
  'Cra. 43 #59-03, Barranquilla', 
  'culture', 
  'https://images.unsplash.com/photo-1568219656418-15c329312bf1?auto=format&fit=crop&q=80&w=800', 
  'https://carnavaldelasartes.com',
  'info@fundacionlacueva.org',
  'Barranquilla'
),
(
  'Concierto al Río', 
  'Música en vivo a orillas del Magdalena.',
  '2026-02-18', 
  '2026-02-18', 
  'Gran Malecón', 
  'Vía 40, Barranquilla', 
  'music', 
  'https://images.unsplash.com/photo-1459749411177-d4a4289fb1c5?auto=format&fit=crop&q=80&w=800', 
  '',
  '',
  'Barranquilla'
),
(
  'Ruta Gastronómica del Caribe', 
  'Degustación de los mejores fritos y platos típicos.',
  '2026-02-20', 
  '2026-02-22', 
  'Plaza de la Paz', 
  'Cll 53 con Cra 46', 
  'food', 
  'https://images.unsplash.com/photo-1606787366850-de6330128bfc?auto=format&fit=crop&q=80&w=800', 
  '',
  '',
  'Barranquilla'
);
