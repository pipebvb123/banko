-- ============================================================
-- BANKO.CL — MODELO DE MONETIZACIÓN + INSTITUCIONES
-- Ejecuta este script en Supabase > SQL Editor
--
-- Cubre:
--   1. instituciones          → una fila por institución financiera (plan de cobro, correo de contacto)
--   2. billing_events         → registro de cobros (Plan A/B/C) sin pasarela de pago integrada aún
--   3. email_notificaciones   → cola de correos HTML a instituciones (envío real se conecta después)
--   4. suscripciones          → suscripción mensual de instituciones (mes 1 gratis, mes 2 50%, mes 3+ 100%)
-- ============================================================

-- 1. Instituciones financieras
CREATE TABLE IF NOT EXISTS public.instituciones (
  id             UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  nombre         TEXT        NOT NULL UNIQUE,
  tipo           TEXT,                          -- factoring | leasing | capital | credito
  contacto_email TEXT,                          -- null hasta que se solicite/confirme con la institución
  plan           TEXT        DEFAULT 'B',       -- 'A' | 'B' | 'C' (ver modelo de monetización)
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.instituciones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_insert_instituciones" ON public.instituciones
  FOR INSERT WITH CHECK (true);

CREATE POLICY "allow_select_instituciones" ON public.instituciones
  FOR SELECT USING (true);

CREATE POLICY "allow_admin_update_instituciones" ON public.instituciones
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid())
  );

-- 2. Billing events — trackea cada cobro sin necesidad de pasarela de pago todavía
CREATE TABLE IF NOT EXISTS public.billing_events (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  institucion  TEXT        NOT NULL,
  solicitud_id UUID        REFERENCES public.solicitudes(id) ON DELETE SET NULL,
  tipo_evento  TEXT        NOT NULL,   -- 'solicitud_enviada' | 'operacion_cursada' | 'comision_operacion_cursada' | 'suscripcion_mensual'
  monto        NUMERIC,
  moneda       TEXT        DEFAULT 'CLP',
  estado_pago  TEXT        DEFAULT 'pendiente',  -- 'pendiente' | 'facturado' | 'pagado' | 'no_facturable'
  plan         TEXT                    -- 'A' | 'B' | 'C' — copia del plan vigente al momento del evento
);

ALTER TABLE public.billing_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_insert_billing_events" ON public.billing_events
  FOR INSERT WITH CHECK (true);

CREATE POLICY "allow_admin_select_billing_events" ON public.billing_events
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid())
  );

CREATE POLICY "allow_admin_update_billing_events" ON public.billing_events
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid())
  );

-- 3. Cola de correos HTML hacia instituciones (envío real vía Resend/SendGrid pendiente de credenciales)
CREATE TABLE IF NOT EXISTS public.email_notificaciones (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  institucion  TEXT        NOT NULL,
  destinatario TEXT,                    -- null si aún no tenemos el correo de la institución
  asunto       TEXT,
  cuerpo_html  TEXT,
  estado       TEXT        DEFAULT 'pendiente_envio'  -- 'pendiente_envio' | 'pendiente_correo_institucion' | 'enviado' | 'error'
);

ALTER TABLE public.email_notificaciones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_insert_email_notificaciones" ON public.email_notificaciones
  FOR INSERT WITH CHECK (true);

CREATE POLICY "allow_admin_select_email_notificaciones" ON public.email_notificaciones
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid())
  );

CREATE POLICY "allow_admin_update_email_notificaciones" ON public.email_notificaciones
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid())
  );

-- 4. Suscripción mensual de instituciones (rango 2-3M CLP · mes 1 gratis, mes 2 50%, mes 3+ 100%)
CREATE TABLE IF NOT EXISTS public.suscripciones (
  id             UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  institucion    TEXT        NOT NULL UNIQUE,
  monto_mensual  NUMERIC     NOT NULL,   -- 2.000.000 - 3.000.000 CLP acordado con la institución
  fecha_inicio   DATE        NOT NULL DEFAULT CURRENT_DATE,
  estado         TEXT        DEFAULT 'activa',  -- 'activa' | 'pausada' | 'cancelada'
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.suscripciones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_admin_all_suscripciones" ON public.suscripciones
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid())
  );

-- ============================================================
-- Nota sobre el cálculo del cobro mensual de suscripción
-- (mes 1 = gratis, mes 2 = 50%, mes 3 en adelante = 100%):
-- el helper `calcularMontoSuscripcion(fechaInicio, montoMensual)` vive en
-- admin/dashboard.html y se debe llamar en el momento de generar el
-- billing_event mensual (tipo_evento = 'suscripcion_mensual'). No hay cobro
-- automático recurrente porque aún no hay pasarela de pago integrada.
-- ============================================================
