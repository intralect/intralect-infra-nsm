# AI Content Generation for Strapi

This Strapi instance is equipped with AI-powered content generation features using Google Gemini and OpenAI APIs.

## Features

✅ **SEO Generation** - Auto-generate meta titles and descriptions
✅ **Excerpt Generation** - Create compelling article summaries
✅ **Image Generation** - Generate featured images with DALL-E 3
✅ **Semantic Search** - Enhanced content discovery with vector embeddings

## API Endpoints

All endpoints are available at `https://cms.yaicos.com/api/ai/`

### 1. Generate SEO Metadata

Generate optimized meta title and description for your content.

**Endpoint:** `POST /api/ai/generate-seo`

**Request:**
```json
{
  "title": "Your Article Title",
  "content": "Your article content here..."
}
```

**Response:**
```json
{
  "metaTitle": "Optimized Meta Title (max 60 chars)",
  "metaDescription": "Compelling meta description with keywords (max 160 chars)"
}
```

**Example:**
```bash
curl -X POST https://cms.yaicos.com/api/ai/generate-seo \
  -H "Content-Type: application/json" \
  -d '{
    "title": "How to Use AI for Content Creation",
    "content": "Artificial intelligence is revolutionizing content creation..."
  }'
```

### 2. Generate Article Excerpt

Create an engaging summary of your article.

**Endpoint:** `POST /api/ai/generate-excerpt`

**Request:**
```json
{
  "content": "Your full article content...",
  "maxLength": 300
}
```

**Response:**
```json
{
  "excerpt": "Your generated excerpt here..."
}
```

**Example:**
```bash
curl -X POST https://cms.yaicos.com/api/ai/generate-excerpt \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Your article content here...",
    "maxLength": 150
  }'
```

### 3. Generate Featured Image

Generate a custom featured image using DALL-E 3.

**Endpoint:** `POST /api/ai/generate-image`

**Request:**
```json
{
  "title": "Your Article Title",
  "content": "Brief description of the article",
  "brand": {
    "style": "modern, professional",
    "colors": "blue and white",
    "avoid": "text, logos, faces"
  }
}
```

**Response:**
```json
{
  "prompt": "The DALL-E prompt that was used",
  "imageUrl": "https://oaidalleapiprodscus.blob.core.windows.net/...",
  "message": "Download and upload to Media Library"
}
```

**Example:**
```bash
curl -X POST https://cms.yaicos.com/api/ai/generate-image \
  -H "Content-Type: application/json" \
  -d '{
    "title": "The Future of Marketing Automation",
    "content": "An in-depth guide to modern marketing tools",
    "brand": {
      "style": "modern, tech-focused",
      "colors": "blue and orange",
      "avoid": "text, logos"
    }
  }'
```

**Note:** You'll need to download the image from the URL and upload it to Strapi's Media Library manually.

### 4. Check AI Services Status

Verify that AI services are configured and available.

**Endpoint:** `GET /api/ai/status`

**Response:**
```json
{
  "gemini": true,
  "openai": true,
  "semanticSearch": true
}
```

**Example:**
```bash
curl https://cms.yaicos.com/api/ai/status
```

## Workflow: Creating a Blog Post with AI

Here's the recommended workflow for creating a new blog post:

### Step 1: Write Your Content
Create your blog post content in the Strapi admin panel at `https://cms.yaicos.com/admin`

### Step 2: Generate SEO Metadata
Use the SEO generation endpoint to create optimized meta tags:

```bash
curl -X POST https://cms.yaicos.com/api/ai/generate-seo \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Your Article Title",
    "content": "Your article content..."
  }'
```

Copy the `metaTitle` and `metaDescription` to your Strapi article's SEO fields.

### Step 3: Generate Excerpt
Create an engaging excerpt for article listings:

```bash
curl -X POST https://cms.yaicos.com/api/ai/generate-excerpt \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Your article content...",
    "maxLength": 200
  }'
```

Paste the excerpt into your article's excerpt field.

### Step 4: Generate Featured Image
Create a custom featured image:

```bash
curl -X POST https://cms.yaicos.com/api/ai/generate-image \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Your Article Title",
    "content": "Brief description",
    "brand": {
      "style": "modern, professional",
      "colors": "blue and white"
    }
  }'
```

1. Copy the image URL from the response
2. Download the image to your computer
3. Upload it to Strapi's Media Library
4. Attach it to your article as the featured image

### Step 5: Publish
Review your content and publish!

## Configuration

### Environment Variables

The following environment variables are configured in the Strapi container:

```env
# Google Gemini API (for SEO and excerpts)
GEMINI_API_KEY=AIzaSyD4cK8RgWZmaEH3wfU_v7JGAaTDVxKaccA

# OpenAI API (for image generation)
OPENAI_API_KEY=sk-proj-...

# Enable semantic search
ENABLE_SEMANTIC_SEARCH=true
```

### AI Models Used

- **Gemini 2.5 Flash** - Fast and efficient model for text generation (SEO, excerpts)
- **DALL-E 3** - High-quality image generation
- **text-embedding-ada-002** - For semantic search (if enabled)

## API Implementation

The AI features are implemented in:

- **Controller:** `src/api/ai/controllers/ai.js`
- **Routes:** `src/api/ai/routes/ai.js`
- **Services:**
  - `src/services/gemini.js` - Gemini API integration
  - `src/services/openai.js` - OpenAI API integration

## Costs

### Google Gemini (Free Tier)
- **15 requests per minute** (free)
- Perfect for SEO and excerpt generation

### OpenAI DALL-E 3
- **~$0.04 per image** (1024x1024)
- **~$0.08 per image** (1792x1024 HD)

## Troubleshooting

### Check AI Status
```bash
curl https://cms.yaicos.com/api/ai/status
```

Should return:
```json
{
  "gemini": true,
  "openai": true,
  "semanticSearch": true
}
```

### Common Issues

**Gemini API Error:**
- Verify the Generative Language API is enabled in Google Cloud Console
- Check that your API key is valid at https://aistudio.google.com/apikey

**OpenAI API Error:**
- Verify your API key is valid at https://platform.openai.com/api-keys
- Check that you have sufficient credits

**Image Generation Timeout:**
- DALL-E 3 can take 10-30 seconds to generate images
- Be patient and wait for the response

## Future Enhancements

Potential improvements to consider:

- [ ] Automatic image upload to Media Library
- [ ] Batch content generation
- [ ] Custom AI prompts per content type
- [ ] Multi-language SEO generation
- [ ] A/B testing for meta descriptions
- [ ] Integration with Strapi admin UI (buttons/panels)

## Support

For issues or questions:
- Check Strapi logs: `docker logs strapi`
- Review API responses for detailed error messages
- Verify environment variables are set correctly

---

**Last Updated:** January 7, 2026
**Strapi Version:** 5.x
**AI Models:** Gemini 2.5 Flash, DALL-E 3
