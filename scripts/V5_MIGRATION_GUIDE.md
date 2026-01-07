# 🚀 V5 Production Migration Guide

**Date:** January 6, 2026
**Version:** V4 → V5
**Estimated Time:** 30-45 minutes
**Downtime:** 5-10 minutes

---

## 📋 What This Migration Does

### ✅ What Will Change
- **Strapi**: `development` → `production` mode
- **Traefik**: Health check FIXED
- **Monitoring**: Prometheus + Grafana added
- **Backups**: Automated daily backups
- **Updates**: Individual service update capability
- **Logs**: Log rotation configured
- **Performance**: Production optimizations applied

### 🔒 What Will NOT Change (Preserved 100%)
- **Mautic configuration** (exact same settings)
- **MySQL database** (all Mautic data intact)
- **PostgreSQL database** (all Strapi data intact)
- **RabbitMQ** (message queue unchanged)
- **n8n workflows** (all preserved)
- **Strapi content** (all articles, authors, media)
- **SSL certificates** (Let's Encrypt certs preserved)
- **Docker volumes** (all data volumes intact)

---

## 🎯 Migration Steps

### Step 1: Pre-Migration Checklist (5 minutes)

```bash
# 1. Check current status
cd /root/scripts/mautic-n8n-stack
docker-compose ps

# All services should show "Up" and "healthy"

# 2. Test Mautic is working
curl -I https://m.yaicos.com
# Should return "HTTP/2 200"

# 3. Test Strapi is working
curl -I https://cms.yaicos.com
# Should return "HTTP/2 200" or "HTTP/2 302"

# 4. Check disk space (need 10GB+ free)
df -h /
```

**✅ All checks passed?** → Continue
**❌ Any issues?** → Fix before migrating

---

### Step 2: Run Migration (15-20 minutes)

```bash
# Make scripts executable
chmod +x /root/scripts/migrate_v4_to_v5.sh
chmod +x /root/scripts/update_n8n.sh
chmod +x /root/scripts/setup_automated_backups.sh

# Run migration
cd /root/scripts
./migrate_v4_to_v5.sh
```

**The script will:**
1. ✅ Verify all prerequisites
2. 💾 Create full backup (MySQL + PostgreSQL + configs + Strapi)
3. 📦 Create V5 directory structure
4. 🔧 Generate production docker-compose.yml
5. 📊 Setup monitoring (Prometheus + Grafana)
6. 🚀 Deploy V5 stack
7. ✔️ Verify all services are healthy

**Expected output:**
```
╔═══════════════════════════════════════════════════════════╗
║         V5 MIGRATION COMPLETED SUCCESSFULLY!              ║
╚═══════════════════════════════════════════════════════════╝

🌐 URLs:
   Mautic:     https://m.yaicos.com
   n8n:        https://n8n.yaicos.com
   Strapi:     https://cms.yaicos.com/admin
   Monitoring: https://monitor.yaicos.com

✅ What Changed:
   • Strapi now in PRODUCTION mode
   • Traefik health check FIXED
   • Monitoring added

🔒 What Stayed the Same:
   • Mautic configuration (100% preserved)
   • All data and volumes (intact)
```

---

### Step 3: Verification (5 minutes)

```bash
# Check all services are running
cd /root/scripts/mautic-n8n-stack-v5
docker-compose ps

# Should show all services "Up":
# - traefik (healthy)
# - mautic-mysql (healthy)
# - strapi-postgres (healthy)
# - mautic-rabbitmq (healthy)
# - strapi (Up)
# - mautic-web (Up)
# - mautic-cron (Up)
# - n8n (Up)
# - prometheus (Up)
# - grafana (Up)
```

**Test each service:**

```bash
# 1. Test Mautic
curl -I https://m.yaicos.com
# Expected: HTTP/2 200

# 2. Test n8n
curl -I https://n8n.yaicos.com
# Expected: HTTP/2 200 or 301

# 3. Test Strapi
curl -I https://cms.yaicos.com
# Expected: HTTP/2 200 or 302

# 4. Verify Strapi is in PRODUCTION mode
docker exec strapi env | grep NODE_ENV
# Expected: NODE_ENV=production

# 5. Check Traefik health
docker inspect traefik | grep -A 5 Health
# Expected: "Status": "healthy"

# 6. Test monitoring
curl -I https://monitor.yaicos.com
# Expected: HTTP/2 200
```

---

### Step 4: Update n8n to v2.0 (5 minutes)

```bash
cd /root/scripts
./update_n8n.sh 2.0

# This will:
# 1. Backup current n8n data
# 2. Stop n8n container
# 3. Update to version 2.0
# 4. Start n8n
# 5. Verify health
# 6. Rollback automatically if it fails
```

**Expected output:**
```
╔═══════════════════════════════════════════════════════════╗
║              n8n Update Utility - V5                      ║
╚═══════════════════════════════════════════════════════════╝

[INFO] Current version: 1.x.x
[INFO] Creating backup...
[SUCCESS] Backup created
[INFO] Pulling new image...
[INFO] Starting n8n with new version...
[SUCCESS] ✓ n8n is running and healthy!
[SUCCESS] ✓ New version: 2.0.x

🎉 Update completed successfully!

Access n8n at: https://n8n.yaicos.com
```

**Verify n8n:**
```bash
# Check version
docker exec n8n n8n --version

# Test access
curl -I https://n8n.yaicos.com

# Login and verify workflows still work
```

---

### Step 5: Setup Automated Backups (5 minutes)

```bash
cd /root/scripts
./setup_automated_backups.sh

# Follow prompts:
# - Enable S3 backups? (recommended: Yes)
# - Enter AWS credentials
# - Enter S3 bucket name
# - Run test backup? (recommended: Yes)
```

**Expected output:**
```
╔═══════════════════════════════════════════════════════════╗
║           Automated Backup Setup Complete!               ║
╚═══════════════════════════════════════════════════════════╝

📋 Configuration:
   Schedule: Daily at 2:00 AM UTC
   Local retention: 7 days
   S3 bucket: your-bucket-name

📂 Backups include:
   • MySQL database (Mautic data)
   • PostgreSQL database (Strapi + vectors)
   • Strapi project files
   • n8n workflows
   • Mautic configuration
```

---

### Step 6: Test Strapi Content Creation (5 minutes)

```bash
# Access Strapi admin
# https://cms.yaicos.com/admin

# Login with your existing credentials

# Test AI endpoints:
curl -X POST https://cms.yaicos.com/api/ai/status
# Expected: {"gemini":true,"openai":true,"semanticSearch":true}

# Generate SEO metadata:
curl -X POST https://cms.yaicos.com/api/ai/generate-seo \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Article",
    "content": "This is a test article about cybersecurity best practices..."
  }'

# Expected: {"metaTitle":"...","metaDescription":"..."}
```

**Test content creation workflow:**
1. Go to Content Manager → guardscan-articles
2. Create new article
3. Add title: "Cybersecurity Best Practices 2026"
4. Add content (or use AI to generate)
5. Use AI features:
   - Generate SEO metadata
   - Generate excerpt
   - Generate feature image
6. Save and publish

---

## 🎉 Migration Complete!

### What You Can Do Now:

#### 1. **Use Strapi for AI Content Creation**
```bash
# Full article generation
curl -X POST https://cms.yaicos.com/api/ai/generate-article \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "Zero Trust Security Architecture",
    "keywords": ["zero trust", "security", "network"],
    "tone": "professional",
    "length": "medium"
  }'
```

#### 2. **Monitor Your Stack**
- Access Grafana: https://monitor.yaicos.com
- Username: `admin`
- Password: (shown after migration, check .env file: `GRAFANA_ADMIN_PASSWORD`)
- Add dashboards for:
  - Docker containers
  - System resources
  - API response times
  - Database connections

#### 3. **Update Individual Services**
```bash
# Update only n8n
./update_n8n.sh latest

# Update only Strapi dependencies
cd /root/scripts/mautic-n8n-stack-v5
docker-compose exec strapi npm update

# Update only monitoring
docker-compose pull prometheus grafana
docker-compose up -d prometheus grafana
```

#### 4. **Manage Backups**
```bash
# List local backups
ls -lh /root/scripts/mautic-n8n-stack-v5/backups/

# List S3 backups
aws s3 ls s3://your-bucket/

# Manual backup
/root/scripts/mautic-n8n-stack-v5/scripts/daily_backup.sh

# Restore from backup (if needed)
# Extract backup archive
# Stop services
# Restore databases and volumes
# Start services
```

---

## 🆘 Troubleshooting

### Issue: Strapi won't start after migration

**Solution:**
```bash
cd /root/scripts/mautic-n8n-stack-v5
docker-compose logs strapi

# If dependencies issue:
docker-compose exec strapi npm install --legacy-peer-deps --production

# If build issue:
docker-compose exec strapi npm run build

# Restart
docker-compose restart strapi
```

### Issue: Mautic not working after migration

**Solution:**
```bash
# Check Mautic logs
docker-compose logs mautic-web

# Verify database connection
docker exec mautic-web php bin/console doctrine:database:validate

# If issue persists, ROLLBACK:
cd /root/scripts/mautic-n8n-stack
docker-compose down
docker-compose up -d

# Contact support with logs
```

### Issue: n8n update failed

**Solution:**
```bash
# The script auto-rolls back on failure
# Check backup location (shown in output)

# Manual rollback if needed:
cd /root/scripts/mautic-n8n-stack-v5
docker-compose stop n8n

# Edit docker-compose.yml to use previous version
# image: n8nio/n8n:1.68.0  (your previous version)

docker-compose up -d n8n
```

### Issue: Can't access Grafana

**Solution:**
```bash
# Get password
cd /root/scripts/mautic-n8n-stack-v5
grep GRAFANA_ADMIN_PASSWORD .env

# Reset password if needed
docker exec -it grafana grafana-cli admin reset-admin-password newpassword

# Check logs
docker-compose logs grafana
```

---

## 📊 V5 Directory Structure

```
/root/scripts/
├── archive/                          # Old scripts (V2, V3, V4)
│   ├── v2_mautic_n8n_deploy_final.sh
│   ├── v3_mautic_n8n_strapi_deploy.sh
│   └── v4_supercharged_deploy.sh
├── mautic-n8n-stack/                 # V4 (keep for 7 days)
│   ├── docker-compose.yml
│   ├── .env
│   └── strapi/
├── mautic-n8n-stack-v5/              # V5 PRODUCTION
│   ├── docker-compose.yml            # Production config
│   ├── .env                          # Environment variables
│   ├── strapi/                       # Strapi project (production mode)
│   ├── monitoring/                   # Prometheus + Grafana configs
│   │   ├── prometheus.yml
│   │   ├── dashboards/
│   │   └── datasources/
│   ├── scripts/                      # Utility scripts
│   │   └── daily_backup.sh          # Automated backup
│   ├── backups/                      # Local backups
│   └── logs/                         # Application logs
├── migrate_v4_to_v5.sh               # Migration script
├── update_n8n.sh                     # n8n update utility
├── setup_automated_backups.sh        # Backup setup
├── MAUTIC_CONFIG_REFERENCE.md        # Mautic config documentation
└── V5_MIGRATION_GUIDE.md             # This guide
```

---

## 📚 Key Files Reference

### `.env` - Environment Variables
```bash
# View all variables
cat /root/scripts/mautic-n8n-stack-v5/.env

# Important variables:
NODE_ENV=production              # Strapi mode
MAUTIC_URL=m.yaicos.com         # Mautic domain
N8N_URL=n8n.yaicos.com          # n8n domain
STRAPI_URL=cms.yaicos.com       # Strapi domain
OPENAI_API_KEY=sk-...           # AI features
GEMINI_API_KEY=...              # AI features
GRAFANA_ADMIN_PASSWORD=...      # Monitoring login
```

### `docker-compose.yml` - Service Configuration
```bash
# View services
docker-compose config --services

# Check specific service config
docker-compose config | grep -A 20 "mautic_web:"
```

---

## 🔐 Security Notes

1. **Passwords are in .env** - Keep this file secure (chmod 600)
2. **Backups contain sensitive data** - Encrypt before uploading to S3
3. **Grafana is public** - Change password immediately after setup
4. **API keys in environment** - Consider using secrets manager (future enhancement)

---

## 📈 Performance Optimization

After migration, consider:

1. **Enable Redis caching for Strapi** (future)
2. **Setup CDN for media files** (Cloudflare/CloudFront)
3. **Database query optimization** (analyze slow queries)
4. **Optimize Mautic cron frequency** (if needed)

---

## 🆘 Support

If you encounter issues:

1. Check logs: `docker-compose logs [service-name]`
2. Review this guide's troubleshooting section
3. Check Mautic config reference: `/root/scripts/MAUTIC_CONFIG_REFERENCE.md`
4. Backup is always available for rollback

---

**Ready to migrate? Start with Step 1!** 🚀

*Last Updated: January 6, 2026*
