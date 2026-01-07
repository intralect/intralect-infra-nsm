# 🚀 Quick Start - V5 Migration

**Ready to run V5? Here's the simple path:**

---

## ⚡ 3-Step Migration (45 minutes total)

### Step 1: Run V5 Migration (30-40 min)
```bash
cd /root/scripts
./migrate_v4_to_v5.sh
```

**What happens:**
- ✅ Creates full backup automatically
- ✅ Preserves your Mautic 100%
- ✅ Fixes Strapi to production mode
- ✅ Adds monitoring (Prometheus + Grafana)
- ✅ Fixes Traefik health check

---

### Step 2: Update n8n to v2.0 (5 min)
```bash
cd /root/scripts
./update_n8n.sh 2.0
```

**What happens:**
- ✅ Auto backup before update
- ✅ Updates to n8n v2.0
- ✅ Verifies it works
- ✅ Rolls back automatically if it fails

---

### Step 3: Setup Resource Alerts (5 min)
```bash
cd /root/scripts
./setup_resource_alerts.sh
```

**What you get:**
- ✅ Email alerts when CPU > 80%
- ✅ Email alerts when Memory > 85%
- ✅ Email alerts when Disk > 80%
- ✅ Checks every 15 minutes

---

## 💾 On-Demand Backups (Whenever You Want)

### Create a backup NOW:
```bash
cd /root/scripts
./backup_now.sh
```

**What it backs up:**
- MySQL (Mautic data)
- PostgreSQL (Strapi + vectors)
- n8n workflows
- All configurations
- Strapi project

### Download backup to your desktop:
```bash
./download_backup.sh
```

**Choose from:**
- SCP download command
- HTTP server (easy browser download)
- SFTP instructions

---

## 🎯 After Migration - What You Can Do

### 1. Access Your Services
- **Mautic:** https://m.yaicos.com (unchanged)
- **n8n v2.0:** https://n8n.yaicos.com
- **Strapi (production):** https://cms.yaicos.com/admin
- **Monitoring:** https://monitor.yaicos.com

### 2. Use AI Content Creation
```bash
# Access Strapi admin panel
https://cms.yaicos.com/admin

# New AI features available:
- Full article generation (topic → complete article)
- Content enhancement (improve/expand/rephrase)
- Quality analysis (readability & SEO scores)
- Image generation (DALL-E 3)
- SEO metadata generation
- Semantic search
```

### 3. Monitor Your VPS
```bash
# Access Grafana
https://monitor.yaicos.com

# Username: admin
# Password: (shown after migration, or check .env)

# See:
- CPU, Memory, Disk usage
- Container health
- Docker stats
```

### 4. Check Resources Anytime
```bash
# Quick manual check
/root/scripts/check_resources_now.sh

# View alert history
tail -f /var/log/resource_alerts.log
```

---

## 📋 Quick Reference Commands

```bash
# Check all services
cd /root/scripts/mautic-n8n-stack-v5
docker-compose ps

# View logs
docker-compose logs -f strapi     # Strapi logs
docker-compose logs -f mautic-web # Mautic logs
docker-compose logs -f n8n        # n8n logs

# Restart a service
docker-compose restart strapi
docker-compose restart n8n

# Create backup
/root/scripts/backup_now.sh

# Download backup
/root/scripts/download_backup.sh

# Check resources
/root/scripts/check_resources_now.sh
```

---

## ✅ What's Preserved (Don't Worry!)

Your working setup is **100% safe**:
- ✅ Mautic configuration (exact same)
- ✅ All Mautic data
- ✅ All Strapi content
- ✅ All n8n workflows
- ✅ SSL certificates
- ✅ Docker volumes

The migration **ONLY changes**:
- Strapi: development → production mode
- Adds: Monitoring stack
- Fixes: Traefik health check

**Mautic is untouched!**

---

## 🆘 Something Wrong?

### Rollback to V4
```bash
cd /root/scripts/mautic-n8n-stack
docker-compose down
docker-compose up -d
```

Your V4 is kept for 7 days as a safety net.

### Get Help
```bash
# Check detailed migration guide
cat /root/scripts/V5_MIGRATION_GUIDE.md

# Check Mautic config reference
cat /root/scripts/MAUTIC_CONFIG_REFERENCE.md

# View all docs
ls -lh /root/scripts/*.md
```

---

## 🎉 Ready to Start?

Just run:
```bash
cd /root/scripts
./migrate_v4_to_v5.sh
```

That's it! The script guides you through everything.

**Total time:** 30-45 minutes
**Your involvement:** Answer a few questions, then wait
**Risk:** Zero (full backup created + V4 preserved)

---

*Questions? Read `/root/scripts/V5_MIGRATION_GUIDE.md` for details*
