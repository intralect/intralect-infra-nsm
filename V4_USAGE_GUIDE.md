# V4 Supercharged - Complete Usage Guide

## Quick Start (Your Current Server)

Since you already have V3 running:

```bash
# 1. Upload script to server
scp v4_supercharged_deploy.sh root@your-server:~/scripts/

# 2. SSH to server
ssh root@your-server

# 3. Run script
cd ~/scripts
chmod +x v4_supercharged_deploy.sh
./v4_supercharged_deploy.sh

# 4. Select option 11: "Upgrade to V4"
```

---

## What V4 Adds

| Feature | Description |
|---------|-------------|
| **pgvector** | PostgreSQL extension for semantic search |
| **Full SEO Fields** | meta_title, meta_description, canonical_url, og_image_alt, og_image_width, og_image_height, no_index |
| **Gemini AI** | Content generation, SEO auto-fill, excerpt creation |
| **OpenAI DALL-E 3** | AI image generation for cover images |
| **Embeddings** | Auto-generated on article save for semantic search |
| **Custom API Routes** | /api/ai/* and /api/search/* endpoints |

---

## Upgrade Process

### Step 1: Run Script
```bash
./v4_supercharged_deploy.sh
```

### Step 2: Select "11. Upgrade to V4"

### Step 3: Answer Prompts
```
Strapi subdomain (default: cms): [Enter]
Blog domain 1: guardscan.io
Blog domain 2: yaicos.com
Blog domain 3: amabex.com
OpenAI API Key: sk-xxxxxxxxxxxx
Gemini API Key: AIzaxxxxxxxxxxxx
```

### Step 4: Wait for Deployment
- PostgreSQL upgrades to pgvector image
- Strapi rebuilds with new content types
- Takes 3-5 minutes

### Step 5: Create Strapi Admin
Go to: `https://cms.yaicos.com/admin`

---

## API Keys Setup

### OpenAI (Required for Images + Semantic Search)
1. Go to: https://platform.openai.com/api-keys
2. Create new key
3. Copy `sk-...` key

### Gemini (Required for Content Generation)
1. Go to: https://aistudio.google.com/app/apikey
2. Create API key
3. Copy `AIza...` key

### Add Keys Later (if skipped during install)
```
Menu → 9 (Strapi) → 5 (Configure AI Keys)
```

---

## Enable Public API Access

After Strapi is running:

1. Go to: `https://cms.yaicos.com/admin`
2. **Settings** → **Users & Permissions** → **Roles** → **Public**
3. Enable for each article type:
   - ✅ find
   - ✅ findOne
4. Enable for **Author**:
   - ✅ find
   - ✅ findOne
5. Enable for **Upload**:
   - ✅ find
   - ✅ findOne
6. Enable for **Ai**:
   - ✅ generateSeo
   - ✅ generateExcerpt
   - ✅ generateImage
   - ✅ status
7. Enable for **Search**:
   - ✅ semantic
   - ✅ status
8. Click **SAVE**

---

## Content Type Fields (Auto-Created)

### Article Types (guardscan/yaicos/amabex)

| Field | Type | Description |
|-------|------|-------------|
| title | String | Article title (required, max 100) |
| slug | UID | URL-friendly unique identifier |
| content | Rich Text | Main article content |
| excerpt | Text | Summary (max 300 chars) |
| featured_image | Media | Main image |
| category | Enum | Category selection |
| tags | JSON | Array of tags |
| author | Relation | Link to Author |
| reading_time | Integer | Minutes to read |
| **SEO Fields** | | |
| meta_title | String | SEO title (max 60) |
| meta_description | Text | SEO description (max 160) |
| canonical_url | String | Canonical URL |
| og_image | Media | Open Graph image |
| og_image_alt | String | OG image alt text (max 125) |
| og_image_width | Integer | OG image width (default 1200) |
| og_image_height | Integer | OG image height (default 630) |
| no_index | Boolean | Exclude from search engines |
| **AI Fields** | | |
| embedding | JSON | Vector for semantic search |
| ai_generated | Boolean | Flag if AI-created |

### Author

| Field | Type |
|-------|------|
| name | String (required) |
| slug | UID |
| bio | Text |
| avatar | Media |
| email | Email |
| website | String |
| twitter | String |
| linkedin | String |

---

## AI API Endpoints

### Check AI Status
```bash
curl https://cms.yaicos.com/api/ai/status
```
Response:
```json
{
  "gemini": true,
  "openai": true,
  "semanticSearch": true
}
```

### Generate SEO Metadata
```bash
curl -X POST https://cms.yaicos.com/api/ai/generate-seo \
  -H "Content-Type: application/json" \
  -d '{
    "title": "10 Security Tips for 2025",
    "content": "In this article we explore the top security practices..."
  }'
```
Response:
```json
{
  "metaTitle": "10 Essential Security Tips for 2025 | Expert Guide",
  "metaDescription": "Discover the top 10 security practices to protect your business in 2025. Expert insights on cybersecurity, data protection, and threat prevention."
}
```

### Generate Excerpt
```bash
curl -X POST https://cms.yaicos.com/api/ai/generate-excerpt \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Your full article content here...",
    "maxLength": 300
  }'
```

### Generate Cover Image
```bash
curl -X POST https://cms.yaicos.com/api/ai/generate-image \
  -H "Content-Type: application/json" \
  -d '{
    "title": "10 Security Tips for 2025",
    "content": "Article about cybersecurity...",
    "brand": {
      "style": "modern, professional, tech",
      "colors": "blue and white",
      "avoid": "text, logos, faces"
    }
  }'
```
Response:
```json
{
  "prompt": "A futuristic digital shield protecting...",
  "imageUrl": "https://oaidalleapiprodscus.blob.core.windows.net/...",
  "message": "Download and upload to Media Library"
}
```

### Semantic Search
```bash
curl -X POST https://cms.yaicos.com/api/search/semantic \
  -H "Content-Type: application/json" \
  -d '{
    "query": "how to protect against ransomware",
    "collection": "guardscan_articles",
    "limit": 5
  }'
```

---

## React Frontend Integration

### Fetch Articles with SEO
```javascript
const response = await fetch(
  'https://cms.yaicos.com/api/guardscan-articles?populate=*'
);
const { data } = await response.json();

// Each article now has:
// - data.attributes.meta_title
// - data.attributes.meta_description
// - data.attributes.canonical_url
// - data.attributes.og_image
// - data.attributes.og_image_alt
```

### Use AI to Generate SEO (Admin Tool)
```javascript
const generateSEO = async (title, content) => {
  const response = await fetch('https://cms.yaicos.com/api/ai/generate-seo', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title, content })
  });
  return response.json();
};
```

### Semantic Search Component
```javascript
const SemanticSearch = () => {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);

  const search = async () => {
    const response = await fetch('https://cms.yaicos.com/api/search/semantic', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        query, 
        collection: 'guardscan_articles',
        limit: 10 
      })
    });
    const data = await response.json();
    setResults(data.results);
  };

  return (
    <div>
      <input value={query} onChange={e => setQuery(e.target.value)} />
      <button onClick={search}>Search</button>
      {results.map(article => (
        <div key={article.id}>
          <h3>{article.title}</h3>
          <p>Relevance: {(article.similarity * 100).toFixed(1)}%</p>
        </div>
      ))}
    </div>
  );
};
```

---

## n8n Workflow Ideas

### Auto-Generate SEO on New Draft
1. **Trigger**: Strapi Webhook (on article create)
2. **HTTP Request**: POST to /api/ai/generate-seo
3. **Strapi Node**: Update article with generated SEO
4. **Slack/Email**: Notify editor

### Auto-Generate Cover Image
1. **Trigger**: Strapi Webhook (on article publish)
2. **IF**: No featured_image set
3. **HTTP Request**: POST to /api/ai/generate-image
4. **HTTP Request**: Download image from URL
5. **Strapi Node**: Upload to Media Library
6. **Strapi Node**: Update article with image

### Weekly Content Suggestions
1. **Trigger**: Schedule (Monday 9am)
2. **HTTP Request**: Gemini - "Suggest 5 blog topics for security industry"
3. **Slack**: Post suggestions to #content channel

---

## Menu Structure

```
V4 Supercharged Stack v4.0
Containers: 8
Strapi: ✅
AI: ✅

1.  Status
2.  Start All
3.  Stop All
4.  Restart All
5.  View Logs
6.  Backup →
7.  Update Images
8.  Show Credentials
9.  Strapi →
    ├── 1. View Logs
    ├── 2. Restart
    ├── 3. Rebuild (npm install)
    ├── 4. Create/Update Content Types
    ├── 5. Configure AI Keys
    ├── 6. Test AI Endpoints
    ├── 7. Reindex Embeddings
    ├── 8. API Permissions Help
    └── 9. Back
10. Mautic →
    ├── 1. View Logs
    ├── 2. Restart
    ├── 3. Fix Vendor (PHP error)
    ├── 4. Clear Cache
    └── 5. Back
11. Upgrade to V4
12. Exit
```

---

## Troubleshooting

### Strapi Won't Start
```bash
# Check logs
docker-compose logs -f strapi

# Rebuild
Menu → 9 → 3 (Rebuild)
```

### AI Endpoints Return Error
```bash
# Check status
curl https://cms.yaicos.com/api/ai/status

# If keys missing
Menu → 9 → 5 (Configure AI Keys)
```

### Semantic Search Not Working
1. Ensure OpenAI key is set
2. Ensure ENABLE_SEMANTIC_SEARCH=true in .env
3. Check pgvector extension:
```bash
docker exec strapi-postgres psql -U strapi -d strapi -c "SELECT * FROM pg_extension WHERE extname='vector';"
```

### Mautic PHP Error
```bash
Menu → 10 → 3 (Fix Vendor)
```

### Content Types Missing
```bash
Menu → 9 → 4 (Create/Update Content Types)
```

---

## Cost Estimates

| Service | Usage | Cost |
|---------|-------|------|
| OpenAI Embeddings | 1M tokens | ~$0.10 |
| OpenAI DALL-E 3 | Per image | ~$0.04-0.08 |
| Gemini Pro | 1M tokens | Free tier available |

**Typical monthly usage for small blog:**
- ~100 articles indexed: $0.01
- ~20 images generated: $1.00
- Content generation: Free (Gemini)
- **Total: ~$1-2/month**

---

## Files Created by V4

```
mautic-n8n-stack/
├── .env                          # All credentials + AI keys
├── docker-compose.yml            # V4 with pgvector
├── strapi/
│   ├── package.json              # With AI dependencies
│   ├── config/
│   │   ├── database.js
│   │   ├── server.js
│   │   ├── admin.js
│   │   ├── middlewares.js        # CORS for blog domains
│   │   ├── plugins.js
│   │   └── api.js
│   └── src/
│       ├── index.js              # Bootstrap with AI status
│       ├── admin/app.js
│       ├── services/
│       │   ├── openai.js         # DALL-E + Embeddings
│       │   ├── gemini.js         # Content generation
│       │   └── semantic-search.js
│       └── api/
│           ├── guardscan-article/
│           ├── yaicos-article/
│           ├── amabex-article/
│           ├── author/
│           ├── ai/               # AI endpoints
│           └── search/           # Search endpoints
└── backups/
```

---

## Ready to Go Checklist

- [ ] Run V4 script and select "Upgrade to V4"
- [ ] Enter OpenAI API key
- [ ] Enter Gemini API key
- [ ] Wait for Strapi to build
- [ ] Create Strapi admin account
- [ ] Enable public permissions for APIs
- [ ] Test: `curl https://cms.yaicos.com/api/ai/status`
- [ ] Create first article with AI-generated SEO
- [ ] Generate cover image with AI
- [ ] Connect React frontend to new SEO fields

**You're now ready to create AI-powered content!** 🚀
