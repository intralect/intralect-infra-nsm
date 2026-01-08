# n8n Automation Plan - Google Sheets to Social Media

**Status:** 📋 Planned (Not Yet Built)
**Next Session Goal:** Build this automation workflow

## Workflow Overview

```
Daily Schedule Trigger (9 AM)
  ↓
Google Sheets: Read new rows
  ↓
Loop through each row:
  ↓
  HTTP Request: Generate blog draft (/api/ai/generate-blog-draft)
  ↓
  HTTP Request: Generate SEO metadata (/api/ai/generate-seo)
  ↓
  HTTP Request: Generate excerpt (/api/ai/generate-excerpt)
  ↓
  HTTP Request: Generate featured image (/api/ai/generate-image)
  ↓
  Strapi: Create draft article (status: draft)
  ↓
  Send Email: Approval notification with preview link
  ↓
  Wait for Webhook: Approval response
  ↓
  If Approved:
    ↓
    Strapi: Publish article (set publishedAt)
    ↓
    Facebook: Create post with link + image
    ↓
    Instagram: Create post with image + caption
    ↓
    Google Sheets: Update row (status: published, URL)
  ↓
  If Rejected:
    ↓
    Google Sheets: Update row (status: rejected, reason)
```

## Google Sheet Setup

### Sheet Name: `Blog Content Queue`

### Columns:
| Column | Type | Description |
|--------|------|-------------|
| Topic | Text | Blog article title/topic |
| Keywords | Text | Comma-separated keywords |
| Outline | Text | Optional structure guide |
| Status | Dropdown | pending, generating, review, approved, published, rejected |
| Approved | Checkbox | Manual approval flag |
| Article URL | Text | Auto-filled after publish |
| FB Post URL | Text | Auto-filled after FB post |
| IG Post URL | Text | Auto-filled after IG post |
| Scheduled Date | Date | When to publish |
| Generated Date | Date | When draft was created |
| Notes | Text | Rejection reason or notes |

### Example Row:
```
Topic: "Best Marketing Tools 2026"
Keywords: "marketing, automation, AI, tools"
Outline: "Introduction, Top 5 Tools, Pricing Comparison, Conclusion"
Status: "pending"
Approved: [ ]
Article URL: [empty]
FB Post URL: [empty]
IG Post URL: [empty]
Scheduled Date: 2026-01-10
Generated Date: [empty]
Notes: [empty]
```

## n8n Nodes Required

### 1. Schedule Trigger
- **Type:** Schedule Trigger
- **Cron:** `0 9 * * *` (Daily at 9 AM)
- **Name:** "Daily Content Check"

### 2. Google Sheets
- **Type:** Google Sheets
- **Operation:** Read rows
- **Filter:** Where Status = "pending"
- **Name:** "Read Pending Topics"

### 3. Loop Node
- **Type:** Split In Batches
- **Batch Size:** 1
- **Name:** "Process Each Topic"

### 4. HTTP Request - Blog Draft
- **Type:** HTTP Request
- **Method:** POST
- **URL:** `https://cms.yaicos.com/api/ai/generate-blog-draft`
- **Body:**
```json
{
  "topic": "{{ $json.Topic }}",
  "keywords": "{{ $json.Keywords.split(',') }}",
  "outline": "{{ $json.Outline }}"
}
```
- **Name:** "Generate Blog Draft"

### 5. HTTP Request - SEO
- **Type:** HTTP Request
- **Method:** POST
- **URL:** `https://cms.yaicos.com/api/ai/generate-seo`
- **Body:**
```json
{
  "title": "{{ $node['Generate Blog Draft'].json.topic }}",
  "content": "{{ $node['Generate Blog Draft'].json.content }}"
}
```
- **Name:** "Generate SEO"

### 6. HTTP Request - Excerpt
- **Type:** HTTP Request
- **Method:** POST
- **URL:** `https://cms.yaicos.com/api/ai/generate-excerpt`
- **Body:**
```json
{
  "content": "{{ $node['Generate Blog Draft'].json.content }}"
}
```
- **Name:** "Generate Excerpt"

### 7. HTTP Request - Image
- **Type:** HTTP Request
- **Method:** POST
- **URL:** `https://cms.yaicos.com/api/ai/generate-image`
- **Body:**
```json
{
  "title": "{{ $node['Generate Blog Draft'].json.topic }}",
  "content": "{{ $node['Generate Blog Draft'].json.content }}"
}
```
- **Name:** "Generate Image"

### 8. Strapi Create Article
- **Type:** HTTP Request
- **Method:** POST
- **URL:** `https://cms.yaicos.com/api/yaicos-articles`
- **Headers:**
  - `Authorization: Bearer YOUR_STRAPI_TOKEN`
  - `Content-Type: application/json`
- **Body:**
```json
{
  "data": {
    "title": "{{ $json.Topic }}",
    "content": "{{ $node['Generate Blog Draft'].json.content }}",
    "excerpt": "{{ $node['Generate Excerpt'].json.excerpt }}",
    "meta_title": "{{ $node['Generate SEO'].json.metaTitle }}",
    "meta_description": "{{ $node['Generate SEO'].json.metaDescription }}",
    "publishedAt": null,
    "ai_generated": true
  }
}
```
- **Name:** "Create Draft in Strapi"

### 9. Send Email - Approval
- **Type:** Send Email
- **To:** your-email@example.com
- **Subject:** "New Blog Draft Ready: {{ $json.Topic }}"
- **Body:**
```html
<h2>New blog draft ready for review</h2>
<p><strong>Topic:</strong> {{ $json.Topic }}</p>
<p><strong>Preview:</strong> <a href="https://cms.yaicos.com/admin/content-manager/collectionType/api::yaicos-article.yaicos-article/{{ $node['Create Draft in Strapi'].json.data.id }}">View in Strapi</a></p>

<p>Click to approve:</p>
<a href="https://n8n.yaicos.com/webhook/approve-blog?id={{ $node['Create Draft in Strapi'].json.data.id }}&row={{ $json.row }}">✅ APPROVE</a>
<br>
<a href="https://n8n.yaicos.com/webhook/reject-blog?id={{ $node['Create Draft in Strapi'].json.data.id }}&row={{ $json.row }}">❌ REJECT</a>
```
- **Name:** "Send Approval Email"

### 10. Webhook - Wait for Approval
- **Type:** Webhook
- **Path:** `approve-blog`
- **Method:** GET
- **Name:** "Approval Webhook"

### 11. IF Node - Check Approval
- **Type:** IF
- **Condition:** `{{ $json.query.approved }}` equals `true`
- **Name:** "Check if Approved"

### 12. Strapi Publish Article
- **Type:** HTTP Request
- **Method:** PUT
- **URL:** `https://cms.yaicos.com/api/yaicos-articles/{{ $json.query.id }}`
- **Body:**
```json
{
  "data": {
    "publishedAt": "{{ $now }}"
  }
}
```
- **Name:** "Publish Article"

### 13. Facebook Create Post
- **Type:** Facebook
- **Operation:** Create Post
- **Message:**
```
{{ $node['Generate SEO'].json.metaDescription }}

Read more: https://yaicos.com/blog/{{ $node['Publish Article'].json.data.attributes.slug }}
```
- **Link:** `https://yaicos.com/blog/{{ $node['Publish Article'].json.data.attributes.slug }}`
- **Name:** "Post to Facebook"

### 14. Instagram Create Post
- **Type:** Instagram
- **Operation:** Create Post
- **Caption:**
```
{{ $node['Generate Excerpt'].json.excerpt }}

Link in bio!

#marketing #business #automation
```
- **Image URL:** `{{ $node['Generate Image'].json.imageUrl }}`
- **Name:** "Post to Instagram"

### 15. Google Sheets Update
- **Type:** Google Sheets
- **Operation:** Update row
- **Row Number:** `{{ $json.row }}`
- **Values:**
  - Status: "published"
  - Article URL: `https://yaicos.com/blog/{{ $node['Publish Article'].json.data.attributes.slug }}`
  - FB Post URL: `{{ $node['Post to Facebook'].json.post_url }}`
  - IG Post URL: `{{ $node['Post to Instagram'].json.permalink }}`
  - Generated Date: `{{ $now }}`
- **Name:** "Update Sheet - Published"

### 16. Google Sheets Update (Rejection)
- **Type:** Google Sheets
- **Operation:** Update row
- **Row Number:** `{{ $json.row }}`
- **Values:**
  - Status: "rejected"
  - Notes: `{{ $json.query.reason }}`
- **Name:** "Update Sheet - Rejected"

## Authentication Setup Needed

### 1. Strapi API Token
- Go to Strapi Admin → Settings → API Tokens
- Create new token with "Full Access"
- Save token for n8n HTTP nodes

### 2. Google Sheets
- n8n has built-in Google Sheets OAuth
- Connect your Google account
- Grant sheets access

### 3. Facebook
- Create Facebook App
- Get Page Access Token
- Add to n8n credentials

### 4. Instagram
- Connect Instagram Business Account
- Link to Facebook Page
- Get credentials from Facebook Developer

## Alternative: Manual Approval via Google Sheets

If webhook approval is too complex, use this simpler approach:

### Modified Workflow:
```
1-7. Same as above (generate content, create draft)
8. Google Sheets: Update row (Status: "review", Article URL)
9. Schedule Trigger: Every hour
10. Google Sheets: Read rows where Status = "review" AND Approved = TRUE
11. Continue with publishing steps...
```

This allows manual review:
1. Check email notification
2. Open Strapi to review article
3. Check "Approved" box in Google Sheet
4. n8n picks it up on next hourly run

## Testing Strategy

### Phase 1: Generate Content Only
- Test nodes 1-7 (read sheet, generate content)
- Verify API responses
- Don't create Strapi articles yet

### Phase 2: Create Draft Articles
- Add node 8 (create draft in Strapi)
- Test with one row
- Verify draft appears in Strapi

### Phase 3: Add Approval Flow
- Add email notification
- Test manual approval in Google Sheets
- Skip webhook for now

### Phase 4: Social Media
- Add Facebook/Instagram nodes
- Test with published article
- Verify posts appear

### Phase 5: Full Automation
- Connect all nodes
- Test end-to-end with one row
- Monitor for 24 hours
- Scale up to multiple rows

## Estimated Time to Build
- **Basic workflow (no social):** 1-2 hours
- **With social media:** 3-4 hours
- **With webhook approval:** 4-5 hours
- **Testing & refinement:** 2-3 hours

## Files to Create Next Session
1. n8n workflow JSON (export/import ready)
2. Google Sheets template
3. Setup instructions for API tokens
4. Testing checklist

---

**Next Session:** Build this n8n automation workflow
**Prerequisites:**
- Strapi API token
- Google account for Sheets
- Facebook/Instagram credentials (optional for Phase 4)
