# Design System: Gestion Team netTime — Grupo SPEC Operations Dashboard

## 1. Visual Theme & Atmosphere

A cockpit-dense operations dashboard with premium corporate restraint. The atmosphere is that of a mission control room — dense with live data but never chaotic. Every element earns its place. The visual language is dark-first, architectural, and precise: deep space backgrounds with glass-surface cards that feel like frosted instrument panels. Glassmorphism is used sparingly as elevation signal, not decoration.

Density 8 — data-heavy, no breathing room wasted.
Variance 4 — structured and predictable. This is a professional tool, not a portfolio.
Motion 4 — purposeful micro-interactions only. Data updates animate in; nothing pulses for vanity.

Light mode is a secondary mode, not an afterthought — it inverts to a clean ash-white editorial surface without losing the premium feel.

---

## 2. Color Palette & Roles

### Dark Mode (Default)
- **Deep Space** (#0B0C11) — Primary canvas background, deepest layer
- **Void Surface** (#111318) — Secondary background, sidebar fills
- **Glass Panel** (#1A1C24) — Card and container fill (glassmorphism base)
- **Elevated Glass** (#21242F) — Hover state, modals, elevated cards
- **Ghost Border** (rgba(255,255,255,0.07)) — Structural card borders, 1px lines
- **Active Border** (rgba(255,255,255,0.14)) — Focused/active card borders
- **Pure Ice** (#F0F2F5) — Primary text, headings, high-contrast labels
- **Steel Mist** (#8B8FA8) — Secondary text, metadata, column headers
- **Fog** (#4A4E63) — Disabled text, placeholder, timestamp muted
- **SPEC Blue** (#3B6BF7) — Primary accent: CTAs, active tab underlines, progress fills, links
- **SPEC Blue Dim** (rgba(59,107,247,0.15)) — Badge backgrounds, pill tints, hover backgrounds
- **Emerald Signal** (#22C55E) — Status: activo, online, completed
- **Amber Alert** (#F59E0B) — Status: en progreso, pending, warning
- **Rose Critical** (#F43F5E) — Status: vencido, stale ticket, error, cerrado urgente
- **Zinc Neutral** (#6B7280) — Status: pausado, sin asignar, neutral

### Light Mode (Inverted)
- **Ash White** (#F6F7FA) — Primary canvas background
- **Pure Surface** (#FFFFFF) — Card fills
- **Lifted Surface** (#ECEEF4) — Hover states, elevated containers
- **Ink Primary** (#0F1117) — Primary text
- **Slate Secondary** (#4B5563) — Secondary text
- **Line Border** (rgba(0,0,0,0.08)) — Structural borders

All status colors remain identical across light/dark — never adjust semantic color meaning by mode.

---

## 3. Typography Rules

- **Display / Section Titles:** Geist — weight 600, letter-spacing -0.02em, size 18–24px. Never screaming. Hierarchy through weight contrast and color dimming, not size alone.
- **Data Labels / Column Headers:** Geist — weight 500, uppercase, letter-spacing 0.06em, size 11px, color Steel Mist (#8B8FA8). All table column headers follow this rule.
- **Body / Card Content:** Geist — weight 400, line-height 1.5, size 13–14px, max-width 60ch.
- **Monospace / Numbers / IDs / Timestamps:** Geist Mono — weight 400, size 12–13px. All ticket IDs, zammad_id, dates, counts, and KPI numbers use Geist Mono exclusively.
- **KPI Values:** Geist — weight 700, size 28–36px, color Pure Ice. No gradient fills on numbers.
- **Badge / Pill Text:** Geist — weight 500, size 11px, uppercase, letter-spacing 0.04em.

**Banned:**
- Inter, Plus Jakarta Sans, Roboto, System UI for new screens
- Any serif font
- Gradient text effects on headings
- Type sizes below 11px

---

## 4. Component Stylings

### Navigation / Team Selector
Top navigation bar with "netTime" and "SPECManager" as primary tabs. Active tab: SPEC Blue (#3B6BF7) underline (3px, border-radius 2px) + Pure Ice text. Inactive: Steel Mist. Tab bar background: Glass Panel with 1px Ghost Border bottom. No dropdown — two flat tabs only. Logo (logo.png) left-anchored, 32px height.

### KPI Cards (Resumen Section)
6-column grid. Each card: Glass Panel background, 1px Ghost Border, border-radius 16px, padding 20px 24px. Icon top-left (24px, SPEC Blue tint). Metric label: Steel Mist 11px uppercase. Value: Geist 700 28px Pure Ice, Geist Mono for counts. Trend delta: small pill below value — Emerald for positive, Rose for negative. No drop shadows — depth comes from border and background contrast only.

### Kanban Cards (Proyectos Section)
Compact kanban columns. Column header: Uppercase label + count badge (SPEC Blue Dim background). Cards: 12px border-radius, Glass Panel fill, 1px Ghost Border, 12px internal padding. Progress bar: thin (4px), full-width, Emerald fill on SPEC Blue Dim track. Client name: Pure Ice 13px weight 500. Status badge: pill with status color (Emerald/Amber/Rose/Zinc). No card drop shadows.

### Data Tables (Instalaciones, Tickets, Pedidos)
Alternating row backgrounds: transparent / Glass Panel (0.4 opacity). Row height 44px minimum for touch compliance. Column headers: uppercase 11px Steel Mist, border-bottom Ghost Border. Cell text: 13px Pure Ice for primary fields, Steel Mist for metadata. Stale ticket rows: left border 3px Rose Critical + subtle Rose tint on row background. Hover state: Elevated Glass background. zammad_id: Geist Mono Steel Mist.

### Status Badges / Pills
Border-radius 999px (fully rounded). Padding 3px 10px. Font: Geist 500 11px uppercase. Colors:
- activo → Emerald text + Emerald/15% background
- en_progreso → Amber text + Amber/15% background
- cerrado / vencido → Rose text + Rose/15% background
- pausado → Zinc text + Zinc/15% background

### Progress Bars
4px height, border-radius 999px. Track: SPEC Blue Dim. Fill: gradient-free SPEC Blue. Percentage label: Geist Mono 11px Steel Mist, right-aligned.

### Dropdowns / Selects
Glass Panel background. 1px Ghost Border. Border-radius 8px. Option list: same background, 1px separator lines (Ghost Border). Selected option: SPEC Blue Dim background. Works in both dark and light mode — never hardcoded rgba in option elements.

### Buttons
Primary: SPEC Blue fill, Pure Ice text, border-radius 8px, padding 8px 16px, no outer glow. Active state: -1px translateY (tactile push). Hover: SPEC Blue darkened 8%. Ghost/secondary: 1px Ghost Border, transparent fill, Steel Mist text.

### Loaders / Skeletons
Shimmer bars matching exact layout dimensions of the content they replace. Color: Ghost Border base with lighter shimmer pass animation. Never circular spinners.

### Historial / Timeline
Left-border vertical line (1px Ghost Border). Each entry: dot (8px, status color filled circle), entity name (Pure Ice 13px), action description (Steel Mist 12px), absolute timestamp (Geist Mono 11px Fog). Grouped by date — date label: uppercase 11px Steel Mist, full-width separator.

### Dark/Light Toggle
Icon-only button (sun/moon). Top-right nav area. 32px tap target minimum. Transition: CSS variable swap, 150ms.

---

## 5. Layout Principles

- Top nav bar: fixed, 56px height, full-width, Deep Space background, 1px Ghost Border bottom
- Section tabs (Resumen, Proyectos, etc.): horizontal pill row beneath nav. Active: Glass Panel background + SPEC Blue underline
- Content area: max-width 1440px, centered, padding 24px horizontal
- KPI grid: CSS Grid `repeat(6, 1fr)`, gap 16px. Below 1200px: 3 columns. Below 768px: 2 columns
- Kanban: horizontal scroll container with `display: flex`, column width 240px fixed
- Tables: full-width, no horizontal scroll on desktop. Below 768px: single-column card view
- Spacing unit: 4px base. Sections separated by 32px vertical gap
- No overlapping elements — every element in its own clean spatial zone
- No absolute-positioned content stacking

---

## 6. Motion & Interaction

- **Row reveals:** Staggered cascade as data loads — each row fades in with 30ms delay offset, `opacity 0 → 1`, `translateY 4px → 0`. Duration 200ms ease-out
- **KPI count-up:** Numbers animate from 0 to value on mount. Duration 600ms, ease-out cubic
- **Status updates (Realtime):** When a row updates via Supabase Realtime, flash the row background with SPEC Blue Dim for 800ms then fade back. No jarring full re-renders
- **Tab transitions:** Fade-through — outgoing section opacity 0 (100ms), incoming section opacity 0 → 1 (150ms)
- **Hover states:** 120ms ease. Background color only — never scale transforms on table rows
- **Spring physics:** Only for kanban card drag (if implemented). `stiffness: 180, damping: 24`
- Hardware-accelerated transforms only — never animate `height`, `top`, `left`, or `background-color` on large lists

---

## 7. Anti-Patterns (Banned)

- No emojis in any UI element
- No Inter, Plus Jakarta Sans, or Roboto in new screens
- No pure black (#000000) — always Deep Space (#0B0C11) or darker surface variants
- No neon outer glow shadows — no `box-shadow: 0 0 20px #3B6BF7`
- No oversaturated accents — SPEC Blue is the one accent, saturation stays below 80%
- No gradient text on headlines or KPI values
- No gradient fills on buttons or cards (flat color only)
- No circular loading spinners — skeletons only
- No 3-column equal-weight feature grids — use asymmetric layouts
- No AI copywriting: "Seamless", "Elevate", "Unleash", "Next-Gen", "Powerful"
- No generic placeholder names ("Cliente A", "Proyecto X") — use real netTime/SPEC terminology
- No rounded-full cards (cards use 16px radius, not pill shapes)
- No decorative blur blobs or ambient glow backgrounds
- No header icons that are just colored squares with rounded corners
- No hardcoded rgba white values in JS template literals — always CSS variables
- No relative dates ("hace 2h") — always absolute DD/MM/YYYY HH:mm via fmtDate()
- No horizontal overflow on any viewport
