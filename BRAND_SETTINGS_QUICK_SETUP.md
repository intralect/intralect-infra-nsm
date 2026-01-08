# Brand Settings - Quick Setup Guide

**Status:** ✅ System is ready!
**Access:** https://cms.yaicos.com/admin

---

## What You Can Control Now

Each collection (Yaicos, Amabex, GuardScan) can have custom:

- ✅ **Target Audience** - Who the images are for
- ✅ **Visual Style** - Friendly vs Corporate vs Technical
- ✅ **Color Palette** - Exact brand colors (with hex codes)
- ✅ **Human Representation** - Include people or not
- ✅ **Tone** - Friendly, Professional, Corporate, Technical
- ✅ **Custom Guidelines** - Your specific brand requirements

---

## 5-Minute Setup

### Step 1: Go to Brand Settings (1 min)

1. Login: https://cms.yaicos.com/admin
2. Click **Content Manager** (left sidebar)
3. Scroll to **Brand Settings**
4. Click **Create new entry**

---

### Step 2: Create Yaicos Settings (2 min)

**Copy/Paste This:**

```
Collection Name: yaicos-article
Brand Name: Yaicos
Target Audience: International students seeking education opportunities
Visual Style: friendly, modern, educational, vibrant
Color Palette: bright blues (#2196F3), warm oranges (#FF9800), white
Include Humans: ✅ ON
Human Representation: diverse international students aged 18-30, multicultural backgrounds, engaging in learning
Tone: friendly
Additional Guidelines: Show diversity and international representation. Focus on education and opportunity. Similar to the reference image style.
Active: ✅ ON
```

**Click Save**

---

### Step 3: Create Amabex Settings (1 min)

**Copy/Paste This:**

```
Collection Name: amabex-article
Brand Name: Amabex
Target Audience: Corporate procurement professionals
Visual Style: corporate, professional, sophisticated
Color Palette: corporate blues (#003D7A, #0066CC), silver/gray (#7C8B9C)
Include Humans: ❌ OFF
Tone: corporate
Additional Guidelines: Abstract representations of procurement, supply chains, and business systems. Professional corporate aesthetic.
Active: ✅ ON
```

**Click Save**

---

### Step 4: Create GuardScan Settings (1 min)

**Copy/Paste This:**

```
Collection Name: guardscan-article
Brand Name: GuardScan
Target Audience: IT security professionals and cybersecurity teams
Visual Style: technical, secure, high-tech, cutting-edge
Color Palette: deep blues (#001F3F), cyber green (#00FF41), dark backgrounds
Include Humans: ❌ OFF
Tone: technical
Additional Guidelines: Advanced security visualizations with networks, encryption, and threat detection. High-tech cybersecurity aesthetic.
Active: ✅ ON
```

**Click Save**

---

## Test It (2 min)

### Test Yaicos
1. Go to **Yaicos Articles** → Create new
2. Title: "How to Study Abroad Successfully"
3. Add some content (at least 200 words)
4. Category: "tutorials-guides"
5. Click **Generate Featured Image**
6. **Expected:** Diverse students, educational setting, bright colors

### Test Amabex
1. Go to **Amabex Articles** → Create new
2. Title: "Modern Procurement Strategies"
3. Add content
4. Category: "business-solutions"
5. Click **Generate Featured Image**
6. **Expected:** Corporate abstract visualization, blue/gray, no people

### Test GuardScan
1. Go to **GuardScan Articles** → Create new
2. Title: "Network Security Best Practices"
3. Add content
4. Category: "cybersecurity"
5. Click **Generate Featured Image**
6. **Expected:** Technical security visualization, dark with cyber green

---

## Key Differences You'll See

| Feature | Yaicos | Amabex | GuardScan |
|---------|--------|--------|-----------|
| **People** | ✅ Students | ❌ No | ❌ No |
| **Colors** | Bright blues/oranges | Corporate blues/grays | Dark blue/cyber green |
| **Style** | Friendly, welcoming | Professional, clean | Technical, high-tech |
| **Mood** | Aspirational | Trustworthy | Cutting-edge |
| **Audience** | International students | Business executives | Security professionals |

---

## Customization Tips

### Want More Diverse Students?
Edit Yaicos → Human Representation:
```
Include equal representation from Asian, African, European, Latin American,
and Middle Eastern backgrounds. Show various ages 18-35. Mix of genders.
All engaged in educational activities.
```

### Want Different Amabex Colors?
Edit Amabex → Color Palette:
```
Your specific brand colors here with hex codes
Example: deep navy (#001A2C), professional teal (#008B8B)
```

### Want GuardScan to Look More "Matrix-Like"?
Edit GuardScan → Additional Guidelines:
```
Heavy emphasis on "Matrix" aesthetic - cascading code, green phosphor
glow, dark black backgrounds. Digital rain effect. Hacker/security
operations center vibe.
```

---

## Troubleshooting

### "Brand Settings" Not Showing?
- Strapi may need a moment to load new content type
- Refresh the browser
- If still missing, check: `docker compose logs strapi | grep -i error`

### Images Not Using Settings?
1. Verify collection_name is exact: "yaicos-article" (not "yaicos")
2. Check "Active" toggle is ON
3. Try regenerating image

### Want to Change Something?
1. Go back to Brand Settings
2. Click the setting you want to edit
3. Make changes
4. Click Save
5. Generate new image to test

---

## Advanced: Placeholder System

If you write Custom Prompt Template, use:

```
{title} - Article title
{content} - Article content
{category} - Article category
{colors} - Your color palette
{style} - Your visual style
{tone} - Your tone setting
{target_audience} - Your audience
{brand_name} - Your brand name
```

**Example Custom Template:**
```
Create a {tone} blog image for {brand_name}.
Title: "{title}"
Use {colors} colors.
Appeal to {target_audience}.
Style: {style}
```

---

## What Happens When You Generate Images

### Without Brand Settings (Old Way)
```
Generic prompt → Same style for all → Corporate look
```

### With Brand Settings (New Way)
```
Yaicos Article → Load Yaicos settings → Students + Bright colors
Amabex Article → Load Amabex settings → Corporate + Abstract
GuardScan Article → Load GuardScan settings → Tech + Dark
```

---

## Reference Image (Optional)

If you have a reference image that captures your brand style:

1. Upload it somewhere (your website, Imgur, etc.)
2. Copy the URL
3. Paste in "Reference Image URL" field
4. AI will use it as style guidance (won't copy it)

**Example for Yaicos:**
Upload your example image → Get URL → Paste in Brand Settings

---

## Next Steps

1. ✅ Create 3 brand settings (above)
2. ✅ Test each collection
3. ✅ Refine based on results
4. ✅ Generate real articles
5. ✅ Compare image consistency

---

**Full Documentation:** See `BRAND_SETTINGS_GUIDE.md` for complete details

**Status:** Ready to use! 🚀
