# pSEO v2 Design — Nationality-First Architecture

**Date:** 2026-04-22  
**Status:** Awaiting user approval  
**Supersedes:** Original pSEO plan (destination-first URL schema)

---

## Problem

Phase 1 built `/estudiar-ingles-en-irlanda/para-colombianos` (destination-first). This is being replaced before any data goes live. New architecture is nationality-first, nested under existing country hubs (`/co`, `/mx`, `/cl`, `/ar`) which already carry 14 years of domain authority. Internal links + URL path both pass authority to pSEO pages.

---

## URL Architecture

**Destination-first** (matches existing frontend route parser — no code changes needed).

```
/estudiar-{idioma}-en-{destino}/para-{nacionalidad}            hub page
/estudiar-{idioma}-en-{destino}/para-{nacionalidad}/4-semanas  duration page
/estudiar-{idioma}-en-{destino}/para-{nacionalidad}/8-semanas
/estudiar-{idioma}-en-{destino}/para-{nacionalidad}/12-semanas
/estudiar-{idioma}-en-{destino}/para-{nacionalidad}/6-meses
/estudiar-{idioma}-en-{destino}/para-{nacionalidad}/desde-{ciudad}  city page (phase 2)
```

### Examples

```
/estudiar-ingles-en-irlanda/para-colombianos
/estudiar-ingles-en-irlanda/para-colombianos/4-semanas
/estudiar-ingles-en-irlanda/para-colombianos/8-semanas
/estudiar-ingles-en-irlanda/para-colombianos/12-semanas
/estudiar-ingles-en-irlanda/para-colombianos/6-meses

/estudiar-ingles-en-canada/para-mexicanos
/estudiar-ingles-en-canada/para-mexicanos/4-semanas
/estudiar-ingles-en-canada/para-mexicanos/desde-monterrey      (phase 2)

/estudiar-ingles-en-canada/para-chilenos
/estudiar-ingles-en-canada/para-chilenos/4-semanas
/estudiar-ingles-en-canada/para-chilenos/desde-santiago        (phase 2)

/estudiar-ingles-en-irlanda/para-argentinos
/estudiar-ingles-en-canada/para-peruanos                       (future)
```

### URL Rules

- `{idioma}` = ingles | frances (lowercase)
- `{destino}` = canada | irlanda | reino-unido | malta | dubai (lowercase, hyphenated)
- `{nacionalidad}` = colombianos | mexicanos | chilenos | argentinos | peruanos (plural, lowercase)
- `{ciudad}` = monterrey | santiago | buenos-aires | bogota (lowercase, hyphenated)
- City pages are phase 2 — only add when search data confirms volume

### Authority from Country Hubs

Each existing hub (`/co`, `/mx`, `/cl`, `/ar`) links to its pSEO hub page via `CountryHubInternalLinks`. Internal links pass authority — no URL nesting required. Hub → pSEO link is already implemented.

### New Nationalities Without Hub Pages

Just add new pSEO pages with `para-peruanos` etc. No stub hub needed — internal links from existing hubs can cross-reference. Add a hub when content volume justifies it.

---

## Page Types & Content Template

### Hub Page (`/{cc}/estudiar-en-{destination}/`)

**Purpose:** Authority page, captures broad searches, links down to duration pages.

**Sections (in order):**
1. **Hero** — headline + subheadline + primary WhatsApp CTA
2. **Visa quick-answer box** — styled callout (green = sin permiso, orange = eTA only, red = visa required + process outlined). This is the #1 anxiety for every student — answer it first.
3. **"Por qué {destination} para {nationality}"** — 3 benefits with icons (real content, not generic)
4. **Duration comparison cards** — 4-semanas / 8-semanas / 12-semanas / 6-meses cards with price range + outcome summary → each links to its duration page
5. **Cost breakdown table** — tuition + accommodation + flights + visa fee + pocket money = estimated total. Real number ranges, not vague estimates.
6. **Cost of living per week** — rent, food, transport, entertainment. Sourced from verified data, not LLM.
7. **Featured schools** — 3–4 schools with photo, price, accreditation badge, location
8. **Testimonial** — YouTube embed if available (Mexico→Canada has one), otherwise text quote + student photo
9. **FAQ accordion** — 8 questions (FAQPage JSON-LD). Questions must match real search queries, not generic.
10. **WhatsApp CTA mid + bottom** — pre-filled message with nationality + destination context
11. **E-E-A-T footer** — "Verificado por [name], [date]" with face photo. Visible, not hidden in footer.

### Duration Pages (`/{cc}/estudiar-en-{destination}/{n}-semanas`)

**Purpose:** Bottom-funnel converter. Captures high-intent searches with duration already in query.

Each page must be genuinely different — not the hub page with duration swapped. Difference comes from:

| Block | 4 semanas | 8 semanas | 12 semanas | 6 meses |
|---|---|---|---|---|
| Sin permiso callout | ✅ Yes | ✅ Yes | ✅ Yes | ❌ Study permit required |
| Persona | "Quiero probarlo" / vacation + study | Recent graduate / summer break | Serious improvement, CV upgrade | Career change / immigration pathway |
| Honest outcome | Fear barrier breaks. Fluency: no. | A2→B1 possible from basics. Noticeable at any level. | B1→B2 realistic. Cambridge prep available. | B2→C1, certificates, work experience |
| Cost (Ireland est.) | ~€2,500 | ~€4,500 | ~€7,000 | ~€12,000 |
| Cost (Canada est.) | ~$3,500 CAD | ~$5,500 CAD | ~$8,500 CAD | ~$14,000 CAD |
| School filter note | Intensive programs only (not all schools do 4-week) | Standard + intensive | Standard + Cambridge prep | All + work experience programs |
| Visa section | Skip (not needed) | Skip | Skip | Full process section — becomes a feature not a fear |

**Duration page sections:**
1. **Status badge** — "Sin permiso de estudio" (green) or "Requiere permiso de estudio" (orange) — first thing visible
2. **"Este programa es para ti si..."** — 3 bullet persona points (different per duration)
3. **Honest outcomes** — what level improvement is realistic in this timeframe. Honest > marketing.
4. **Exact cost breakdown** — tuition rate × weeks + accommodation + one-way flight estimate + visa/eTA fee
5. **Sample weekly schedule** — Mon–Fri outline (classes, activities, free time). Makes it real.
6. **Best schools for this duration** — curated shortlist (not all schools, filtered by what works for this length)
7. **WhatsApp CTA** — "Consultá por cursos de {n} semanas en {destination}"
8. **Internal links** — sibling duration pages + hub (breadcrumb + inline links)

### City Pages (`/{cc}/estudiar-en-{destination}/desde-{ciudad}`) — Phase 2

Only build when:
- 500k+ population city
- Client data shows students from that city OR keyword tool shows volume
- Have city-specific content: flight time from that city, regional price differences, any local agent contacts

City-specific content blocks:
- Flight time + approximate cost from that city to destination
- "Estudiantes de {ciudad}" testimonial if available
- Regional purchasing power context (Monterrey students have different budget than Oaxaca)

---

## Visa Logic by Combo

| Nationality | Destination | Visa situation | Page callout |
|---|---|---|---|
| Colombian | Ireland | Study visa required (Irish consulate Bogotá, €60, 4–6 weeks) | ⚠️ Orange |
| Mexican | Canada | No study permit for <6 months. eTA only ($7 CAD, online, 72h). | ✅ Green |
| Chilean | Canada | No study permit for <6 months. eTA only. | ✅ Green |
| Chilean | UK | Standard Visitor Visa required | ⚠️ Orange |
| Argentine | Ireland | No pre-travel visa. Student Permission at landing (IRP). | ✅ Green (with nuance note) |
| Colombian | Canada | No study permit for <6 months. eTA only. | ✅ Green |

**Hard rule:** Visa data is NEVER LLM-generated. Sourced from embassy/IRCC pages, manually verified, quarterly audit date visible on page.

---

## Architecture Changes from v1

### 1. Frontend Route — NO CHANGE NEEDED

Loveable agent already implemented destination-first routing:
```
Route: /:idiomaDestino/:paraNacionalidad
Route: /:idiomaDestino/:paraNacionalidad/:extra
Guard: idiomaDestino must match estudiar-{idioma}-en-{destino}
       paraNacionalidad must start with para-
```
This handles all pSEO URLs correctly. No frontend route changes required.

### 2. Strapi pSEO Page Slug Format (unchanged from v1)

```
estudiar-ingles-en-irlanda/para-colombianos
estudiar-ingles-en-irlanda/para-colombianos/4-semanas
estudiar-ingles-en-canada/para-mexicanos
```

Slug = full path minus leading slash. Frontend fetches by slug via `fetchPseoPageBySlug`.

### 3. CountryHubInternalLinks — DONE

Added pSEO hub links to all 4 hubs:
- `/mx` → `/estudiar-ingles-en-canada/para-mexicanos`
- `/co` → `/estudiar-ingles-en-irlanda/para-colombianos`
- `/cl` → `/estudiar-ingles-en-canada/para-chilenos`
- `/ar` → `/estudiar-ingles-en-irlanda/para-argentinos`

### 4. Duration as Separate Strapi Records

Each duration page = separate Strapi record. Not a sub-field on the hub record. Reason: different content, different SEO metadata, different structured data. Hub and duration records share a `parent_hub` relation field.

### 4. Hub Pages — Add Destination Card

Each existing country hub (`/co`, `/mx`, `/cl`, `/ar`) needs:
- "Estudiar en {destination}" card added to hub page
- Card links to pSEO hub
- This passes authority and creates crawl path

---

## Structured Data

**Hub page:** FAQPage + EducationalOrganization (the agency) + BreadcrumbList  
**Duration pages:** FAQPage + Course (with duration, price range) + BreadcrumbList  
**All pages:** BreadcrumbList showing `Home > /cc hub > pSEO hub > duration page`

---

## Content Rules

- Visa rules, prices, dates: manually verified only, never LLM-generated
- Claude (via n8n) writes ONLY: intro prose, FAQ answers, persona descriptions
- Every page has `last_verified_date` visible to users (E-E-A-T)
- Every page has a named human reviewer with photo (E-E-A-T)
- School photos: use school press kit images (free use), never stock
- Testimonials: real student, real name, real photo or YouTube embed

---

## Launch Order

| Phase | Pages | Key asset |
|---|---|---|
| 1 | `/co/estudiar-en-irlanda/` + 4 duration pages | Seed data already prepared |
| 2 | `/mx/estudiar-en-canada/` + 4 duration pages | YouTube testimonial ready |
| 3 | `/cl/estudiar-en-canada/` + 4 duration pages | — |
| 4 | `/ar/estudiar-en-irlanda/` + 4 duration pages | "Sin visa" framing needs care |
| 5 | City pages (desde-monterrey, desde-santiago) | After ranking data from phases 1–2 |
| 6 | New countries (/pe, etc.) | After stub hub created |

---

## Success Metrics (Month 6)

- 40–60 live pSEO pages (hub + duration per combo)
- 2,000–4,000 monthly organic sessions from pSEO
- 40–80 WhatsApp opens/month from pSEO
- 3–6 paid enrollments/month attributable to pSEO
- €1,200–€3,000/month attributable revenue

---

## Hard Rules (unchanged from v1)

- Never auto-publish — human review gate always
- Never let LLM write visa rules, prices, or dates
- Never break existing `/ar/` `/co/` `/cl/` `/mx/` URLs
- Never redirect old pages to pSEO URLs until pSEO proves it outranks
- Never deploy without testing on staging first
- Max 5 pages/day from n8n generation workflow
