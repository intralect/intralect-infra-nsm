# Yaicos pSEO — Data Entry Guide

**Status:** Strapi is live. Schemas are built. This doc explains what needs to go in and what needs human validation before publishing.

---

## What "VALIDAR" means

Fields marked `VALIDAR` in the seed JSON files contain **placeholder or estimated data** that I could not confirm from official sources. These must be verified by the Yaicos team against official Irish Immigration sources before the page is published.

**Never publish a pSEO page with unverified visa data.** Wrong visa info = legal risk + trust damage.

Official source: https://www.irishimmigration.ie/coming-to-study-in-ireland/

---

## Current Stage: Data Loading

The system is built end-to-end:
- ✅ Strapi schemas: `nationality`, `destination`, `visa-matrix`, `pseo-page`
- ✅ Frontend: `PseoPage.tsx` + routes wired in `App.tsx`
- ✅ Seed JSON files ready (see below)
- ⏳ **Waiting on:** manual data entry + human validation

---

## Seed Files

| File | Status | Notes |
|------|--------|-------|
| `pseo-seed-argentina-irlanda.json` | Ready for review | Several VALIDAR fields — check before Strapi entry |
| `pseo-seed-colombia-irlanda.json` | Ready for review | More complete, fewer unknowns |
| `school-seed-atlas-dublin.json` | Ready for Strapi | Atlas Language School Dublin — verify scores/pros/cons |

---

## What to Validate — Argentina Seed

Open `pseo-seed-argentina-irlanda.json` and confirm these fields:

| Field | Placeholder value | Source to check |
|-------|------------------|-----------------|
| Minimum funds required at arrival | Omitted (unknown) | irishimmigration.ie |
| Minimum course weeks for work rights | Not specified | irishimmigration.ie |
| IRP registration cost at landing | Not specified | irishimmigration.ie |
| Work hours: 20h term / 40h holidays | Assumed same as Colombia | Confirm same rule applies |

---

## Data Entry Order in Strapi Admin

Go to: `cms.yaicos.com/admin`

Enter in this exact order (relations depend on it):

### Step 1 — Destination (once, shared)
`Content Manager → Destination → Create`

```
slug: irlanda
display_name_es: Irlanda
country_code: IE
primary_language: ingles
currency: EUR
cost_of_living_monthly_eur: 1400
work_rights_default: part_time_20h
capital_city: Dublín
featured_cities: ["Dublín", "Cork", "Galway", "Limerick"]
last_verified_date: 2026-04-20
```

### Step 2 — Nationality (one per country)
`Content Manager → Nationality → Create`

Copy from `pseo-seed-argentina-irlanda.json` → `nationalities[0]`  
Do NOT enter `pseo_pages` or `visa_matrix_rows` here — Strapi links these automatically.

### Step 3 — Visa Matrix (one row per nationality × destination)
`Content Manager → Visa Matrix → Create`

Copy from seed file → `visa_matrix[0]`  
Link the `nationality` and `destination` relations.

### Step 4 — School (optional but recommended for school cards)
`Content Manager → Yaicos School → Create`

Copy from `school-seed-atlas-dublin.json` → `data`  
Link `destination` relation to `irlanda`.

### Step 5 — pSEO Page
`Content Manager → Pseo Page → Create`

Copy from seed file → `pseo_pages[0]`  
Link `nationality`, `destination`, and optionally `schools_featured`.  
**Save as DRAFT. Do not publish until all VALIDAR fields are confirmed.**

---

## How the Frontend Renders

Once a pSEO page is **published** in Strapi:

```
URL: yaicos.com/estudiar-ingles-en-irlanda/para-argentinos
      ↓
PseoPage.tsx fetches pseo-pages?filters[slug][$eq]=...
      ↓
Renders: visa quick-answer, application steps, school cards, FAQs, WhatsApp CTAs
```

School cards appear only if schools are linked in `schools_featured` relation.

---

## Live URL Pattern

```
/estudiar-{idioma}-en-{destino}/para-{nacionalidad}

Examples:
  /estudiar-ingles-en-irlanda/para-argentinos
  /estudiar-ingles-en-irlanda/para-colombianos
```

---

## What Comes Next (after data is in)

1. Publish Argentina pSEO page → test live URL
2. Enter Colombia data → publish
3. Fix internal links on `/ar/` and `/co/` existing pages (wire school cards to profiles)
4. Submit sitemap to Google Search Console
5. Monitor indexing (Yaicos 14yr domain authority → pages should index within days)
