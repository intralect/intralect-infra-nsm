#!/usr/bin/env python3
"""
Import school-seed-canada.json into Strapi.

Usage:
    python3 import-schools-canada.py <API_TOKEN>

Get token: https://cms.yaicos.com/admin → Settings → API Tokens
"""

import sys
import json
import time
import requests

STRAPI = "https://cms.yaicos.com"

if len(sys.argv) < 2:
    print("Usage: python3 import-schools-canada.py <API_TOKEN>")
    sys.exit(1)

TOKEN = sys.argv[1]
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}
SEED_FILE = "/root/scripts/school-seed-canada.json"

with open(SEED_FILE) as f:
    seed = json.load(f)


def post(endpoint, data):
    r = requests.post(f"{STRAPI}/api/{endpoint}", headers=HEADERS, json={"data": data})
    if r.status_code not in (200, 201):
        print(f"  ERROR {r.status_code}: {r.text[:400]}")
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


# Resolve destination slugs → IDs upfront
dest_cache: dict[str, int] = {}

def get_dest_id(slug: str) -> int | None:
    if slug in dest_cache:
        return dest_cache[slug]
    r = requests.get(f"{STRAPI}/api/destinations?filters[slug][$eq]={slug}", headers=HEADERS)
    items = r.json().get("data", [])
    if not items:
        return None
    dest_cache[slug] = items[0]["id"]
    return dest_cache[slug]


print("\n=== Importing Canadian Schools ===\n")

for school in seed["schools"]:
    dest_slug = school.pop("_destination_slug", None)

    name = school["name"]
    slug = school["slug"]

    existing = get_by_slug("yaicos-schools", slug)
    if existing:
        print(f"  SKIP (exists): {name} → id {existing['id']}")
        continue

    if dest_slug:
        dest_id = get_dest_id(dest_slug)
        if dest_id:
            school["destination"] = dest_id
        else:
            print(f"  WARN: destination '{dest_slug}' not found — skipping relation")

    result = post("yaicos-schools", school)
    if result:
        rid = result["id"]
        published = publish("yaicos-schools", rid)
        status = "PUBLISHED" if published else "DRAFT"
        print(f"  OK [{status}]: {name} → id {rid}")
    else:
        print(f"  FAILED: {name}")

    time.sleep(0.5)

print("\n=== Done ===")
print("Check: https://cms.yaicos.com/admin/content-manager/collection-types/api::yaicos-school.yaicos-school")
