-- ═══════════════════════════════════════════════════════════════════
-- LIAX CONTRATISTAS — Modelo de datos base
-- Re-domicilia el modelo real del LIAX educativo (colegios/usuarios) al
-- dominio de seguridad de contratistas Codelco. Pegar COMPLETO en el
-- SQL Editor del Supabase NUEVO (no el educativo).
-- Orden: este archivo primero; luego esquema_rags_contratistas.sql.
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. CONTRATISTAS (equivale a `colegios`) ────────────────────────
create table if not exists public.contratistas (
  id            uuid primary key default gen_random_uuid(),
  nombre        text not null,               -- razón social
  rut           text unique,                 -- RUT empresa
  clasificacion text check (clasificacion in ('A','B','C','D')),  -- nivel de exposición (RESSO Tít. VII)
  estado        text default 'Aceptable'     -- Aceptable | Moderado | Inaceptable (matriz auditoría)
                 check (estado in ('Aceptable','Moderado','Inaceptable')),
  area          text,                         -- área/planta principal en Ventanas
  created_at    timestamptz default now()
);

-- ── 2. USUARIOS (equivale a `usuarios` educativo) ──────────────────
-- rol: 'superadmin' | 'mandante' (Codelco, ve todo) | 'contratista' (ve solo lo suyo)
create table if not exists public.usuarios (
  id             uuid primary key references auth.users(id) on delete cascade,
  rol            text not null default 'contratista'
                  check (rol in ('superadmin','mandante','contratista')),
  nombre         text,
  apellido       text,
  email          text,
  contratista_id uuid references public.contratistas(id) on delete set null,  -- null para mandante/superadmin
  created_at     timestamptz default now()
);

-- ── 3. HELPERS de aislamiento (los usa la RLS de `rags` y del resto) ─
-- Devuelve el contratista_id del usuario logueado (null si mandante/superadmin).
create or replace function public.current_contratista_id()
returns uuid language sql stable security definer set search_path = public as $$
  select contratista_id from public.usuarios where id = auth.uid()
$$;

-- True si el usuario logueado es mandante o superadmin (ve todo).
create or replace function public.is_mandante()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from public.usuarios
    where id = auth.uid() and rol in ('mandante','superadmin')
  )
$$;

-- ── 4. RLS de las tablas base ──────────────────────────────────────
alter table public.contratistas enable row level security;
alter table public.usuarios     enable row level security;

-- CONTRATISTAS: el mandante ve todos; un contratista ve solo su propia ficha.
create policy contratistas_select on public.contratistas
  for select using (
    public.is_mandante() or id = public.current_contratista_id()
  );
-- Solo el mandante crea/edita contratistas.
create policy contratistas_write on public.contratistas
  for all using (public.is_mandante()) with check (public.is_mandante());

-- USUARIOS: cada quien ve su propia fila; el mandante ve todas.
create policy usuarios_select on public.usuarios
  for select using (
    id = auth.uid() or public.is_mandante()
  );
-- El mandante gestiona usuarios; cada usuario puede editar su propia fila.
create policy usuarios_write on public.usuarios
  for all using (id = auth.uid() or public.is_mandante())
           with check (id = auth.uid() or public.is_mandante());

-- ── 5. Trigger: al registrarse en auth, crear fila en usuarios ─────
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.usuarios (id, email, rol)
  values (new.id, new.email, 'contratista')
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
