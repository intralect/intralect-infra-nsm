# Content Scheduling Guide - Schedule Your Blog Posts

**Status:** ✅ Installed and ready to use!

**Plugin:** @webbio/strapi-plugin-scheduler v1.1.0

---

## What You Can Do Now

✅ **Schedule publish dates** - Set when an article should go live
✅ **Schedule unpublish dates** - Automatically take down content after a date
✅ **Time-based content** - Perfect for campaigns, announcements, seasonal content
✅ **Draft → Published automatically** - No manual intervention needed

---

## How to Use the Scheduler

### 1. Open Your Article

Go to **Content Manager** → Select your article type:
- Yaicos Article
- GuardScan Article
- Amabex Article

Open an existing article or create a new one.

---

### 2. Find the Scheduling Fields

When editing an article, you'll now see **new scheduling fields** (usually in the right sidebar or at the bottom):

#### **Publish At** 📅
- Set the date and time when this article should be published
- Format: Date + Time picker
- Example: `January 15, 2026 at 9:00 AM`

#### **Unpublish At** 📅 (Optional)
- Set the date and time when this article should be unpublished
- Useful for time-limited content (promotions, events, etc.)
- Leave empty if you want the article to stay published forever

---

### 3. Save Your Article

**Important:** Save the article as a **DRAFT** (not published yet)

The scheduler will automatically:
1. Check every minute (or configured interval)
2. Find articles with "Publish At" date/time that has passed
3. Automatically publish them
4. Do the same for "Unpublish At" dates

---

## Example Workflows

### Workflow 1: Schedule Single Article

**Scenario:** You want to publish "10 Tips for Dublin Students" next Monday at 9am

**Steps:**
1. Create/edit the article
2. Fill in all content (title, body, featured image, etc.)
3. Set **Publish At:** Monday, January 13, 2026 - 09:00 AM
4. Leave **Published** toggle OFF (keep as draft)
5. Click **Save**

**What happens:**
- Article stays as draft until Monday 9am
- Scheduler checks every minute
- At 9:00 AM Monday → Article automatically published ✅
- Visible on your website immediately

---

### Workflow 2: Time-Limited Content

**Scenario:** Black Friday promotion article (publish Nov 29, unpublish Dec 2)

**Steps:**
1. Create promotion article
2. Set **Publish At:** November 29, 2026 - 00:00 AM
3. Set **Unpublish At:** December 2, 2026 - 23:59 PM
4. Save as draft

**What happens:**
- Nov 29 at midnight → Article goes live
- Dec 2 at 11:59 PM → Article automatically unpublished
- Perfect for time-sensitive content!

---

### Workflow 3: Batch Content for the Week

**Scenario:** You wrote 5 articles and want to publish one per day

**Steps:**
1. Article 1: Set **Publish At:** Monday 9am
2. Article 2: Set **Publish At:** Tuesday 9am
3. Article 3: Set **Publish At:** Wednesday 9am
4. Article 4: Set **Publish At:** Thursday 9am
5. Article 5: Set **Publish At:** Friday 9am
6. Save all as drafts

**What happens:**
- Each article publishes automatically at its scheduled time
- You write once, schedule all, forget about it
- Consistent publishing schedule for SEO

---

## How the Scheduler Works Behind the Scenes

### The Cron Job

The plugin runs a **background task** (cron job) that:

```
Every 1 minute (default):
  1. Check all draft articles with "publishAt" date
  2. If publishAt <= now → Publish the article
  3. Check all published articles with "unpublishAt" date
  4. If unpublishAt <= now → Unpublish the article
  5. Log results
```

### What Gets Checked

- **Content types enabled:** All collection types (yaicos-article, guardscan-article, amabex-article)
- **Draft → Published:** Articles with publishAt date in the past
- **Published → Draft:** Articles with unpublishAt date in the past
- **Timezone:** Server timezone (UTC by default)

---

## Important Notes

### ⚠️ Server Time vs Your Time

The scheduler uses **server time (UTC)**.

**Example:**
- You're in Dublin (UTC+0 winter, UTC+1 summer)
- Server is UTC+0
- Schedule for 9:00 AM → That's 9:00 AM UTC

**Tip:** When scheduling, think in UTC or convert your local time:
- Dublin Winter: Same as UTC (9 AM = 9 AM UTC)
- Dublin Summer: Add 1 hour (9 AM local = 8 AM UTC)

### ✅ Best Practices

1. **Keep as Draft:** Don't manually publish if you want to schedule
2. **Check Your Time:** Make sure you're scheduling in the correct timezone
3. **Test First:** Schedule something 2 minutes in the future to test
4. **Set Clear Times:** Use round numbers (9:00 AM, not 9:17 AM)
5. **Plan Ahead:** Schedule at least a few minutes in the future to avoid issues

### 🚫 What NOT to Do

❌ Don't schedule a time in the past (it will publish immediately)
❌ Don't manually publish AND set a schedule (pick one method)
❌ Don't schedule two articles at the exact same second (space them out)
❌ Don't forget to save as DRAFT (published articles won't be re-scheduled)

---

## Troubleshooting

### "My article didn't publish at the scheduled time"

**Check:**
1. Is the article still a DRAFT? (must be draft for scheduler to work)
2. Is the "Publish At" time in the past? (not future)
3. Is Strapi running? (scheduler only works when Strapi is up)
4. Check the server time: `docker compose exec strapi date`
5. Check Strapi logs: `docker compose logs strapi --tail 50 | grep scheduler`

### "My article published immediately"

**Reason:** The scheduled time is in the past

**Fix:**
- The scheduler publishes anything with a past date immediately
- Always schedule for the future
- If you made a mistake, unpublish it and reschedule

### "I don't see the scheduling fields"

**Possible issues:**
1. Plugin not enabled → Check `config/plugins.js`
2. Cache issue → Hard refresh browser (Ctrl+Shift+R)
3. Content type not supported → Only works with collection types

**Fix:**
- Restart Strapi: `docker compose restart strapi`
- Clear browser cache
- Rebuild admin panel: `docker compose exec strapi npm run build`

---

## Configuration

### Default Settings

The scheduler is configured with sensible defaults:

```javascript
// config/plugins.js
'scheduler': {
  enabled: true,
  // Default cron interval: every 1 minute
  // Default timezone: UTC
}
```

### Custom Configuration (Optional)

If you want to change the check interval, you can add:

```javascript
'scheduler': {
  enabled: true,
  config: {
    // Check every 5 minutes instead of 1
    interval: '*/5 * * * *', // Cron format
  }
}
```

**Cron format examples:**
- `* * * * *` - Every minute (default)
- `*/5 * * * *` - Every 5 minutes
- `0 * * * *` - Every hour (on the hour)
- `0 9 * * *` - Every day at 9:00 AM

---

## Frontend Integration

### Fetching Scheduled Content

When you fetch articles via API, scheduled (draft) articles won't appear:

```javascript
// Only published articles returned
const articles = await fetch('/api/yaicos-articles?populate=*');

// Draft articles (even with schedules) are hidden
// This is good - users don't see unpublished content!
```

### Checking Publication Status

```javascript
const article = await fetch('/api/yaicos-articles/1');

// Check if article is published
if (article.publishedAt) {
  console.log('Article is live!');
  console.log('Published at:', article.publishedAt);
}
```

---

## Advanced: Combining with n8n

Want to do more when an article is published? Add n8n automation!

### Example: Auto-Tweet When Article Publishes

**Setup:**
1. Article schedules for 9:00 AM
2. Scheduler publishes it at 9:00 AM
3. Strapi webhook fires → n8n workflow triggered
4. n8n posts to Twitter/X with article link
5. n8n sends email to subscribers via Mautic

**Best of both worlds:**
- Scheduling: Handled by Strapi (simple)
- Distribution: Handled by n8n (powerful)

---

## Testing the Scheduler

### Quick Test (2 minutes)

1. **Create test article:**
   - Title: "Scheduler Test"
   - Content: "Testing 123"
   - Keep as DRAFT

2. **Set schedule:**
   - Publish At: (current time + 2 minutes)
   - Example: If it's 10:15 AM, set to 10:17 AM

3. **Save and wait:**
   - Save the article (still draft)
   - Wait 2-3 minutes
   - Refresh the article list
   - It should now be PUBLISHED ✅

4. **Verify:**
   - Check the article - "Published" badge should show
   - Check your API: `/api/yaicos-articles`
   - Article should appear in the results

---

## Monitoring

### Check Scheduler Status

```bash
# View recent Strapi logs
docker compose logs strapi --tail 100 | grep -i "publish\|schedule"

# Check server time (important for scheduling)
docker compose exec strapi date

# Verify plugin is loaded
docker compose exec strapi npm list @webbio/strapi-plugin-scheduler
```

### Logs to Watch For

When the scheduler runs, you might see logs like:
```
[scheduler] Checking for scheduled publications...
[scheduler] Published article: "10 Tips for Dublin Students"
[scheduler] Unpublished article: "Black Friday Sale 2025"
```

---

## FAQ

### Q: Can I schedule multiple articles at once?
**A:** Yes! Each article can have its own schedule. Schedule as many as you want.

### Q: What happens if Strapi is down during the scheduled time?
**A:** The article will publish when Strapi comes back online (assuming the time has passed).

### Q: Can I change the scheduled time after saving?
**A:** Yes! Edit the article, change the "Publish At" time, and save. As long as it's still a draft, the new schedule applies.

### Q: Can I cancel a scheduled publish?
**A:** Yes! Edit the article and remove the "Publish At" date, or delete the article entirely.

### Q: Does this work with all content types?
**A:** Yes! Works with yaicos-article, guardscan-article, amabex-article, and any custom content types.

### Q: Can I schedule drafts that are already published?
**A:** No. Once an article is published, it stays published. The scheduler only works on DRAFT articles.

### Q: What about timezones?
**A:** The plugin uses UTC by default. Keep this in mind when scheduling. You can configure a different timezone in the plugin settings if needed.

---

## Summary

✅ **Scheduler plugin installed and working**
✅ **Schedule publish dates for any article**
✅ **Schedule unpublish dates (optional)**
✅ **Automatic background task checks every minute**
✅ **Perfect for consistent publishing schedules**
✅ **Works great with your existing AI content workflow**

**Next steps:**
1. Go to https://cms.yaicos.com/admin
2. Open any article (or create new)
3. Look for **"Publish At"** field
4. Schedule your first post!
5. Test it with a 2-minute future time

**Your content creation workflow is now complete:**
1. ✅ Generate AI content (Gemini 2.5 Flash)
2. ✅ Generate beautiful images (Gemini/DALL-E 3)
3. ✅ Automatic image optimization (Sharp)
4. ✅ **Schedule publication (Scheduler)** ← NEW!

---

**Installation Date:** 2026-01-08
**Status:** ✅ Production Ready
**Plugin:** @webbio/strapi-plugin-scheduler v1.1.0
