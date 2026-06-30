-- ============================================================
-- Configuración de Supabase Storage para documentos de clientes
-- (información financiera y antecedentes legales)
--
-- Cómo ejecutarlo:
-- 1. Entra a supabase.com -> tu proyecto -> SQL Editor
-- 2. Pega todo este archivo y dale "Run"
-- ============================================================

-- 1. Crear el bucket privado (no público) para los documentos
insert into storage.buckets (id, name, public)
values ('documentos-clientes', 'documentos-clientes', false)
on conflict (id) do nothing;

-- 2. Limpiar políticas anteriores con el mismo nombre (por si se re-ejecuta)
drop policy if exists "Users can upload own docs" on storage.objects;
drop policy if exists "Users can view own docs" on storage.objects;
drop policy if exists "Users can delete own docs" on storage.objects;
drop policy if exists "Admins can view all docs" on storage.objects;

-- 3. Un cliente puede subir documentos solo dentro de su propia carpeta
--    (la carpeta raíz del archivo debe ser igual a su user_id)
create policy "Users can upload own docs"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'documentos-clientes'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- 4. Un cliente puede ver/listar solo sus propios documentos
create policy "Users can view own docs"
on storage.objects for select
to authenticated
using (
  bucket_id = 'documentos-clientes'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- 5. Un cliente puede eliminar solo sus propios documentos
create policy "Users can delete own docs"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'documentos-clientes'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- 6. Los administradores (tabla "admins") pueden ver los documentos de CUALQUIER cliente
create policy "Admins can view all docs"
on storage.objects for select
to authenticated
using (
  bucket_id = 'documentos-clientes'
  and exists (
    select 1 from public.admins where user_id = auth.uid()
  )
);
