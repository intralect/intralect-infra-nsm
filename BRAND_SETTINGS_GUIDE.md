# Brand Settings System - Complete Control Over Image Generation

**Date:** 2026-01-07
**Status:** ✅ Live and Active

## Overview

You now have **complete control** over how AI generates images for each collection (Yaicos, Amabex, GuardScan). Each collection can have its own:

- Target audience
- Visual style
- Color palette
- Human representation (include or not)
- Tone and mood
- Custom prompt templates
- Brand-specific guidelines

---

## Quick Start

### Step 1: Access Brand Settings

1. Go to https://cms.yaicos.com/admin
2. Navigate to **Content Manager**
3. Look for **Brand Settings** in the sidebar
4. Click **Create new entry**

### Step 2: Create Settings for Each Collection

You need to create 3 brand settings (one for each collection):

1. **Yaicos** - International students blog
2. **Amabex** - Corporate procurement blog
3. **GuardScan** - Cybersecurity blog

---

## Field Explanations

### Collection Name (Required)
**Dropdown:** `yaicos-article`, `guardscan-article`, or `amabex-article`

This links the brand settings to the specific collection.

---

### Brand Name (Required)
**Example:** "Yaicos", "Amabex", "GuardScan"

The name of your brand. This appears in prompts to give AI context.

---

### Target Audience
**Example:** "International students seeking education opportunities"

Who are you creating content for? This helps AI generate relevant imagery.

**Examples:**
- Yaicos: "International students aged 18-30, multicultural backgrounds"
- Amabex: "Corporate procurement professionals and business decision-makers"
- GuardScan: "IT security professionals, system administrators, CISOs"

---

### Visual Style
**Example:** "friendly, modern, educational, vibrant"

The overall aesthetic feel of your images.

**Examples:**
- Yaicos: "friendly, welcoming, educational, vibrant, aspirational"
- Amabex: "corporate, professional, trustworthy, sophisticated, clean"
- GuardScan: "technical, secure, high-tech, cutting-edge, dramatic"

---

### Color Palette
**Example:** "bright blues (#2196F3), warm oranges (#FF9800), white backgrounds"

Specific colors for your brand. Include hex codes for precision.

**Examples:**
- Yaicos: "bright blues (#2196F3), warm oranges (#FF9800), energetic yellows (#FFC107)"
- Amabex: "corporate blues (#003D7A, #0066CC), silver/gray (#7C8B9C), minimal white"
- GuardScan: "deep blues (#001F3F), cyber green (#00FF41), dark backgrounds, neon accents"

---

### Include Humans (Boolean)
**Toggle:** ON or OFF

Whether to include people in images.

**Recommendations:**
- ✅ Yaicos: **ON** (students, international, diverse)
- ❌ Amabex: **OFF** (corporate, abstract)
- ❌ GuardScan: **OFF** (technical, systems)

---

### Human Representation
**Example:** "diverse international students, young people aged 18-30, engaged in learning"

Only used if "Include Humans" is ON. Describes what type of people to show.

**Important:** AI will show people from behind or at angles (no direct face shots) for privacy.

**Example for Yaicos:**
```
Diverse international students from various cultural backgrounds,
aged 18-30, engaged in learning activities, collaborative work,
campus life, or professional development. Show multicultural
representation with people from Asian, African, European, and
Latin American backgrounds.
```

---

### Tone
**Dropdown:** friendly, professional, corporate, technical, educational, innovative

The mood and feeling of images.

**Examples:**
- Yaicos: **friendly** or **educational**
- Amabex: **corporate**
- GuardScan: **technical**

---

### Custom Prompt Template (Advanced)
**Optional:** Write your own prompt with placeholders

If you want complete control, write a custom prompt template using these placeholders:

**Available Placeholders:**
- `{title}` - Article title
- `{content}` - Article content
- `{category}` - Article category
- `{colors}` - Your color palette
- `{style}` - Your visual style
- `{tone}` - Your tone
- `{target_audience}` - Your target audience
- `{brand_name}` - Your brand name

**Example Custom Template:**
```
Create a {style} blog header image for {brand_name}.

Title: {title}

The image must:
- Use {colors} color scheme
- Appeal to {target_audience}
- Have a {tone} tone
- Show people from diverse backgrounds collaborating
- Be modern and aspirational
- Wide landscape 1792x1024 format

Generate a detailed DALL-E 3 prompt.
```

**Leave blank to use default system prompt** (recommended for most users).

---

### Avoid Elements
**Example:** "text, logos, cluttered elements"

What should NEVER appear in images.

**Defaults (good for most):**
```
text, logos, cluttered elements
```

**For corporate (Amabex):**
```
text, logos, faces, informal elements, bright colors
```

**For technical (GuardScan):**
```
text, logos, faces, generic security symbols, consumer-grade imagery
```

---

### Composition Rules
**Example:** "wide landscape format (16:9), centered subject, professional lighting"

Technical specifications for layout and formatting.

**Default (works well):**
```
wide landscape format (16:9), centered subject with 10% margins,
professional studio lighting from upper-left 45°, golden ratio positioning
```

---

### Additional Guidelines
**Optional:** Any other brand-specific instructions

Extra details to guide AI generation.

**Example for Yaicos:**
```
Images should feel welcoming and aspirational. Show diversity and
international representation. Include students in realistic educational
or campus settings. Focus on connection, learning, and opportunity.
Reference the warm, inclusive style of modern educational platforms like
Coursera or Duolingo.
```

**Example for Amabex:**
```
Images should convey trust, efficiency, and professionalism. Use abstract
representations of procurement processes, supply chains, business networks,
or enterprise systems. Focus on structure, data, and systematic approaches.
Maintain a serious, corporate aesthetic similar to Fortune 500 companies.
```

**Example for GuardScan:**
```
Images should feel cutting-edge and technically sophisticated. Use advanced
visualizations of networks, encryption, data protection, and threat detection.
Include circuit patterns, digital shields, encrypted data streams, or security
architecture. Avoid cliché padlock imagery. Focus on enterprise-grade security
similar to high-end cybersecurity platforms like CrowdStrike or Palo Alto.
```

---

### Reference Image URL
**Optional:** URL to an example image

If you have a reference image that captures your desired style, add the URL here.

**Note:** AI won't copy it, but uses it for style guidance.

---

### Active (Boolean)
**Toggle:** ON or OFF

Whether to use these settings. Turn OFF to temporarily disable without deleting.

---

## Setup Instructions

### For Yaicos (International Students)

```
Collection Name: yaicos-article
Brand Name: Yaicos
Target Audience: International students seeking education and career opportunities
Visual Style: friendly, modern, educational, vibrant
Color Palette: bright blues (#2196F3), warm oranges (#FF9800), energetic yellows, white backgrounds
Include Humans: ✅ YES
Human Representation: diverse international students, young people aged 18-30, multicultural backgrounds, engaging in learning and collaboration
Tone: friendly
Avoid Elements: text, logos, cluttered elements
Composition Rules: wide landscape format (16:9), centered subject with people interacting, bright natural lighting
Additional Guidelines: Images should feel welcoming and aspirational. Show diversity and international representation. Include students in realistic educational or campus settings. Focus on connection, learning, and opportunity.
Active: ✅ YES
```

---

### For Amabex (Corporate Procurement)

```
Collection Name: amabex-article
Brand Name: Amabex
Target Audience: Corporate procurement professionals and business decision-makers
Visual Style: corporate, professional, trustworthy, sophisticated
Color Palette: corporate blues (#003D7A, #0066CC), silver/gray accents (#7C8B9C), white, minimal color
Include Humans: ❌ NO
Human Representation: (leave blank)
Tone: corporate
Avoid Elements: text, logos, faces, informal elements, bright colors
Composition Rules: wide landscape format (16:9), clean centered composition, professional studio lighting
Additional Guidelines: Images should convey trust, efficiency, and professionalism. Use abstract representations of procurement processes, supply chains, or business networks. Focus on structure and systematic approaches. Maintain corporate aesthetic.
Active: ✅ YES
```

---

### For GuardScan (Cybersecurity)

```
Collection Name: guardscan-article
Brand Name: GuardScan
Target Audience: IT security professionals, system administrators, cybersecurity teams
Visual Style: technical, secure, high-tech, cutting-edge
Color Palette: deep blues (#001F3F), cyber green (#00FF41), dark backgrounds, neon accents
Include Humans: ❌ NO
Human Representation: (leave blank)
Tone: technical
Avoid Elements: text, logos, faces, generic security symbols, consumer-grade imagery
Composition Rules: wide landscape format (16:9), centered technical visualization, dramatic lighting with blue/green accents
Additional Guidelines: Images should feel cutting-edge and technically sophisticated. Use advanced visualizations of networks, encryption, data protection, threat detection. Include circuit patterns, digital shields, encrypted data streams. Avoid cliché padlock imagery.
Active: ✅ YES
```

---

## How It Works

### Old Workflow (Before Brand Settings)
```
1. Click "Generate Featured Image"
2. Generic prompt sent to AI
3. Same style for all collections
4. No human representation
5. Limited customization
```

### New Workflow (With Brand Settings)
```
1. You create Brand Settings for Yaicos (include humans, student-focused)
2. User opens Yaicos article
3. Clicks "Generate Featured Image"
4. System loads Yaicos brand settings
5. Prompt customized with:
   - Target audience: international students
   - Include diverse students in image
   - Friendly, educational tone
   - Bright blues and warm oranges
   - Welcoming, aspirational style
6. AI generates image specifically for Yaicos brand
7. Result: Image with diverse students, educational setting, Yaicos colors
```

---

## Testing Your Settings

### Test 1: Create Yaicos Article
1. Create new Yaicos article
2. Title: "How to Apply for Universities Abroad"
3. Add content about international education
4. Select category: "education" or "tutorials-guides"
5. Click "Generate Featured Image"
6. **Expected:** Image with diverse international students, educational setting, bright colors, friendly tone

### Test 2: Create Amabex Article
1. Create new Amabex article
2. Title: "Procurement Automation Best Practices"
3. Add content about business procurement
4. Select category: "business-solutions"
5. Click "Generate Featured Image"
6. **Expected:** Corporate abstract visualization, blues/grays, no people, professional, systematic

### Test 3: Create GuardScan Article
1. Create new GuardScan article
2. Title: "Advanced Threat Detection Techniques"
3. Add content about cybersecurity
4. Select category: "threat-intelligence"
5. Click "Generate Featured Image"
6. **Expected:** Technical security visualization, dark blues/cyber greens, no people, cutting-edge, high-tech

---

## Comparison Examples

### Same Article Title, Different Collections

**Title:** "Getting Started with Cloud Security"

**Yaicos Version:**
- Shows diverse students learning about cloud concepts
- Bright, friendly colors
- Educational setting with laptops
- Aspirational and welcoming

**Amabex Version:**
- Abstract cloud infrastructure diagram
- Corporate blues and grays
- No people, just systems
- Professional and trustworthy

**GuardScan Version:**
- Dark technical visualization
- Encrypted data streams with security shields
- Cyber green accents on dark background
- Cutting-edge and sophisticated

---

## Advanced: Custom Prompt Templates

If default prompts don't work for you, create custom templates.

### Example Custom Template (Yaicos)

```
Create a vibrant, welcoming blog header for {brand_name}, targeting {target_audience}.

Article Title: "{title}"

Requirements:
- Show diverse international students (Asian, African, European, Latin American)
- Ages 18-30, in realistic educational or campus scenarios
- Use {colors} color palette prominently
- Students shown from behind or at angles (no direct faces)
- Modern, aspirational, friendly atmosphere
- {style} visual style
- Wide landscape 1792x1024 format
- Professional lighting, not stock photo style

The image should make viewers feel inspired and included.

Generate a detailed DALL-E 3 prompt based on "{title}".
```

### Using Placeholders

When you write custom templates, use these:

```
{title} → "How to Apply for Universities Abroad"
{content} → (first 800 chars of article)
{category} → "education"
{colors} → "bright blues (#2196F3), warm oranges"
{style} → "friendly, modern, educational"
{tone} → "friendly"
{target_audience} → "international students"
{brand_name} → "Yaicos"
```

---

## Troubleshooting

### Images Still Look Generic

**Problem:** Images not using brand settings

**Solutions:**
1. Check that Brand Settings exist in Strapi
2. Verify collection_name matches exactly (e.g., "yaicos-article")
3. Ensure "Active" toggle is ON
4. Restart Strapi: `docker compose restart strapi`

### No Humans Showing (When Include Humans is ON)

**Problem:** AI ignoring human representation

**Solutions:**
1. Make human_representation field more specific
2. Add to Additional Guidelines: "MUST include people as described"
3. Check if "Avoid Elements" includes "faces" (should allow angles/back views)

### Wrong Colors Being Used

**Problem:** AI not using your color palette

**Solutions:**
1. Include hex codes in color_palette field
2. Make colors more specific: "Use ONLY bright blue #2196F3 and warm orange #FF9800"
3. Add to Additional Guidelines: "Color palette is mandatory and must be followed exactly"

### Brand Settings Not Loading

**Problem:** System using defaults instead of your settings

**Solutions:**
1. Check Strapi logs: `docker compose logs strapi | tail -50`
2. Verify API endpoint working: `curl https://cms.yaicos.com/api/brand-settings`
3. Ensure only ONE setting per collection (no duplicates)

---

## API Integration

### Fetch Brand Settings

```javascript
// Get all brand settings
const response = await fetch('https://cms.yaicos.com/api/brand-settings');
const settings = await response.json();

// Get specific collection settings
const yaicoSettings = await fetch(
  'https://cms.yaicos.com/api/brand-settings?filters[collection_name][$eq]=yaicos-article'
);
```

### Manual Image Generation with Brand Settings

```javascript
const response = await fetch('https://cms.yaicos.com/api/ai/generate-image', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    title: 'Your Article Title',
    content: 'Article content here...',
    category: 'education',
    collectionType: 'yaicos-article', // This loads brand settings!
    brand: {
      // These are overridden by brand settings if they exist
      style: 'modern',
      colors: 'blue'
    }
  })
});
```

---

## Benefits

### Before Brand Settings
- ❌ Same style for all collections
- ❌ No control over visual style
- ❌ No human representation
- ❌ Generic corporate look
- ❌ Hard-coded in code (need developer to change)

### After Brand Settings
- ✅ Unique style per collection
- ✅ Complete control from admin panel
- ✅ Can include people (or not)
- ✅ Brand-specific colors and tone
- ✅ No code changes needed
- ✅ Test and iterate easily
- ✅ Reference images for guidance
- ✅ Custom prompt templates

---

## Files Created

1. `/strapi/src/api/brand-settings/content-types/brand-settings/schema.json` - Data structure
2. `/strapi/src/api/brand-settings/controllers/brand-settings.js` - API controller
3. `/strapi/src/api/brand-settings/services/brand-settings.js` - Service layer
4. `/strapi/src/api/brand-settings/routes/brand-settings.js` - API routes

## Files Modified

1. `/strapi/src/api/ai/controllers/ai.js` - Loads brand settings
2. `/strapi/src/services/gemini.js` - Uses brand settings in prompts
3. `/strapi/src/admin/extensions/ai-generation-panel/components/AIGenerationPanel.js` - Sends collection type

---

## Next Steps

1. ✅ Restart Strapi (if not done)
2. ✅ Go to Content Manager > Brand Settings
3. ✅ Create settings for Yaicos
4. ✅ Create settings for Amabex
5. ✅ Create settings for GuardScan
6. ✅ Test image generation in each collection
7. ✅ Refine settings based on results
8. ✅ Share example images with team

---

**You now have complete control over AI image generation for each brand!** 🎨✨

**Status:** Ready to configure
**Access:** https://cms.yaicos.com/admin → Content Manager → Brand Settings
