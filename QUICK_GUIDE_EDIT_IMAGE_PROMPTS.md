# Quick Guide: How to Tweak Image Prompts

**For:** Non-developers who want to customize AI-generated images
**Time:** 5 minutes to edit, 30 seconds to apply

---

## What You Can Control

Each brand (Yaicos, Amabex, GuardScan) has these customizable settings:

1. **Colors** - Exact colors with hex codes
2. **People** - Include or exclude humans in images
3. **Style** - Visual aesthetic (friendly, corporate, technical)
4. **Tone** - Overall mood (aspirational, professional, cutting-edge)
5. **Guidelines** - Specific instructions for AI

---

## Where to Edit

### File Location
```
/root/scripts/mautic-n8n-stack/strapi/src/services/gemini.js
```

### Find This Section
Open the file and search for:
```
HARD-CODED BRAND SETTINGS - EASY TO EDIT
```

Or go to **Line 90**

---

## Quick Edits (Copy & Paste)

### Change Yaicos Colors (Make it Purple)

**Find this line (around line 95):**
```javascript
colorPalette: 'bright blues (#2196F3), warm oranges (#FF9800), energetic yellows (#FFC107), white backgrounds',
```

**Replace with:**
```javascript
colorPalette: 'royal purple (#6200EA), bright pink (#E91E63), gold (#FFD700), white backgrounds',
```

---

### Make Amabex More Modern/Tech

**Find this section (around line 107):**
```javascript
visualStyle: 'corporate, professional, trustworthy, sophisticated, clean, systematic',
colorPalette: 'corporate blues (#003D7A, #0066CC), silver/gray accents (#7C8B9C), white, minimal use of color',
```

**Replace with:**
```javascript
visualStyle: 'modern, tech-forward, innovative, startup-inspired, clean',
colorPalette: 'electric blue (#0066FF), bright teal (#00CED1), white, minimal accents',
```

---

### Make GuardScan More Dramatic

**Find this section (around line 123):**
```javascript
additionalGuidelines: 'Images should feel technically sophisticated and cutting-edge...'
```

**Add to the end (before the closing quote):**
```javascript
Use more dramatic lighting. Add red alert accents. Make it feel like an active cyber attack is being blocked in real-time.
```

---

### Add More Diversity to Yaicos Students

**Find this section (around line 97):**
```javascript
humanRepresentation: 'diverse international students from Asian, African, European, Latin American, and Middle Eastern backgrounds, aged 18-30, shown from behind or at angles (no direct faces), engaged in learning activities, collaborative work, campus life',
```

**Make it more specific:**
```javascript
humanRepresentation: 'highly diverse students: 30% Asian, 25% African/Black, 20% European/White, 15% Latin American, 10% Middle Eastern, equal gender representation, ages 18-30, casual modern clothing, shown from behind or side angles (no direct faces), engaged in studying, group projects, campus activities',
```

---

### Remove People from Yaicos (Make it Abstract)

**Find this line (around line 96):**
```javascript
includeHumans: true,
```

**Change to:**
```javascript
includeHumans: false,
```

**Then also change:**
```javascript
humanRepresentation: null,
```

---

## Common Tweaks

### 1. Change Brand Colors

**Always include hex codes!**

**Good:**
```javascript
colorPalette: 'navy blue (#003366), gold (#FFD700), white'
```

**Bad:**
```javascript
colorPalette: 'blue and gold'  // Too vague!
```

**Color picker tool:** https://htmlcolorcodes.com/

---

### 2. Adjust Student Diversity

**Be specific about ratios:**
```javascript
humanRepresentation: 'students: 40% from Asia, 30% from Africa, 20% from Latin America, 10% from Europe/other, ages 18-28...'
```

---

### 3. Change Visual Style

**Use descriptive keywords:**

**Friendly:**
```javascript
visualStyle: 'warm, welcoming, approachable, casual, friendly'
```

**Corporate:**
```javascript
visualStyle: 'professional, clean, sophisticated, formal, trustworthy'
```

**Tech/Modern:**
```javascript
visualStyle: 'innovative, cutting-edge, modern, tech-forward, sleek'
```

**Playful:**
```javascript
visualStyle: 'fun, energetic, vibrant, youthful, playful'
```

---

### 4. Reference Other Brands

**Add to `additionalGuidelines`:**

**For Yaicos:**
```javascript
additionalGuidelines: 'Similar to Duolingo or Coursera style. Modern, friendly, educational. Use their color vibrancy and approachable aesthetic.'
```

**For Amabex:**
```javascript
additionalGuidelines: 'Reference IBM, Microsoft, or Salesforce corporate aesthetics. Professional, trustworthy, enterprise-grade.'
```

**For GuardScan:**
```javascript
additionalGuidelines: 'Similar to CrowdStrike or Palo Alto Networks. High-tech security operations center (SOC) aesthetic. Cutting-edge and sophisticated.'
```

---

### 5. Avoid Specific Things

**Add to `avoidElements`:**

**Examples:**
```javascript
avoidElements: 'text, logos, faces, cluttered backgrounds, stock photo poses, cliché symbols like lightbulbs or arrows'
```

---

## Step-by-Step Edit Process

### Step 1: Access the File

**Via SSH:**
```bash
cd /root/scripts/mautic-n8n-stack/strapi/src/services
nano gemini.js
```

**Or use:**
- VS Code Remote SSH
- FileZilla SFTP
- Any code editor with SSH

---

### Step 2: Find Your Brand

Search for one of these:
- `'yaicos-article'` (line ~91)
- `'amabex-article'` (line ~103)
- `'guardscan-article'` (line ~115)

---

### Step 3: Edit the Settings

**Each brand has these fields:**

```javascript
'yaicos-article': {
  brandName: 'Yaicos',                    // ← Brand name
  targetAudience: '...',                  // ← Who is this for?
  visualStyle: '...',                     // ← How should it look?
  colorPalette: '...',                    // ← What colors? (with hex!)
  includeHumans: true,                    // ← Show people? true/false
  humanRepresentation: '...',             // ← What kind of people?
  tone: '...',                            // ← What mood/feeling?
  additionalGuidelines: '...',            // ← Extra instructions
  avoidElements: '...'                    // ← Never include these
}
```

**Just change the text in quotes or true/false values!**

---

### Step 4: Save and Exit

**In nano:**
- Press `Ctrl+O` (save)
- Press `Enter` (confirm)
- Press `Ctrl+X` (exit)

**In vim:**
- Press `Esc`
- Type `:wq`
- Press `Enter`

---

### Step 5: Restart Strapi

```bash
cd /root/scripts/mautic-n8n-stack
docker compose restart strapi
```

**Wait 30 seconds** for Strapi to reload.

---

### Step 6: Test

1. Go to Strapi admin: https://cms.yaicos.com/admin
2. Open an article in the collection you edited
3. Click "Generate Featured Image"
4. Check if it uses your new settings!

---

## Testing Tips

### Test With Same Title

Generate an image BEFORE editing, then again AFTER editing with the **same article title**. This lets you see exactly what changed.

**Before edit:**
- Title: "How to Study Abroad"
- Generate image → Save screenshot

**After edit:**
- Same title: "How to Study Abroad"
- Generate image again → Compare!

---

### Iterate Quickly

1. Edit settings
2. Restart Strapi (30 sec)
3. Generate image
4. Not right? Edit again!
5. Repeat until perfect

Each iteration takes ~1-2 minutes.

---

## What Each Field Does

### brandName
```javascript
brandName: 'Yaicos'
```
How AI refers to your brand in prompts. Usually keep as-is.

---

### targetAudience
```javascript
targetAudience: 'International students aged 18-30'
```
Who the content is for. Makes AI generate relevant imagery.

**Examples:**
- "College students interested in study abroad"
- "Enterprise procurement managers at Fortune 500 companies"
- "Cybersecurity professionals and CISOs"

---

### visualStyle
```javascript
visualStyle: 'friendly, modern, vibrant'
```
Keywords describing the look and feel.

**Be specific! Use 4-6 descriptive words.**

---

### colorPalette
```javascript
colorPalette: 'bright blue (#2196F3), warm orange (#FF9800)'
```

**ALWAYS include hex codes in parentheses!**

The AI will use these exact colors.

---

### includeHumans
```javascript
includeHumans: true  // or false
```

- `true` = Show people in images
- `false` = No people, just abstract/objects

**If true, you MUST set humanRepresentation below.**

---

### humanRepresentation
```javascript
humanRepresentation: 'diverse students aged 18-30, shown from behind...'
```

Describes what kind of people to show.

**Important:** Always say "shown from behind or at angles (no direct faces)" for privacy.

---

### tone
```javascript
tone: 'friendly and aspirational'
```

The emotional feel of images.

**Examples:**
- "friendly and welcoming"
- "professional and trustworthy"
- "cutting-edge and dramatic"
- "playful and energetic"

---

### additionalGuidelines
```javascript
additionalGuidelines: 'Extra instructions here...'
```

Use for:
- Style references ("Similar to Apple's design")
- Specific requirements ("Must show data visualization")
- Emphasis ("Focus on diversity and inclusion")

**This is your "anything else" field!**

---

### avoidElements
```javascript
avoidElements: 'text, logos, cluttered backgrounds'
```

Things AI should NEVER include.

**Common avoidances:**
- text, logos (always)
- faces (if people shown from behind)
- stock photo poses
- cliché symbols (lightbulbs, arrows, handshakes)

---

## Troubleshooting

### Images Still Look the Same

**Problem:** Edited settings but images unchanged

**Solutions:**
1. Did you restart Strapi?
   ```bash
   docker compose restart strapi
   ```
2. Wait full 30 seconds for startup
3. Hard refresh browser: `Ctrl+Shift+R` (Windows) or `Cmd+Shift+R` (Mac)
4. Try generating with a new article title

---

### Strapi Won't Start

**Problem:** Edited file and now Strapi crashes

**Solutions:**
1. Check for syntax errors:
   - Missing commas between fields
   - Unclosed quotes
   - Missing brackets
2. Revert your changes
3. Try editing just ONE field at a time

**Quick revert:**
```bash
cd /root/scripts/mautic-n8n-stack
git checkout strapi/src/services/gemini.js
```

---

### Colors Not Working

**Problem:** AI not using my colors

**Solutions:**
1. Did you include hex codes? `(#2196F3)`
2. Be more specific in `additionalGuidelines`:
   ```javascript
   additionalGuidelines: 'MUST use ONLY the colors specified in color palette. No other colors allowed.'
   ```

---

### Wrong People Showing

**Problem:** People don't match description

**Solutions:**
1. Be MORE specific in `humanRepresentation`
2. Add exact percentages: "40% Asian, 30% African..."
3. Specify age range: "ages 18-25, NOT older"
4. Add to `additionalGuidelines`:
   ```javascript
   'Focus heavily on diversity. Equal representation is critical.'
   ```

---

## Examples: Before & After

### Example 1: Yaicos - More Vibrant

**Before:**
```javascript
colorPalette: 'bright blues (#2196F3), warm oranges (#FF9800), energetic yellows (#FFC107), white backgrounds',
visualStyle: 'friendly, welcoming, modern, educational, vibrant, aspirational',
```

**After:**
```javascript
colorPalette: 'electric blue (#00D4FF), hot pink (#FF1493), sunshine yellow (#FFD700), pure white (#FFFFFF)',
visualStyle: 'energetic, fun, Instagram-worthy, youthful, vibrant, playful, modern',
```

**Result:** Much more colorful and youthful images!

---

### Example 2: Amabex - Less Corporate, More Modern

**Before:**
```javascript
colorPalette: 'corporate blues (#003D7A, #0066CC), silver/gray accents (#7C8B9C), white, minimal use of color',
visualStyle: 'corporate, professional, trustworthy, sophisticated, clean, systematic',
tone: 'corporate and professional',
```

**After:**
```javascript
colorPalette: 'bright blue (#0066FF), teal (#00CED1), white (#FFFFFF), minimal gray',
visualStyle: 'modern, tech-forward, innovative, clean, startup-inspired',
tone: 'innovative and approachable',
```

**Result:** More like a tech startup than traditional corporate!

---

## Need Help?

### Full Documentation
See: `BRAND_SETTINGS_HARDCODED_GUIDE.md`

### File Location
```
/root/scripts/mautic-n8n-stack/strapi/src/services/gemini.js
Lines 85-154
```

### Test Command
```bash
# After editing, restart:
cd /root/scripts/mautic-n8n-stack
docker compose restart strapi

# Check startup:
docker compose logs strapi | tail -20
```

---

**Remember:** Small tweaks can make big differences! Start with one change at a time. ✨
