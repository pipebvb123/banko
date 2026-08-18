-- ============================================================
-- Tabla para el formulario "Estado de situación de Multy"
-- (estado de situación financiera personal/empresarial del cliente)
-- Ejecutar en Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS public.estado_situacion (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    UUID        NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  data       JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.estado_situacion ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow_user_select_own_estado_situacion" ON public.estado_situacion;
DROP POLICY IF EXISTS "allow_user_insert_own_estado_situacion" ON public.estado_situacion;
DROP POLICY IF EXISTS "allow_user_update_own_estado_situacion" ON public.estado_situacion;
DROP POLICY IF EXISTS "allow_admin_select_estado_situacion"    ON public.estado_situacion;

-- El usuario solo puede ver, crear y actualizar su propio estado de situación
CREATE POLICY "allow_user_select_own_estado_situacion" ON public.estado_situacion
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "allow_user_insert_own_estado_situacion" ON public.estado_situacion
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "allow_user_update_own_estado_situacion" ON public.estado_situacion
  FOR UPDATE USING (auth.uid() = user_id);

-- Los administradores pueden ver el estado de situación de cualquier cliente
CREATE POLICY "allow_admin_select_estado_situacion" ON public.estado_situacion
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid())
  );
