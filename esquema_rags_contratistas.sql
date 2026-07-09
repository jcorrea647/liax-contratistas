-- esquema_rags_contratistas.sql
-- Tabla `rags` para LIAX Contratistas. Sin pgvector: los chunks son texto,
-- la búsqueda BM25 ocurre en el cliente (igual que LIAX educativo).

create table if not exists public.rags (
  id             text primary key,
  nombre         text not null,
  descripcion    text default '',
  nivel          text not null default 'contratista',   -- global | red | contratista
  contratista_id uuid references public.contratistas(id) on delete cascade,  -- null = mandante/global
  chunks         jsonb not null default '[]'::jsonb,     -- array de strings
  user_id        uuid,
  created_at     timestamptz default now(),
  updated_at     timestamptz default now()
);

-- ── RLS: el aislamiento real vive aquí, no en el JS ──────────────
alter table public.rags enable row level security;

-- LECTURA: un usuario ve los RAG globales (contratista_id null) + los de SU contratista.
-- Se asume una función auth helper que devuelve el contratista_id del usuario logueado.
create policy rags_select on public.rags
  for select using (
    contratista_id is null
    or contratista_id = public.current_contratista_id()
  );

-- ESCRITURA: solo el mandante puede tocar RAG globales; un contratista solo los suyos.
create policy rags_write on public.rags
  for all using (
    (contratista_id is null and public.is_mandante())
    or contratista_id = public.current_contratista_id()
  )
  with check (
    (contratista_id is null and public.is_mandante())
    or contratista_id = public.current_contratista_id()
  );

-- NOTA: current_contratista_id() e is_mandante() son helpers a definir según tu
-- modelo de perfiles (equivalente a colegio_id / rol del LIAX educativo).
