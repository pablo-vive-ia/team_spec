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

-- RLS — habilitar en todas las tablas
ALTER TABLE projects    ENABLE ROW LEVEL SECURITY;
ALTER TABLE installations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets     ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders      ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_log  ENABLE ROW LEVEL SECURITY;

-- POLICIES — lectura pública (anon key); escritura solo via service_role (n8n)
DO $$ BEGIN
  CREATE POLICY "lectura publica" ON projects FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "lectura publica" ON installations FOR SELECT USING (true);
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
