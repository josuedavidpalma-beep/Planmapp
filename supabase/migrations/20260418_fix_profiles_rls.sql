-- Permite a todos los usuarios autenticados leer los perfiles públicos de los demás.
-- Esto soluciona el fallo donde el Chat no podía leer el nombre de tu novia (y devolvía "Miembro" por seguridad).

CREATE POLICY "Allow public read access to profiles" 
ON public.profiles 
FOR SELECT 
USING (
    auth.role() = 'authenticated'
    OR auth.role() = 'anon'
);
