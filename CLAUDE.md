# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Gestion Team netTime** — internal operations dashboard for netTime and SPECManager teams. Tracks projects, installations, tickets (from Zammad), and orders (from Zoho Projects).

Full spec: [`dashboard-vive-os-spec.md`](dashboard-vive-os-spec.md)

## Architecture

```
Zammad API ──┐
             ├─► n8n (sync cron, every 15 min) ──► Supabase (tables)
Zoho API ────┘                                          │
                                                        ▼
                                        index.html (Supabase JS Realtime, no polling)
```

**No build step.** The frontend is a single `index.html` with Tailwind via CDN and `@supabase/supabase-js` via CDN. Deploy target: Netlify static site (no `netlify.toml` needed, just publish directory).

## Supabase

- **Project ref:** `osnttxgmsfudghinxfat`
- **MCP access:** available via `.mcp.json` — apply schema via MCP or SQL Editor
- **Schema:** `schema.sql` (idempotente, seguro para re-ejecutar con IF NOT EXISTS)
- **Security model:** anon key is hardcoded in client JS — this is intentional. Security comes from RLS policies (public read, service_role write from n8n only). Do not treat this as a vulnerability.
- **Realtime:** subscriptions on 6 tables (`projects`, `installations`, `tickets`, `orders`, `status_log`, `tasks`) — no polling needed in the frontend.
- **Aplicar schema:** ir a [SQL Editor](https://supabase.com/dashboard/project/osnttxgmsfudghinxfat/sql/new) y ejecutar `schema.sql` completo.

## Frontend Constraints

- Single `index.html`, no framework, no build
- Tailwind CSS via CDN `<script src="https://cdn.tailwindcss.com">`
- Supabase JS via CDN (importmap or `<script type="module">`)
- Dark theme default + light mode toggle — glassmorphism aesthetic
- State in plain JS variables — no localStorage
- Responsive but desktop-priority (used for screen sharing)

**Team selector:** top-level tabs "netTime" / "SPECManager" that apply `.eq('team', activeTeam)` to every Supabase query. Same HTML, different filter — not two pages.

**Sections (nav order):** Resumen, Proyectos, Instalaciones, Tickets, Pedidos, **Tareas Internas**, Historial.

- Resumen: KPI cards + últimos movimientos instalaciones
- Proyectos: kanban + progress bar
- Instalaciones: table
- Tickets: table + iframe to `https://n8n.vive-ia.com/webhook/zammad-dashboard`
- Pedidos: table
- **Tareas Internas**: gestión de tareas internas del equipo (CRUD completo desde el frontend)
- Historial: status_log timeline — solo instalaciones

**`D` object:** `{ projects, installations, tickets, orders, log, tasks }`

### Theming (dark/light mode)

CSS variables in `:root` (dark defaults) overridden in `body.light`. Key variables:

```css
--card-b:  rgba(255,255,255,0.06)  /* dark */ / rgba(0,0,0,0.08)  /* light */
--row-b:   rgba(255,255,255,0.04)  /* dark */ / rgba(0,0,0,0.05)  /* light */
--pill-br: rgba(255,255,255,0.07)  /* dark */ / rgba(0,0,0,0.10)  /* light */
```

All JS-generated HTML uses these variables in inline styles — never hardcode `rgba(255,255,255,...)` directly in template literals.

**Dates:** always absolute format `DD/MM/YYYY HH:mm` via `fmtDate(ts)` — never relative ("hace 2h").

**Tickets:** includes `zammad_id` and `zammad_number` columns. Stale ticket alert (red highlight + icon) when `last_contact_at` > 5 days ago.

**Zammad iframe:** the dark KPI band at the top of Tickets section is an external iframe from n8n — its styling cannot be controlled from `index.html`.

**Select dropdowns:** all `<select>` and `<option>` have global CSS rules for dark/light contrast — never style options inline without matching both modes.

### Tareas Internas

- Tab "TAREAS INTERNAS" posicionado antes de HISTORIAL en el nav.
- CRUD completo: crear, editar, eliminar, ciclar estado desde el frontend (anon key con políticas RLS de escritura en `tasks`).
- **Sin filtro de equipo** — el campo `team` no se muestra ni en tabla ni en modal; la DB usa el default `netTime`.
- Campos del modal: título (obligatorio), descripción, responsable, prioridad (baja/media/alta/urgente), estado, fecha de vencimiento.
- Tabla: TAREA, RESPONSABLE, PRIORIDAD, ESTADO (badge clickeable que cicla), VENCE, acciones (Editar / ✕).
- Filas vencidas: `border-left:3px solid var(--danger)` + fondo rojo tenue + ⚠ en fecha.
- Estado cicla: `pendiente → en_progreso → completado → pendiente`; cancelado solo vía modal.
- KPI cards: Pendientes, En progreso, Vencidas, Completadas.
- Filtro de estado (pills): Todos / Pendiente / En progreso / Completado / Cancelado.
- `tasks` es la única tabla donde el anon key puede INSERT/UPDATE/DELETE (tool interno protegido por Netlify Identity en prod).

### Resumen & Historial — solo instalaciones

- **Resumen** "ÚLTIMOS MOVIMIENTOS": filtra `D.log` a `entity_type === 'installation'`, muestra los últimos 5.
- **Historial**: hardcodeado a `entity_type === 'installation'`. Sin filtros de tipo (HIST_TYPES eliminado). Solo tiene buscador de texto en notas.
- `filterEntity` y `setHistFilter` no existen en el código — fueron eliminados.
- `status_log` en la DB contiene solo registros de instalaciones (limpieza realizada vía MCP Supabase).

## n8n Workflows (on n8n.vive-ia.com)

| Workflow | ID | Trigger | Target tables |
|---|---|---|---|
| `zammad-sync-supabase` | `votsdMSzgAHnTSA0` | Cron 15 min | `tickets`, `status_log` |
| `zoho-projects-sync-supabase` | `bbnieKNegHRGrfvF` | Cron 12h | `projects`, `orders`, `status_log` |
| `telegram-status-update` | `SjD5aAOWywPS92eM` | Telegram voice/text | `installations` + `status_log` |

URLs:
- https://n8n.vive-ia.com/workflow/votsdMSzgAHnTSA0
- https://n8n.vive-ia.com/workflow/bbnieKNegHRGrfvF
- https://n8n.vive-ia.com/workflow/SjD5aAOWywPS92eM

> **Nota:** El workflow de Telegram sigue activo en n8n y escribe en Supabase. El frontend ya no muestra datos específicos de Telegram (se eliminó la lógica de `telegram_voice` del frontend).

## Current Status

- `index.html` — ✅ completo. Sin servicios, sin Telegram en frontend. Anon key hardcoded. Branding Grupo SPEC (Plus Jakarta Sans, paleta corporativa, logo via `logo.png`). Light/dark toggle, fechas absolutas, columna zammad_id + zammad_number, stale ticket alerts, CSS variable theming completo. Resumen e Historial filtrados a instalaciones. Sección TAREAS INTERNAS con CRUD completo.
- `schema.sql` — ✅ idempotente (IF NOT EXISTS + DO $$ EXCEPTION en enums/policies). Sin tabla services. Migraciones idempotentes: `nivel_soporte`, `time_unit`, `zammad_number` en tickets. Tabla `tasks` con RLS (anon puede leer y escribir).
- `logo.png` — ✅ en raíz del proyecto.
- Supabase MCP — ✅ configurado en `.mcp.json` (`osnttxgmsfudghinxfat`).
- n8n MCP — ✅ configurado en `.mcp.json` via HTTP transport (`https://n8n.vive-ia.com/mcp-server/http`).
- `zoho-projects-sync-supabase` — ✅ funcionando. Proyectos (20 items) y pedidos (14 milestones activos) sincronizando. Cron 12h activo. Comparación case-insensitive. Paginación milestones cubre índices 1–601. 16/20 proyectos con `next_step`.
- `telegram-status-update` — ✅ activo y testeado. Crea Y actualiza instalaciones. Credencial: `Team_Spec` (Telegram API).
- `zammad-sync-supabase` — ⚠️ lógica completa y bugs corregidos (ver sección abajo), pero credencial Zammad no creada → workflow no activado.
- Netlify deploy — ⏳ pendiente (drag & drop de la carpeta, sin `netlify.toml`).

## Zoho Sync — Estado Detallado

### Lo que funciona
- `Fetch Proyectos Zoho` → 20 items (API v3, split automático por n8n)
- `Normalizar Proyectos Zoho` → 20 items con team detection por grupo
- Flujo completo de proyectos: fetch → normalizar → buscar en Supabase → comparar → crear/actualizar → log
- `Fetch Pedidos Zoho` → endpoint `/milestones/` con scope `ZohoProjects.milestones.READ` ✅
- `Normalizar Pedidos Zoho` → filtra hitos activos con prefijo `H-`, lee `resp.milestones` y `status_det.name`
- Flujo completo de pedidos: fetch → normalizar → buscar en Supabase → comparar → crear/actualizar → log

### `next_step` — fixes aplicados
- Campo correcto: `created_time_long` (no `time_long` — ese campo no existe en la respuesta Zoho)
- **`Extraer next_step`**: agrupa comentarios por `pairedItem.item` (no por `c.project.id` — ese campo no siempre está embebido en el comentario). `pairedItem` es el índice del item en `Preparar URL Comentarios` que originó ese fetch de comentarios.
- **`Preparar URL Comentarios`**: selecciona la tarea "Seguimiento" más reciente que esté abierta usando `segTasks.slice().reverse().find(openTask)` — no la primera (`tasks.find()`). Crítico para proyectos con múltiples tareas "Seguimiento" históricas (ej. RECKITT BENKISER).
- Fallback cuando no hay "Seguimiento" abierto: última "Seguimiento" encontrada → `tasks[0]` → null
- Proyectos sin `next_step` (esperado): ADIUM-ACCESOS no tiene tarea "Seguimiento" en Zoho; HONDA y KIMBERLY CLARCK tienen "Seguimiento" pero sin comentarios.

### Team detection (proyectos)
El grupo del proyecto en Zoho determina el equipo. Grupos conocidos:
- **netTime**: "netTime 6", "netTime Lite", "netTime One", "SPEC ARGENTINA"
- **SPECManager**: grupos que contengan "specmanager" (confirmar nombres exactos)

El normalizer lee `p.group_name || p.group || p.groups[0]?.name` y deja `_group_name` en el output para debugging.

### Pedidos — Milestones de Zoho
Los "pedidos" son **milestones** (hitos con prefijo "H-") en el proyecto GESTION_PEDIDOS, no tasks regulares.
- Endpoint activo: `GET https://projectsapi.zoho.com/restapi/portal/grupospeclatam/projects/1972504000000679075/milestones/`
- Credencial `Zoho_project` tiene scope `ZohoProjects.projects.READ,ZohoProjects.tasks.READ,ZohoProjects.milestones.READ`
- El normalizer lee `resp.milestones`, filtra `status_det.name !== 'completed'` y nombre con `/^H-/i`
- Status de Zoho milestones viene en `status_det.name` (ej. "Completed", "Open") — no en `status.type`
- **Paginación crítica**: Zoho devuelve milestones en orden cronológico (más antiguos primero). Los milestones completados ocupan los índices 1–400; los activos empiezan cerca del índice 401. `Preparar URLs Pedidos` genera 8 URLs cubriendo índices 1–601 más un intento con `?flag=open`. `Fetch Pedidos Zoho` tiene `continueRegularOutput` por si `?flag=open` retorna 400.
- `Comparar Pedidos` usa `.toLowerCase()` en ambos lados para evitar duplicados por variaciones de capitalización.

### Zoho API — Notas importantes
- **API v3** (`/api/v3/`): solo soporta `/projects`. Tasks, milestones y demás requieren formato `restapi`.
- **Fetch Proyectos**: `GET https://projectsapi.zoho.com/api/v3/portal/grupospeclatam/projects` — devuelve array spliteado automáticamente por n8n (20 items, no wrapper).
- **Fetch Pedidos**: `GET https://projectsapi.zoho.com/restapi/portal/grupospeclatam/projects/1972504000000679075/milestones/`
- **Portal**: `grupospeclatam` | **Proyecto GESTION_PEDIDOS ID**: `1972504000000679075`
- Parámetros `?status=active` y `?status=open` dan error 400 en ambos endpoints — no usar.

## Zammad Sync — Estado Detallado

Workflow `zammad-sync-supabase` (`votsdMSzgAHnTSA0`). Lógica completa, pendiente de credencial.

### Conexión Zammad
- **Host:** `190.210.223.60` (IP directa, SSL con SNI `soporte.grupospec.com.ar`)
- **Token:** en n8n Credentials Store como `Zammad API` (Header Auth: `Authorization: Token token=...`)
- **rejectUnauthorized:** `false` (certificado self-signed o mismatch de hostname)

### Buscar Tickets Zammad — lógica actual
El nodo `Buscar Tickets Zammad` es un Code node con HTTPS nativo (no HTTP Request node):

1. `GET /api/v1/ticket_states` → obtiene todos los estados con `state_type_id`
2. Filtra estados con `state_type_id` en `{1, 2, 3, 4}` (1=new, 2=open, 3=pending reminder, 4=pending action)
3. Construye query ES: `state_id:X OR state_id:Y OR ...`
4. Paginación: hasta 10 páginas de 100 tickets (`/api/v1/tickets/search?query=...&expand=true&per_page=100&page=N`)
5. Fallback si `/api/v1/ticket_states` falla: usa IDs `[1, 2, 3, 4]` directamente
6. Maneja ambos formatos de respuesta: array directo Y `{assets: {Ticket: {...}}}`

**Motivo del Code node:** el nodo HTTP Request de n8n no permite `rejectUnauthorized: false` ni SNI custom — necesario porque Zammad está en IP directa con certificado para otro dominio.

### Fixes aplicados al workflow

**Normalizar Tickets Zammad:**
- `product` en Zammad llega como array JSON (`["x-Time"]`) — se extrae con `Array.isArray(rawProducto) ? rawProducto[0] : rawProducto`
- `mapTeam()` convierte el producto Zammad al enum `team_name` de Supabase:
  - `specmanager` → `SPECManager`
  - `spec argentin` → `SPEC Argentina`
  - resto (x-Time, xTime, netSync, Postmaster) → `netTime`
- Se preservan dos campos: `team` (enum, para Supabase) y `group_name` (valor original de Zammad, para display en frontend)
- `stateName`, `groupName`, `priorityName` se extraen con fallback string si Zammad devuelve objeto en lugar de string

**Comparar y Preparar (reconciliación de tickets cerrados):**
- Zammad solo devuelve tickets abiertos/nuevos/pendientes
- Al finalizar el fetch, compara tickets abiertos en Supabase contra los IDs fetcheados
- Si un ticket estaba abierto en Supabase pero no aparece en Zammad → se marca `status: 'cerrado'`

**Insertar Status Log:**
- Credencial: `CEO_vive_Supabase` (ID: `5wD9YEVcOOK8Xchb`)
- Campo `id` NO se setea — es UUID auto-generado por Postgres
- `entity_id` = `$("Comparar y Preparar").item.json._supabase_id`
- Campos: `entity_type` → "ticket", `team`, `previous_status`, `new_status`, `source` → "zammad_sync"

### team vs group_name en tickets
- `team` → enum válido para Supabase (`netTime` / `SPECManager` / `SPEC Argentina`)
- `group_name` → nombre original del producto Zammad (`x-Time`, `SPECManager`, `netSync`, etc.)
- El frontend siempre lee `group_name` para tabs y badges: `ticketProductLabel(t.group_name || t.team)`

### Pendiente para activar
Crear credencial `Zammad API` en n8n (Header Auth):
- Header: `Authorization`
- Value: `Token token=TU_TOKEN_ZAMMAD`

Luego re-guardar credencial `CEO_vive_Supabase` (abrir → guardar sin cambios) para refrescar schema cache del nodo Supabase, y activar workflow `votsdMSzgAHnTSA0`.

## Telegram Workflow — Detalles

El workflow `telegram-status-update` (`SjD5aAOWywPS92eM`) soporta voz y texto. Flujo:

1. Transcribe audio (Whisper) o toma texto directo
2. Fetch de todas las entidades de Supabase → contexto para el LLM
3. GPT-4.1-mini parsea la transcripción y devuelve JSON con `action: "create" | "update"`, `entity_type`, `confidence`, campos de instalación, etc.
4. Si `confidence >= 0.5`: crea o actualiza
5. Si `confidence < 0.5`: pide aclaración por Telegram

### Creación de instalaciones por voz
Solo las instalaciones se pueden **crear** por voz/texto. Proyectos, tickets y pedidos solo se actualizan.

Campos que extrae el LLM para instalaciones nuevas:
- `client` — nombre del cliente
- `description` — qué se instala
- `technician` — quién lo hace (default: "Sin asignar")
- `scheduled_week` — cuándo está agendado
- `team` — default: "netTime"

### Bug resuelto: `entity_id` null en creaciones
Al crear una instalación nueva, el LLM devuelve `entity_id: null` (el registro no existía aún). El nodo `Insertar Status Log` usaba ese null → error de constraint.

**Fix aplicado:** `entity_id` en `Insertar Status Log` ahora usa:
```
={{ $json.id || $("Parsear Respuesta LLM").item.json.entity_id }}
```
`$json.id` proviene del nodo de Supabase anterior (Crear/Actualizar Instalacion o Actualizar en Supabase), que siempre devuelve el UUID del registro afectado.

## Credenciales n8n (resumen)

| Credencial | ID | Tipo | Workflow |
|---|---|---|---|
| `Zoho_project` | — | OAuth2 genérico | `zoho-projects-sync-supabase` |
| `Team_Spec` | — | Telegram API | `telegram-status-update` |
| `CEO_vive_Supabase` | `5wD9YEVcOOK8Xchb` | supabaseApi | `zammad-sync-supabase` |
| `Zammad API` | — | Header Auth (`Authorization: Token token=...`) | `zammad-sync-supabase` ⏳ pendiente |

## Pendientes para activar todo

1. **Aplicar schema.sql** en Supabase SQL Editor — ejecutar el archivo completo (idempotente, seguro)
2. **Zammad credential** — crear `Zammad API` (Header Auth, `Authorization: Token token=TU_TOKEN`) y activar workflow `votsdMSzgAHnTSA0`
3. **Re-guardar `CEO_vive_Supabase`** en n8n para refrescar schema cache (abrir credencial → guardar sin cambios)
4. **Netlify deploy** — drag & drop de la carpeta (sin `netlify.toml`)

## n8n MCP

- **Endpoint:** `https://n8n.vive-ia.com/mcp-server/http` (n8n built-in MCP server)
- **Config:** `.mcp.json` → server `"n8n"`, type `http`

## n8n-mcp Subdirectory

`n8n-mcp/` is a separate OSS project (MCP server for n8n documentation). It has its own `CLAUDE.md` and should be treated as an independent repo. Do not mix its changes with the dashboard.
