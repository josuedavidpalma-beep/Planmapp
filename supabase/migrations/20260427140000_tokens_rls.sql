-- Permitir a Super Admin insertar y leer todos los tokens (Super Admin RLS)
CREATE POLICY "SuperAdmin all on tokens" 
ON public.restaurant_tokens 
FOR ALL TO authenticated 
USING (auth.email() = 'josuedavidpalma@gmail.com') 
WITH CHECK (auth.email() = 'josuedavidpalma@gmail.com');
