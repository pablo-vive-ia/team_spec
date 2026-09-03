-- ============================================================
-- Gestion Team netTime — Supabase Schema (idempotente)
-- Proyecto: osnttxgmsfudghinxfat
-- Aplicar en: Supabase Dashboard > SQL Editor
-- Seguro para re-ejecutar: usa IF NOT EXISTS en todo
-- ============================================================

-- TIPOS ENUM (solo crea si no existen)
DO $$ BEGIN
  CREATE TYPE entity_type AS ENUM ('project', 'ticket', 'order', 'installation');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE entity_status AS ENUM ('pendiente', 'en_progreso', 'frenado', 'en_revision', 'completado', 'cancelado');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE update_source AS ENUM ('telegram_voice', 'manual', 'zammad_sync', 'zoho_sync');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE team_name AS ENUM ('netTime', 'SPECManager');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- TABLAS

CREATE TABLE IF NOT EXISTS projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  client text,
  team team_name NOT NULL DEFAULT 'netTime',
  status entity_status NOT NULL DEFAULT 'pendiente',
  progress_pct int DEFAULT 0 CHECK (progress_pct BETWEEN 0 AND 100),
  next_step text,
  blocked_reason text,
  owner text,
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS installations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  technician text NOT NULL,
  client text,
  team team_name NOT NULL DEFAULT 'netTime',
  description text,
  scheduled_week text,
  next_steps text,
  status entity_status NOT NULL DEFAULT 'pendiente',
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zammad_id int UNIQUE NOT NULL,
  title text,
  client text,
  team text NOT NULL DEFAULT 'netTime',
  group_name text,
  priority text,
  nivel_soporte text,
  status text,
  owner text,
  organization text,
  last_contact_at timestamptz,
  first_response_at timestamptz,
  time_unit numeric,
  created_at timestamptz,
  updated_at timestamptz DEFAULT now()
);

-- Migraciones idempotentes (para tablas ya existentes)
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS nivel_soporte text;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS time_unit numeric;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS zammad_number text;

CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  client text,
  team team_name NOT NULL DEFAULT 'netTime',
  status entity_status NOT NULL DEFAULT 'pendiente',
  source text DEFAULT 'zoho',
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  assignee text,
  team team_name NOT NULL DEFAULT 'netTime',
  priority text NOT NULL DEFAULT 'media',
  status text NOT NULL DEFAULT 'pendiente',
  due_date date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS status_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type entity_type NOT NULL,
  entity_id uuid NOT NULL,
  team team_name NOT NULL,
  previous_status text,
  new_status text,
  note text,
  source update_source NOT NULL,
  raw_transcript text,
  created_by text,
  created_at timestamptz DEFAULT now()
);

-- REALTIME (agrega solo las que faltan, ignora duplicados)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE projects;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE installations;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE tickets;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE orders;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE status_log;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE tasks;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- RLS — habilitar en todas las tablas
ALTER TABLE projects    ENABLE ROW LEVEL SECURITY;
ALTER TABLE installations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets     ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders      ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_log  ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks       ENABLE ROW LEVEL SECURITY;

-- POLICIES — lectura pública (anon key); escritura solo via service_role (n8n)
-- Excepciones: tasks e installations permiten escritura desde el frontend (CRUD manual)
DO $$ BEGIN
  CREATE POLICY "lectura publica" ON projects FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "lectura publica" ON installations FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "anon insert installations" ON installations FOR INSERT TO anon WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "anon update installations" ON installations FOR UPDATE TO anon USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "anon delete installations" ON installations FOR DELETE TO anon USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "lectura publica" ON tickets FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "lectura publica" ON orders FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "lectura publica" ON status_log FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "lectura publica" ON tasks FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "escritura interna" ON tasks FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "actualizacion interna" ON tasks FOR UPDATE USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "eliminacion interna" ON tasks FOR DELETE USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- TEAM ACTIVITIES (Actividades Equipo) — sync de registros de tiempo Zoho
-- Proyecto Zoho: "PR-17 .ACTIVIDAD EQUIPO TECNICO" (id 1972504000000057737)
-- Sin distinción de equipo — transversal a todo el equipo técnico
-- ============================================================

CREATE TABLE IF NOT EXISTS team_activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zoho_log_id text UNIQUE NOT NULL,
  activity text NOT NULL,
  user_name text,
  team team_name NOT NULL DEFAULT 'netTime',
  log_date date NOT NULL,
  hours numeric NOT NULL DEFAULT 0,
  notes text,
  bill_status text,
  approval_status text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_team_activities_log_date ON team_activities(log_date);
CREATE INDEX IF NOT EXISTS idx_team_activities_activity  ON team_activities(activity);

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE team_activities;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE team_activities ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "lectura publica" ON team_activities FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- AUTH Y ROLES — PARTE 1 (ADITIVA)  ✅ aplicada 2026-09-03
-- Base del módulo de Planificación + control de acceso por rol.
-- No modifica ninguna policy existente: es seguro correrla sola.
-- ============================================================

-- Campo "próximo paso" de las tareas
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS next_step text;

CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON public.tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON public.tasks(assignee);

-- Perfiles: un rol por usuario de Supabase Auth
CREATE TABLE IF NOT EXISTS public.profiles (
  id         uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      text,
  full_name  text,
  role       text NOT NULL DEFAULT 'viewer',
  created_at timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_role_check CHECK (role IN ('admin','viewer'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Alta automática de perfil al crear un usuario en Auth. Default: viewer.
-- Para crear un admin: user metadata {"role":"admin"} al darlo de alta, o
-- UPDATE public.profiles SET role='admin' WHERE email='...'
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name',''), split_part(NEW.email,'@',1)),
    CASE WHEN NEW.raw_user_meta_data->>'role' = 'admin' THEN 'admin' ELSE 'viewer' END
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END $fn$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Backfill para usuarios creados antes del trigger
INSERT INTO public.profiles (id, email, full_name, role)
SELECT u.id, u.email, split_part(u.email,'@',1), 'viewer'
  FROM auth.users u
 WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = u.id);

-- Helper de rol usado por las policies de escritura.
-- SECURITY DEFINER => corre como owner => bypassea el RLS de profiles, así que
-- se puede invocar dentro de las policies de tasks/installations sin recursión.
-- SET search_path es obligatorio: sin él, la función es secuestrable.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
     WHERE id = auth.uid() AND role = 'admin'
  );
$fn$;

REVOKE EXECUTE ON FUNCTION public.is_admin() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- profiles: cada usuario lee SOLO su propio perfil.
-- Sin subquery => sin recursión de RLS. Sin INSERT/UPDATE desde el cliente
-- => un viewer no puede auto-promoverse a admin.
DROP POLICY IF EXISTS "profiles self select" ON public.profiles;
CREATE POLICY "profiles self select" ON public.profiles
  FOR SELECT TO authenticated USING (id = auth.uid());


-- ============================================================
-- AUTH Y ROLES — PARTE 2 (RLS RESTRICTIVA)   ⚠️ NO aplicada aún
-- ============================================================
-- ORDEN OBLIGATORIO: correr esto SOLO cuando (a) existan los usuarios en
-- Supabase Auth, (b) esté OFF el registro público, y (c) el frontend con
-- login ya esté publicado y verificado. Antes de eso, deja el sitio sin datos.
--
-- Se usa DROP + CREATE (no el patrón DO $$ ... duplicate_object del resto del
-- archivo) porque acá hay que REEMPLAZAR: las policies son OR-aditivas y una
-- sola policy permisiva sobrante anularía todo el hardening.
--
-- Los syncs de n8n NO se ven afectados: usan service_role, que bypassea RLS.
-- ============================================================
--
-- BEGIN;
--
-- -- Lectura: de público a solo autenticados
-- DROP POLICY IF EXISTS "lectura publica" ON public.projects;
-- CREATE POLICY "read authenticated" ON public.projects        FOR SELECT TO authenticated USING (true);
-- DROP POLICY IF EXISTS "lectura publica" ON public.tickets;
-- CREATE POLICY "read authenticated" ON public.tickets         FOR SELECT TO authenticated USING (true);
-- DROP POLICY IF EXISTS "lectura publica" ON public.orders;
-- CREATE POLICY "read authenticated" ON public.orders          FOR SELECT TO authenticated USING (true);
-- DROP POLICY IF EXISTS "lectura publica" ON public.status_log;
-- CREATE POLICY "read authenticated" ON public.status_log      FOR SELECT TO authenticated USING (true);
-- DROP POLICY IF EXISTS "lectura publica" ON public.team_activities;
-- CREATE POLICY "read authenticated" ON public.team_activities FOR SELECT TO authenticated USING (true);
--
-- -- Installations: lectura autenticada, escritura solo admin
-- DROP POLICY IF EXISTS "lectura publica"           ON public.installations;
-- DROP POLICY IF EXISTS "anon insert installations" ON public.installations;
-- DROP POLICY IF EXISTS "anon update installations" ON public.installations;
-- DROP POLICY IF EXISTS "anon delete installations" ON public.installations;
-- CREATE POLICY "read authenticated" ON public.installations FOR SELECT TO authenticated USING (true);
-- CREATE POLICY "admin insert"       ON public.installations FOR INSERT TO authenticated WITH CHECK (public.is_admin());
-- CREATE POLICY "admin update"       ON public.installations FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
-- CREATE POLICY "admin delete"       ON public.installations FOR DELETE TO authenticated USING (public.is_admin());
--
-- -- Tasks: idem. OJO, las policies viejas son TO public (no TO anon), o sea que
-- -- hoy cualquier usuario authenticated hereda escritura completa — ese es
-- -- exactamente el bug que rompería el acceso de solo lectura.
-- DROP POLICY IF EXISTS "lectura publica"       ON public.tasks;
-- DROP POLICY IF EXISTS "escritura interna"     ON public.tasks;
-- DROP POLICY IF EXISTS "actualizacion interna" ON public.tasks;
-- DROP POLICY IF EXISTS "eliminacion interna"   ON public.tasks;
-- CREATE POLICY "read authenticated" ON public.tasks FOR SELECT TO authenticated USING (true);
-- CREATE POLICY "admin insert"       ON public.tasks FOR INSERT TO authenticated WITH CHECK (public.is_admin());
-- CREATE POLICY "admin update"       ON public.tasks FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
-- CREATE POLICY "admin delete"       ON public.tasks FOR DELETE TO authenticated USING (public.is_admin());
--
-- COMMIT;
