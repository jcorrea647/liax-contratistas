-- ═══════════════════════════════════════════════════════════════════
-- LIAX CONTRATISTAS — Tanda 2: Agentes, sesiones, documentos, config
-- Portado FIEL del modelo real del educativo (agentes_custom,
-- agent_sesiones, documentos_chat, config), con colegio_id → contratista_id.
-- Ejecutar DESPUÉS de 00_modelo_base_contratistas.sql.
-- ═══════════════════════════════════════════════════════════════════

-- ── AGENTES CUSTOM (agentes de prevención: Redactor ART/IPER, etc.) ──
create table if not exists public.agentes_custom (
  id             text primary key,
  user_id        uuid references auth.users(id) on delete cascade,
  contratista_id uuid references public.contratistas(id) on delete cascade,
  nombre         text not null,
  icono          text default '🤖',
  dimension      text default '',        -- ej: 'prevencion', 'documental'
  descripcion    text default '',
  prompt_text    text default '',
  preguntas      jsonb default '[]'::jsonb,
  visual         boolean default false,
  together_llm   boolean default false,
  updated_at     timestamptz default now(),
  created_at     timestamptz default now()
);

-- ── SESIONES DE CHAT con agentes ───────────────────────────────────
create table if not exists public.agent_sesiones (
  id           text primary key,
  user_id      uuid references auth.users(id) on delete cascade,
  agent_id     text,
  agent_nombre text default '',
  title        text default '',
  first_msg    text default '',
  messages     jsonb default '[]'::jsonb,
  saved_at     timestamptz default now(),
  updated_at   timestamptz default now()
);

-- ── DOCUMENTOS generados/subidos en el chat (ART, IPER, informes) ──
create table if not exists public.documentos_chat (
  id             text primary key,
  user_id        uuid references auth.users(id) on delete cascade,
  contratista_id uuid references public.contratistas(id) on delete cascade,
  nombre         text,
  tipo           text,               -- 'ART' | 'IPER' | 'informe' | ...
  contenido      text,
  created_at     timestamptz default now()
);

-- ── CONFIG clave/valor (ajustes por contratista o globales) ────────
create table if not exists public.config (
  key            text primary key,
  value          jsonb,
  contratista_id uuid references public.contratistas(id) on delete cascade,
  updated_at     timestamptz default now()
);

-- ── RLS: mismo patrón de aislamiento que las tablas base ───────────
alter table public.agentes_custom  enable row level security;
alter table public.agent_sesiones  enable row level security;
alter table public.documentos_chat enable row level security;
alter table public.config          enable row level security;

-- Agentes: mandante ve todos; contratista ve globales (contratista_id null) + los suyos.
create policy agentes_select on public.agentes_custom
  for select using (
    public.is_mandante()
    or contratista_id is null
    or contratista_id = public.current_contratista_id()
  );
create policy agentes_write on public.agentes_custom
  for all using (
    user_id = auth.uid() or public.is_mandante()
  ) with check (
    user_id = auth.uid() or public.is_mandante()
  );

-- Sesiones: privadas del usuario que las creó (más el mandante para auditoría).
create policy sesiones_all on public.agent_sesiones
  for all using (user_id = auth.uid() or public.is_mandante())
           with check (user_id = auth.uid() or public.is_mandante());

-- Documentos: mandante ve todos; contratista ve los de su empresa.
create policy documentos_select on public.documentos_chat
  for select using (
    public.is_mandante()
    or contratista_id = public.current_contratista_id()
    or user_id = auth.uid()
  );
create policy documentos_write on public.documentos_chat
  for all using (user_id = auth.uid() or public.is_mandante())
           with check (user_id = auth.uid() or public.is_mandante());

-- Config: global (contratista_id null) legible por todos; por-contratista aislada.
create policy config_select on public.config
  for select using (
    contratista_id is null
    or public.is_mandante()
    or contratista_id = public.current_contratista_id()
  );
create policy config_write on public.config
  for all using (
    (contratista_id is null and public.is_mandante())
    or contratista_id = public.current_contratista_id()
  ) with check (
    (contratista_id is null and public.is_mandante())
    or contratista_id = public.current_contratista_id()
  );
