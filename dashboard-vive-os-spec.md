# Gestion Team netTime

Proyecto standalone: HTML/JS estático + Supabase + n8n, repo propio, deploy en Netlify (sin build step). Supabase queda cloud (no depende del VPS), n8n sigue corriendo en n8n.vive-ia.com.

---

## 1. Arquitectura

```
Zammad API ──┐
             ├─► n8n (sync cron) ──► Supabase (tablas)
Zoho Analytics┘                          │
                                          ▼
Telegram (audio) ─► n8n (Whisper+LLM) ─► Supabase (update + status_log)
                                          │
                                          ▼
                              Gestion Team netTime (HTML + Supabase JS Realtime)
```

Una sola fuente de verdad: Supabase. Zammad y Zoho se sincronizan hacia adentro; Telegram escribe directo; el frontend solo lee de Supabase (con Realtime, sin polling).

---

## 2. Schema Supabase

MCP agregado al proyecto (`project_ref=osnttxgmsfudghinxfat`) — Antigravity/Claude Code aplica este schema directo vía MCP (create types, tables, RLS, realtime), no hace falta correrlo a mano en el SQL Editor.

```sql
create type entity_type as enum ('project', 'service', 'ticket', 'order', 'installation');
create type entity_status as enum ('pendiente', 'en_progreso', 'frenado', 'en_revision', 'completado', 'cancelado');
create type update_source as enum ('telegram_voice', 'manual', 'zammad_sync', 'zoho_sync');
create type team_name as enum ('netTime', 'SPECManager');

create table projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  client text,
  team team_name not null default 'netTime',
  status entity_status not null default 'pendiente',
  progress_pct int default 0 check (progress_pct between 0 and 100),
  next_step text,
  blocked_reason text,
  owner text,
  updated_at timestamptz default now()
);

create table services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  client text,
  team team_name not null default 'netTime',
  status entity_status not null default 'pendiente',
  next_step text,
  updated_at timestamptz default now()
);

create table installations (
  id uuid primary key default gen_random_uuid(),
  technician text not null,
  client text,
  team team_name not null default 'netTime',
  description text,
  scheduled_week text,
  next_steps text,
  status entity_status not null default 'pendiente',
  updated_at timestamptz default now()
);

create table tickets (
  id uuid primary key default gen_random_uuid(),
  zammad_id int unique not null,
  title text,
  client text,
  team team_name not null default 'netTime',
  group_name text,
  priority text,
  status text,
  created_at timestamptz,
  updated_at timestamptz default now()
);

create table orders (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  client text,
  team team_name not null default 'netTime',
  status entity_status not null default 'pendiente',
  source text default 'zoho',
  updated_at timestamptz default now()
);

create table status_log (
  id uuid primary key default gen_random_uuid(),
  entity_type entity_type not null,
  entity_id uuid not null,
  team team_name not null,
  previous_status text,
  new_status text,
  note text,
  source update_source not null,
  raw_transcript text,
  created_by text,
  created_at timestamptz default now()
);

-- Realtime
alter publication supabase_realtime add table projects, services, installations, tickets, orders, status_log;

-- RLS: lectura pública (anon key queda en el cliente HTML), escritura solo desde n8n (service_role, bypassea RLS)
alter table projects enable row level security;
alter table services enable row level security;
alter table installations enable row level security;
alter table tickets enable row level security;
alter table orders enable row level security;
alter table status_log enable row level security;

create policy "lectura publica" on projects for select using (true);
create policy "lectura publica" on services for select using (true);
create policy "lectura publica" on installations for select using (true);
create policy "lectura publica" on tickets for select using (true);
create policy "lectura publica" on orders for select using (true);
create policy "lectura publica" on status_log for select using (true);
```

---

## 3. Sync Zammad (n8n, cron cada 15 min)

Ya existe el webhook `zammad-dashboard` con la API key/credenciales de Zammad configuradas en n8n. Reusar esa credencial.

Workflow nuevo: `zammad-sync-supabase`
1. **Cron** (cada 15 min)
2. **HTTP Request** → `GET {zammad_url}/api/v1/tickets/search?query=*` (o `/ticket_overview` para traer estado/prioridad/grupo)
3. **Loop sobre resultados**
4. **Supabase Upsert** en `tickets` (conflict en `zammad_id`), mapeando `team` desde el grupo/queue de Zammad (ej. grupo contiene "SPECManager" → team='SPECManager', resto → team='netTime')
5. Si `status` cambió respecto al valor previo → insert en `status_log` con `source: zammad_sync`

---

## 4. Sync Zoho Projects (n8n, cron cada 15 min)

Reemplaza el embed de Analytics. Mismo patrón que el sync de Zammad: proyectos y pedidos salen del mismo portal de Zoho Projects (pedidos = tasks dentro del proyecto `GESTION_PEDIDOS`).

**Setup OAuth (una sola vez):**
1. Zoho API Console → crear "Self Client" o "Server-based App"
2. Scope: `ZohoProjects.projects.READ,ZohoProjects.tasks.READ`
3. Generar refresh token, guardarlo como credencial en n8n (HTTP Request con OAuth2 genérico, o refresh manual vía `/oauth/v2/token`)
4. Anotar `portal_id` (de la URL de tu Zoho Projects) y `project_id` de GESTION_PEDIDOS

**Workflow `zoho-projects-sync-supabase`:**
1. **Cron** (cada 15 min)
2. **HTTP Request** → `GET https://projectsapi.zoho.com/api/v3/portal/{portal_id}/projects` → upsert en `projects`, mapeando `team` desde el campo `group` de Zoho (ej. group="netTime One"/"netTime 6" → team='netTime', group="SPECManager" → team='SPECManager') y el resto: Estado→status, %→progress_pct, Propietario→owner
3. **HTTP Request** → `GET https://projectsapi.zoho.com/api/v3/portal/{portal_id}/projects/{gestion_pedidos_id}/tasks` → upsert en `orders` (cada task = un pedido, milestone agrupador tipo "H- PED 4-01922 Cofco" se puede usar como `name`; team se infiere del cliente/milestone o se deja default `netTime` y se corrige manual si corresponde a SPECManager)
4. Rate limit: 100 req/2min — con cron de 15 min no hay riesgo
5. Si `status` cambió vs valor previo → insert en `status_log` con `source: zoho_sync` (copiando el `team` de la entidad)

Esto deja projects, services, tickets y orders sincronizados con el mismo mecanismo (cron + upsert + diff de status), todo editable también por voz vía Telegram sin pisarse con el sync (el sync solo pisa si Zoho cambió algo nuevo; si Telegram actualizó algo que Zoho todavía no refleja, esa diferencia queda en el `status_log` como fuente de verdad del último cambio real).

---

## 5. Automatización Telegram (audio → actualización de estado)

Bot: `Team_spec_boy` (token `8683090117:AAFv7dcOvrFk9vlwb4Y-VtT2zifF4buq4no`). Cargalo como credencial de tipo Telegram API en n8n (no lo hardcodees en el workflow JSON ni en ningún archivo del repo — el bot solo vive del lado de n8n, nunca toca el frontend).

Workflow n8n: `telegram-status-update`

1. **Telegram Trigger** — tipo `message`, filtrar `voice`
2. **Telegram → Get File** (descarga el .ogg)
3. **OpenAI → Audio Transcription** (Whisper, `whisper-1`)
4. **Supabase → Get rows** de `projects`, `services`, `installations`, `tickets`, `orders` (`id`, `name`/`technician`, `client`, `status`, `team`) para pasarle al LLM la lista de entidades existentes y matchear por nombre
5. **OpenAI/Gemini → Chat** con system prompt fijo:

```
Sos un parser de actualizaciones de estado. Te paso una transcripción de audio
y una lista de entidades existentes (proyectos, servicios, instalaciones,
tickets, pedidos), cada una con su team (netTime o SPECManager).

Devolvé SOLO JSON, sin texto adicional, con esta forma:
{
  "entity_type": "project|service|installation|ticket|order",
  "action": "update|create",
  "entity_match": "nombre o id más probable de la lista dada, o null si action=create",
  "team": "netTime|SPECManager",
  "confidence": 0-1,
  "new_status": "pendiente|en_progreso|frenado|en_revision|completado|cancelado",
  "next_step": "string o null",
  "blocked_reason": "string o null",
  "note": "resumen breve de lo dicho",
  "installation_fields": {
    "technician": "string o null",
    "client": "string o null",
    "description": "string o null",
    "scheduled_week": "string o null"
  }
}

Reglas:
- project/service/ticket/order vienen de syncs externos, nunca se crean por
  voz: si no matcheás con confianza > 0.6, entity_match: null, action: update.
  El team sale del team de la entidad matcheada, no lo infieras del audio.
- installation no tiene sync externo: si no hay match claro con una
  instalación existente, action: create y completá installation_fields con
  lo que se entienda del audio (ej. "instalación de faciales en Reckitt la
  semana que viene, la hace Marcelo"). Para action=create, inferí team del
  contexto del audio (mención explícita de "SPECManager" o cliente conocido
  de ese team); si no hay ninguna pista, default team: "netTime".
```

6. **IF** `entity_type != installation` y `confidence < 0.6` → responder en Telegram pidiendo aclaración (no actualiza nada)
7. **IF** `action == create` → **Supabase → Insert** en `installations` (incluyendo `team`). **ELSE** → **Supabase → Update** la tabla correspondiente (status, next_step, blocked_reason, updated_at)
8. **Supabase → Insert** en `status_log` (`source: telegram_voice`, `raw_transcript`, `created_by`: nombre de quien mandó el audio, `team` copiado de la entidad)
9. **Telegram → Reply** confirmando: entidad actualizada/creada + team + nuevo estado + next step

Esto cierra el loop: vos mandás un audio tipo *"el proyecto de Biotracom quedó frenado, falta que nos manden el certificado de origen"* y el dashboard se actualiza solo, con historial completo. Para instalaciones también sirve para cargar pendientes nuevos directo desde el campo: *"instalación de lectoras en GC Gestión, semana del 22/06, la hace Marcelo"* crea la fila sin pasar por ninguna planilla.

---

## 6. Frontend — Gestion Team netTime (HTML estático)

Un solo `index.html` con Tailwind por CDN (`<script src="https://cdn.tailwindcss.com">`) y `@supabase/supabase-js` por CDN. Sin build, sin framework.

**Selector de equipo arriba de todo:** dos pestañas, "netTime" y "SPECManager", que filtran `.eq('team', ...)` en cada query. Todas las secciones de abajo se renderizan según el equipo activo (mismo HTML, distinto filtro — no son dos páginas separadas). Default: netTime.

Secciones dentro de cada equipo (anchors/tabs con JS plano):

- **Resumen** — KPIs del equipo activo (proyectos activos, tickets abiertos, frenados, % completado promedio)
- **Proyectos** — lista/kanban por status, progress_pct, next_step, blocked_reason visible en rojo si hay
- **Servicios** — igual estructura simplificada
- **Instalaciones** — tabla tipo planilla: Técnico, Cliente, Descripción, Semana, Próximos pasos, agrupable por status (pendiente/en_progreso/completado)
- **Tickets** — tabla sincronizada de Zammad + iframe de métricas existente (`zammad-dashboard`)
- **Pedidos** — tabla nativa, misma estructura visual que Proyectos (status, owner, fechas), poblada desde `orders` (sync Zoho Projects)
- **Historial** — timeline de `status_log` del equipo activo, filtrable por entidad/cliente, mostrando `raw_transcript` cuando el origen es voz

Supabase Realtime: suscripción a `projects`, `services`, `installations`, `tickets`, `orders`, `status_log` para que el dashboard se actualice solo sin refresh, ideal para cuando lo estás mostrando en vivo al jefe.

URL/anon key de Supabase van directo en el JS del cliente (es el diseño esperado, no es secreto — la seguridad la dan las RLS policies en las tablas, no ocultar la key).

---

## 7. Prompt para Antigravity

```
Construí "Gestion Team netTime", un dashboard standalone en un solo index.html
(sin framework, sin build step). Usá Tailwind por CDN y @supabase/supabase-js
por CDN (importmap o <script type="module">). Tema dark, glassmorphism, look
propio. Deploy target: Netlify como sitio estático (sin plugin, sin netlify.toml
necesario — solo publish directory).

URL y anon key de Supabase van hardcodeadas en el JS del cliente (lectura
pública vía RLS, es el diseño esperado). Tenés acceso a Supabase vía MCP
(project_ref=osnttxgmsfudghinxfat) — aplicá vos el schema de la sección 2
(types, tables, RLS, realtime) antes de generar el frontend, no asumas que ya
existe. Usá Supabase Realtime channels para que las vistas se actualicen sin
refresh.

Título visible en el header: "Gestion Team netTime".

Selector de equipo arriba de todo (dos pestañas: "netTime" y "SPECManager",
default netTime) que filtra .eq('team', activeTeam) en TODAS las queries de
abajo. Es un solo HTML, no dos páginas — cambiar de pestaña solo recarga los
datos filtrados y re-renderiza las mismas secciones.

Secciones dentro del equipo activo (tabs o anchors en la misma página):
1. Resumen — KPI cards: proyectos activos, % completado promedio, tickets
   abiertos, instalaciones pendientes, items frenados (status='frenado' en
   cualquier tabla), todo filtrado por team
2. Proyectos — cards/kanban agrupado por status, mostrar progress_pct como
   barra, next_step y blocked_reason (blocked_reason en rojo si no es null)
3. Servicios — misma estructura, sin progress_pct
4. Instalaciones — tabla con columnas technician/client/description/
   scheduled_week/next_steps/status, agrupada por status (estilo planilla,
   header tipo "Pendientes")
5. Tickets — tabla con columnas title/client/priority/status/group, + iframe
   embebido apuntando a https://n8n.vive-ia.com/webhook/zammad-dashboard
6. Pedidos — tabla con columnas name/client/status/owner/fecha, mismo estilo
   visual que Proyectos
7. Historial — timeline de status_log ordenado por created_at desc, filtros
   por entity_type y client, mostrar ícono distinto según source (voz/manual/sync),
   y raw_transcript en un tooltip/expand cuando source='telegram_voice'

No uses localStorage. Estado de filtros en variables JS planas. Responsive,
prioridad desktop ya que se usa para presentar en pantalla compartida.
```

---

## Orden de implementación sugerido

1. Pasar el prompt de la sección 7 a Antigravity — aplica el schema vía MCP (`osnttxgmsfudghinxfat`) y genera el frontend en el mismo paso
2. Levantar workflows `zammad-sync-supabase` y `zoho-projects-sync-supabase` en n8n
3. Recién al final, montar `telegram-status-update` — necesita que las tablas ya tengan datos reales para que el matching de entidades funcione bien
