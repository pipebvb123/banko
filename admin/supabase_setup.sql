-- ============================================================
-- BANKO.CL — ADMIN SYSTEM SETUP
-- Ejecuta este script en Supabase > SQL Editor
-- ============================================================

-- 1. Tabla de logs de actividad
CREATE TABLE IF NOT EXISTS public.activity_logs (
  id               UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  timestamp        TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  user_id          UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  session_id       TEXT        NOT NULL,
  tipo_comparacion TEXT,
  datos            JSONB,
  is_logged_in     BOOLEAN     DEFAULT FALSE,
  user_agent       TEXT
);

-- 2. Tabla de administradores
CREATE TABLE IF NOT EXISTS public.admins (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    UUID        REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  email      TEXT        NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admins         ENABLE ROW LEVEL SECURITY;

-- activity_logs: cualquiera puede insertar (para tracking anónimo y autenticado)
CREATE POLICY "allow_insert_activity" ON public.activity_logs
  FOR INSERT WITH CHECK (true);

-- activity_logs: solo admins pueden leer
CREATE POLICY "allow_admin_select_activity" ON public.activity_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid())
  );

-- admins: cada admin solo puede ver su propio registro (para verificación de acceso)
CREATE POLICY "allow_admin_select_self" ON public.admins
  FOR SELECT USING (auth.uid() = user_id);

-- ============================================================
-- AGREGAR UN ADMINISTRADOR
-- Pasos:
--   1. El usuario admin debe registrarse primero en el sitio
--      (o créalo en Supabase > Authentication > Users)
--   2. Copia su UUID desde Authentication > Users
--   3. Ejecuta el INSERT de abajo con su UUID y email
-- ============================================================

-- INSERT INTO public.admins (user_id, email)
-- VALUES ('PEGA-AQUI-EL-UUID-DEL-USUARIO', 'admin@tudominio.cl');

-- Ejemplo:
-- INSERT INTO public.admins (user_id, email)
-- VALUES ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'admin@banko.cl');
