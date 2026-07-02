-- ============================================================
-- Tabla para registrar visitas al sitio multy.cl
-- Ejecutar en Supabase SQL Editor
-- ============================================================

create table if not exists public.page_visits (
  id         uuid default gen_random_uuid() primary key,
  session_id text,
  page       text default '/',
  referrer   text,
  created_at timestamptz default now()
);

alter table public.page_visits enable row level security;

drop policy if exists "Anyone can insert visits" on public.page_visits;
drop policy if exists "Admins can read visits"   on public.page_visits;

-- Cualquier visitante (sin sesión) puede registrar su visita
create policy "Anyone can insert visits"
on public.page_visits for insert
with check (true);

-- Solo administradores pueden ver las visitas
create policy "Admins can read visits"
on public.page_visits for select
using (
  exists (select 1 from public.admins where user_id = auth.uid())
);
