#!/usr/bin/env python3
"""
Import pseo-seed-canada-ar-mx-cl.json into Strapi.

Usage:
    python3 import-pseo-canada.py <API_TOKEN>

Get token from: https://cms.yaicos.com/admin → Settings → API Tokens
Pick "claudecode" or any full-access token and regenerate/copy it.
"""

import sys
import json
import time
import requests

STRAPI = "https://cms.yaicos.com"

if len(sys.argv) < 2:
    print("Usage: python3 import-pseo-canada.py <API_TOKEN>")
    sys.exit(1)

TOKEN = sys.argv[1]
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}
SEED_FILE = "/root/scripts/pseo-seed-canada-ar-mx-cl.json"

with open(SEED_FILE) as f:
    seed = json.load(f)


def post(endpoint, data):
    r = requests.post(f"{STRAPI}/api/{endpoint}", headers=HEADERS, json={"data": data})
    if r.status_code not in (200, 201):
        print(f"  ERROR {r.status_code}: {r.text[:300]}")
        return None
    return r.json().get("data", {})


def get_by_slug(endpoint, slug):
    r = requests.get(f"{STRAPI}/api/{endpoint}?filters[slug][$eq]={slug}", headers=HEADERS)
    items = r.json().get("data", [])
    return items[0] if items else None


def publish(endpoint, record_id):
    r = requests.put(
        f"{STRAPI}/api/{endpoint}/{record_id}",
        headers=HEADERS,
        json={"data": {"publishedAt": "2026-04-22T00:00:00.000Z"}}
    )
    return r.status_code in (200, 201)


print("\n=== 1. Nationalities ===")
nat_ids = {}
for n in seed["nationalities"]:
    existing = get_by_slug("nationalities", n["slug"])
    if existing:
        nat_ids[n["slug"]] = existing["id"]
        print(f"  SKIP (exists): {n['slug']} → id {existing['id']}")
        continue
    result = post("nationalities", n)
    if result:
        nat_ids[n["slug"]] = result["id"]
        print(f"  OK: {n['slug']} → id {result['id']}")
    time.sleep(0.3)

print("\n=== 2. Destinations ===")
dest_ids = {}
for d in seed["destinations"]:
    existing = get_by_slug("destinations", d["slug"])
    if existing:
        dest_ids[d["slug"]] = existing["id"]
        print(f"  SKIP (exists): {d['slug']} → id {existing['id']}")
        continue
    result = post("destinations", d)
    if result:
        dest_ids[d["slug"]] = result["id"]
        print(f"  OK: {d['slug']} → id {result['id']}")
    time.sleep(0.3)

print("\n=== 3. Visa Matrix ===")
for vm in seed["visa_matrix"]:
    nat_slug = vm.pop("_nationality_slug")
    dest_slug = vm.pop("_destination_slug")
    nat_id = nat_ids.get(nat_slug)
    dest_id = dest_ids.get(dest_slug)
    if not nat_id or not dest_id:
        print(f"  SKIP: missing id for {nat_slug}→{dest_slug}")
        continue
    # Check if already exists
    r = requests.get(
        f"{STRAPI}/api/visa-matrices?filters[nationality][slug][$eq]={nat_slug}&filters[destination][slug][$eq]={dest_slug}",
        headers=HEADERS
    )
    if r.json().get("data"):
        print(f"  SKIP (exists): {nat_slug}→{dest_slug}")
        continue
    vm["nationality"] = nat_id
    vm["destination"] = dest_id
    result = post("visa-matrices", vm)
    if result:
        print(f"  OK: {nat_slug}→{dest_slug} → id {result['id']}")
    time.sleep(0.3)

print("\n=== 4. pSEO Pages ===")
for page in seed["pseo_pages"]:
    comment = page.pop("_comment", "")
    nat_slug = page.pop("_nationality_slug")
    dest_slug = page.pop("_destination_slug")
    nat_id = nat_ids.get(nat_slug)
    dest_id = dest_ids.get(dest_slug)

    slug = page["slug"]

    # Check if exists
    existing = requests.get(
        f"{STRAPI}/api/pseo-pages?filters[nationality][slug][$eq]={nat_slug}&filters[destination][slug][$eq]={dest_slug}&filters[page_type][$eq]={page['page_type']}" +
        (f"&filters[duration_weeks][$eq]={page['duration_weeks']}" if page.get("duration_weeks") else "&filters[page_type][$eq]=overview"),
        headers=HEADERS
    ).json().get("data", [])

    if existing:
        print(f"  SKIP (exists): {slug}")
        continue

    page["nationality"] = nat_id
    page["destination"] = dest_id

    result = post("pseo-pages", page)
    if result:
        rid = result["id"]
        published = publish("pseo-pages", rid)
        status = "PUBLISHED" if published else "DRAFT"
        print(f"  OK [{status}]: {slug} → id {rid}")
    else:
        print(f"  FAILED: {slug}")
    time.sleep(0.5)

print("\n=== Done ===")
print("Check: https://cms.yaicos.com/admin/content-manager/collection-types/api::pseo-page.pseo-page")
