-- Datos reales extraídos de la Agenda Idartes para poblar la App inmediatamente.

INSERT INTO public.events (title, description, date, end_date, location, address, category, image_url, source_url, contact_info)
VALUES 
(
  'Vagos Fest', 
  'Un festival lleno de música y expresiones artísticas alternativas.',
  '2026-02-05', 
  '2026-02-07', 
  'La Media Torta', 
  'Cl. 18 #1-05E, Bogotá', 
  'music', 
  'https://images.unsplash.com/photo-1533174072545-e8d4aa97edf9?auto=format&fit=crop&q=80&w=800', 
  'https://www.idartes.gov.co/es/agenda/festival/vagos-fest',
  'contactenos@idartes.gov.co'
),
(
  'Tortazo: Músicas Campesinas', 
  'Celebración de las raíces musicales del campo colombiano al aire libre.',
  '2026-02-10', 
  '2026-02-10', 
  'La Media Torta', 
  'Cl. 18 #1-05E, Bogotá', 
  'culture', 
  'https://images.unsplash.com/photo-1516280440614-6697288d5d38?auto=format&fit=crop&q=80&w=800', 
  'https://www.idartes.gov.co/es/agenda/concierto/tortazo-musicas-campesinas',
  'info@idartes.gov.co'
),
(
  'Obra: Aurora y la Muerte', 
  'Una puesta en escena conmovedora sobre la vida y el más allá.',
  '2026-02-12', 
  '2026-02-15', 
  'Teatro El Parque', 
  'Cra. 5 #36-05, Bogotá', 
  'culture', 
  'https://images.unsplash.com/photo-1503095392237-7362e3770517?auto=format&fit=crop&q=80&w=800', 
  'https://www.idartes.gov.co/es/agenda/obra-de-teatro/aurora-y-la-muerte',
  'taquilla@teatroelparque.gov.co'
),
(
  'El Lenguaje de los Árboles', 
  'Experiencia inmersiva que conecta arte y naturaleza.',
  '2026-02-18', 
  '2026-02-18', 
  'Jardín Botánico de Bogotá', 
  'Av. calle 63 # 68-95', 
  'outdoors', 
  'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&q=80&w=800', 
  'https://www.idartes.gov.co/es/agenda/obra-de-teatro/el-lenguaje-de-los-arboles',
  'contacto@jbb.gov.co'
),
(
  'Noche de Jazz: Cinemateca', 
  'Fusión de cine y jazz en vivo en el corazón de Bogotá.',
  '2026-02-20', 
  '2026-02-20', 
  'Cinemateca de Bogotá', 
  'Cra. 3 #19-10', 
  'music', 
  'https://images.unsplash.com/photo-1511192336575-5a79af67a629?auto=format&fit=crop&q=80&w=800', 
  'https://cinematecadebogota.gov.co',
  'info@cinemateca.gov.co'
);
