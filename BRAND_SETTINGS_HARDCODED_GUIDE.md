# Hard-Coded Brand Settings Guide

**Status:** ✅ Implemented and Ready
**Location:** `/root/scripts/mautic-n8n-stack/strapi/src/services/gemini.js` (Lines 85-154)

---

## What Was Implemented

I've added **hard-coded brand-specific settings** directly in the code. Each collection (Yaicos, Amabex, GuardScan) now has its own customized image generation settings.

### How It Works

When you generate an image:
1. System detects which collection you're in (Yaicos, Amabex, or GuardScan)
2. Loads the corresponding brand settings from code
3. Generates images using those specific guidelines
4. Results in consistent, brand-appropriate imagery

---

## Where to Edit Brand Settings

### File Location
```
/root/scripts/mautic-n8n-stack/strapi/src/services/gemini.js
```

### Lines to Edit
**Lines 85-154** contain the `BRAND_SETTINGS` object

### How to Find It
1. Open the file: `strapi/src/services/gemini.js`
2. Look for this big comment:
```javascript
// ═══════════════════════════════════════════════════════════════════════
// HARD-CODED BRAND SETTINGS - EASY TO EDIT
// ═══════════════════════════════════════════════════════════════════════
```
3. Right below is the `BRAND_SETTINGS` object

---

## Current Brand Settings

### Yaicos (International Students)

```javascript
'yaicos-article': {
  brandName: 'Yaicos',
  targetAudience: 'International students aged 18-30 seeking education and career opportunities',
  visualStyle: 'friendly, welcoming, modern, educational, vibrant, aspirational',
  colorPalette: 'bright blues (#2196F3), warm oranges (#FF9800), energetic yellows (#FFC107), white backgrounds',
  includeHumans: true, // ⭐ SHOWS PEOPLE
  humanRepresentation: 'diverse international students from Asian, African, European, Latin American, and Middle Eastern backgrounds, aged 18-30, shown from behind or at angles (no direct faces), engaged in learning activities, collaborative work, campus life',
  tone: 'friendly and aspirational',
  additionalGuidelines: 'Images should feel welcoming and inspiring. Show diversity and international representation. Include students in realistic educational or campus settings. Focus on connection, learning, and opportunity. Similar to modern educational platforms like Coursera or Duolingo. Avoid stock photo poses - use natural, candid scenarios.',
  avoidElements: 'text, logos, cluttered elements, stock photo poses'
}
```

**Key Features:**
- ✅ Includes diverse international students
- ✅ Bright, friendly colors (blues/oranges/yellows)
- ✅ Educational and aspirational tone
- ✅ Natural, candid scenarios (not stock photos)

---

### Amabex (Corporate Procurement)

```javascript
'amabex-article': {
  brandName: 'Amabex',
  targetAudience: 'Corporate procurement professionals and business decision-makers',
  visualStyle: 'corporate, professional, trustworthy, sophisticated, clean, systematic',
  colorPalette: 'corporate blues (#003D7A, #0066CC), silver/gray accents (#7C8B9C), white, minimal use of color',
  includeHumans: false, // ⭐ NO PEOPLE
  humanRepresentation: null,
  tone: 'corporate and professional',
  additionalGuidelines: 'Images should convey trust, efficiency, and professionalism. Use abstract representations of procurement processes, supply chains, business networks, or enterprise systems. Focus on structure, data visualization, and systematic approaches. Maintain a serious, corporate aesthetic similar to Fortune 500 companies. Show business workflows, organizational charts, or process diagrams in a clean, modern style.',
  avoidElements: 'text, logos, faces, hands, informal elements, bright colors, consumer imagery'
}
```

**Key Features:**
- ❌ No people - abstract corporate visuals
- ✅ Corporate blues and grays only
- ✅ Professional, systematic, trustworthy
- ✅ Business processes and workflows

---

### GuardScan (Cybersecurity)

```javascript
'guardscan-article': {
  brandName: 'GuardScan',
  targetAudience: 'IT security professionals, system administrators, CISOs, and cybersecurity teams',
  visualStyle: 'technical, secure, high-tech, cutting-edge, sophisticated, dramatic',
  colorPalette: 'deep blues (#001F3F), cyber green (#00FF41), electric blue (#00D4FF), dark backgrounds (#0A0E27), neon accents',
  includeHumans: false, // ⭐ NO PEOPLE
  humanRepresentation: null,
  tone: 'technical and cutting-edge',
  additionalGuidelines: 'Images should feel technically sophisticated and cutting-edge. Use advanced visualizations of networks, encryption, data protection, threat detection, and security systems. Include circuit patterns, digital shields, encrypted data streams, network topologies, or security architecture diagrams. Avoid cliché padlock or simple shield imagery. Focus on enterprise-grade security visualization similar to platforms like CrowdStrike, Palo Alto Networks, or high-end SOC (Security Operations Center) environments. Use Matrix-style aesthetics with digital elements.',
  avoidElements: 'text, logos, faces, hands, generic security symbols, consumer-grade imagery, simple padlocks'
}
```

**Key Features:**
- ❌ No people - technical visualizations
- ✅ Dark backgrounds with cyber green/blue accents
- ✅ High-tech, Matrix-style aesthetics
- ✅ Advanced security visualizations

---

## How to Customize

### Step 1: Open the File

```bash
nano /root/scripts/mautic-n8n-stack/strapi/src/services/gemini.js
```

Or use VS Code, SSH editor, etc.

### Step 2: Find the Brand Settings Section

Search for: `BRAND_SETTINGS`

Or scroll to **line 90**

### Step 3: Edit the Settings

Example - Change Yaicos colors:

**Before:**
```javascript
colorPalette: 'bright blues (#2196F3), warm oranges (#FF9800), energetic yellows (#FFC107), white backgrounds',
```

**After:**
```javascript
colorPalette: 'royal purple (#6200EA), bright pink (#E91E63), gold accents (#FFD700), white backgrounds',
```

### Step 4: Restart Strapi

```bash
cd /root/scripts/mautic-n8n-stack
docker compose restart strapi
```

Wait 30 seconds for Strapi to reload.

### Step 5: Test

1. Go to the collection you edited
2. Generate a new image
3. Check if it uses your new settings

---

## What You Can Edit

### Brand Name
```javascript
brandName: 'Your Brand Name'
```
Changes how the brand is referenced in prompts.

---

### Target Audience
```javascript
targetAudience: 'Who this content is for'
```

**Examples:**
- "College students interested in study abroad"
- "C-level executives in Fortune 500 companies"
- "Security engineers at tech startups"

---

### Visual Style
```javascript
visualStyle: 'style keywords separated by commas'
```

**Examples:**
- "minimalist, clean, Scandinavian, simple"
- "bold, energetic, playful, colorful"
- "serious, corporate, traditional, formal"

---

### Color Palette
```javascript
colorPalette: 'colors with hex codes'
```

**IMPORTANT:** Include hex codes for precision!

**Examples:**
- "navy blue (#003366), gold (#FFD700), white"
- "forest green (#228B22), earth tones, natural"
- "monochrome grays (#666666), minimal black/white"

---

### Include Humans
```javascript
includeHumans: true  // or false
```

- `true` = AI will include people in images
- `false` = AI will NOT include people

**Note:** If `true`, you MUST also set `humanRepresentation`

---

### Human Representation
```javascript
humanRepresentation: 'description of people to show'
```

**Only used if `includeHumans: true`**

**Good Example:**
```javascript
humanRepresentation: 'diverse professionals aged 25-40, various ethnicities, business casual attire, shown from behind or at angles (no direct face shots), engaged in collaborative work'
```

**Important:** Always specify "shown from behind or at angles (no direct faces)" for privacy.

---

### Tone
```javascript
tone: 'overall mood'
```

**Examples:**
- "friendly and approachable"
- "serious and professional"
- "innovative and forward-thinking"
- "technical and precise"

---

### Additional Guidelines
```javascript
additionalGuidelines: 'Any extra instructions for AI'
```

Use this for:
- Style references ("Similar to Apple's design aesthetic")
- Specific requirements ("Must include data visualization")
- What to emphasize ("Focus on innovation and technology")

**Example:**
```javascript
additionalGuidelines: 'Images should feel luxurious and premium. Reference high-end fashion magazines like Vogue. Use dramatic lighting and sophisticated compositions. Emphasize elegance and exclusivity.'
```

---

### Avoid Elements
```javascript
avoidElements: 'things to never include'
```

**Always avoid:**
- text, logos (legal issues)
- faces (privacy)

**Additional examples:**
- "cluttered backgrounds"
- "generic stock photo imagery"
- "cliché symbols (lightbulbs, arrows, handshakes)"

---

## Example Customizations

### Example 1: Make Yaicos More Playful

```javascript
'yaicos-article': {
  brandName: 'Yaicos',
  targetAudience: 'International students aged 18-25',
  visualStyle: 'playful, fun, energetic, youthful, vibrant, Instagram-worthy',
  colorPalette: 'hot pink (#FF1493), electric blue (#00BFFF), sunshine yellow (#FFD700), white',
  includeHumans: true,
  humanRepresentation: 'Gen Z students (18-25), very diverse, casual streetwear style, shown celebrating, studying together, exploring new cities, from behind or side angles',
  tone: 'fun and energetic',
  additionalGuidelines: 'Images should feel like Instagram posts. Use trendy compositions, bright saturated colors, and Gen Z aesthetics. Show real college life - coffee shops, libraries, campus events, travel. No formal or corporate vibes.',
  avoidElements: 'text, logos, formal settings, business attire, stock photo poses'
}
```

---

### Example 2: Make Amabex More Modern

```javascript
'amabex-article': {
  brandName: 'Amabex',
  targetAudience: 'Modern procurement professionals at tech companies',
  visualStyle: 'modern, tech-forward, innovative, clean, startup-inspired',
  colorPalette: 'electric blue (#0066FF), bright teal (#00CED1), white, minimal gray accents',
  includeHumans: false,
  tone: 'modern and innovative',
  additionalGuidelines: 'Images should feel more like a tech startup than traditional corporate. Use modern flat design, clean infographics, and innovative data visualizations. Think Stripe or Notion aesthetics - clean, colorful, modern. Show smart automation and AI-powered processes.',
  avoidElements: 'text, logos, faces, traditional corporate imagery, outdated design styles'
}
```

---

### Example 3: Make GuardScan More Dramatic

```javascript
'guardscan-article': {
  brandName: 'GuardScan',
  targetAudience: 'Security professionals and ethical hackers',
  visualStyle: 'dramatic, intense, cyberpunk, hacker aesthetic, high-tech',
  colorPalette: 'neon green (#39FF14), electric purple (#BF00FF), deep blacks (#000000), red alerts (#FF0000)',
  includeHumans: false,
  tone: 'intense and dramatic',
  additionalGuidelines: 'Images should feel like a cybersecurity thriller movie. Heavy cyberpunk aesthetics with Matrix-style cascading code, neon colors on dark backgrounds, dramatic lighting. Show active threat detection, red alert warnings, network intrusions being blocked. Make it feel urgent and high-stakes like a SOC during an active breach.',
  avoidElements: 'text, logos, faces, simple security symbols, corporate clean aesthetics, bright backgrounds'
}
```

---

## Testing Your Changes

### Quick Test
1. Edit the brand settings
2. Restart Strapi
3. Create test article in that collection
4. Generate image
5. Check results

### A/B Testing
1. Take screenshot of current image style
2. Edit settings
3. Restart Strapi
4. Generate new image with SAME title
5. Compare before/after

### Refine
- Too generic? Add more specific guidelines
- Wrong colors? Update colorPalette with hex codes
- Wrong people? Update humanRepresentation
- Wrong tone? Adjust visualStyle and tone fields

---

## Common Modifications

### Change Colors
```javascript
colorPalette: 'your new colors with #hex codes'
```

### Add/Remove People
```javascript
includeHumans: true  // or false
```

### Change Target Audience
```javascript
targetAudience: 'new audience description'
```

### Update Brand Voice
```javascript
tone: 'new tone description',
visualStyle: 'new style keywords',
```

### Add Reference Brands
```javascript
additionalGuidelines: 'Similar to [Brand Name] aesthetic. Reference their style in [specific way].'
```

---

## After Editing

### Always Restart Strapi
```bash
cd /root/scripts/mautic-n8n-stack
docker compose restart strapi
```

### Wait for Startup
```bash
sleep 30
docker compose logs strapi | tail -20
```

Look for "Welcome back!" message.

---

## Troubleshooting

### Images Not Using New Settings

**Problem:** Generated images still use old style

**Solutions:**
1. Verify you edited the correct collection name
   - Check: `'yaicos-article'` not `'yaicos'`
2. Ensure you restarted Strapi
3. Clear browser cache and try again
4. Check Strapi logs for errors

---

### Syntax Errors After Editing

**Problem:** Strapi won't start after editing

**Solutions:**
1. Check for missing commas between fields
2. Ensure all quotes are properly closed
3. Verify JavaScript syntax (use a linter)
4. Revert to original and try again

---

### Images Still Generic

**Problem:** AI not following guidelines

**Solutions:**
1. Be MORE specific in `additionalGuidelines`
2. Add more detail to `visualStyle`
3. Include reference brands in `additionalGuidelines`
4. Add specific elements to avoid in `avoidElements`

---

## Benefits of Hard-Coded Approach

✅ **Simple** - Just edit one file, no database needed
✅ **Version Control** - Track changes in git
✅ **No Breaking** - Can't accidentally break Strapi
✅ **Fast** - No API calls to load settings
✅ **Documented** - Settings are self-documented in code
✅ **Portable** - Easy to copy settings between servers

---

## File Locations Reference

**Main file to edit:**
```
/root/scripts/mautic-n8n-stack/strapi/src/services/gemini.js
```

**Lines to edit:**
```
Lines 85-154 (BRAND_SETTINGS object)
```

**How to access:**
```bash
# Via nano
nano /root/scripts/mautic-n8n-stack/strapi/src/services/gemini.js

# Or via vim
vim /root/scripts/mautic-n8n-stack/strapi/src/services/gemini.js
```

**Jump to line 90:**
```
# In nano: Ctrl+_ then type 90
# In vim: :90 then Enter
```

---

## Quick Reference Card

| Setting | What It Does | Example |
|---------|--------------|---------|
| `brandName` | Brand identity | "Yaicos" |
| `targetAudience` | Who content is for | "International students" |
| `visualStyle` | Overall aesthetic | "friendly, modern, vibrant" |
| `colorPalette` | Exact colors to use | "blue (#2196F3), orange (#FF9800)" |
| `includeHumans` | Show people or not | `true` or `false` |
| `humanRepresentation` | Type of people | "diverse students, ages 18-30" |
| `tone` | Mood and feeling | "friendly and aspirational" |
| `additionalGuidelines` | Extra instructions | "Similar to Coursera style" |
| `avoidElements` | Never include | "text, logos, stock poses" |

---

**Ready to use!** Edit the settings at your convenience and restart Strapi to apply changes. ✅

**File Location:** `/root/scripts/mautic-n8n-stack/strapi/src/services/gemini.js` (Lines 85-154)
