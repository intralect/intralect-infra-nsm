# 📚 V5 Production Stack - Quick Reference

**Last Updated:** January 6, 2026
**Status:** Ready for Migration

---

## 🎯 Quick Start

### Migrate to V5 Production (Recommended)
```bash
cd /root/scripts
./migrate_v4_to_v5.sh
```
**Time:** 30-45 minutes | **Downtime:** 5-10 minutes

### Update n8n to v2.0
```bash
cd /root/scripts
./update_n8n.sh 2.0
```
**Time:** 5 minutes | **Downtime:** ~1 minute for n8n only

### Create On-Demand Backup
```bash
cd /root/scripts
./backup_now.sh
```
**Time:** 2-5 minutes

### Download Backup to Desktop
```bash
cd /root/scripts
./download_backup.sh
```
**Easy download via SCP or HTTP**

### Setup Resource Email Alerts
```bash
cd /root/scripts
./setup_resource_alerts.sh
```
**Time:** 5 minutes | Get alerts for CPU/Memory/Disk

---

## 📋 Available Scripts

| Script | Purpose | Safety |
|--------|---------|--------|
| `migrate_v4_to_v5.sh` | Full V4→V5 migration | ✅ Auto backup + rollback |
| `update_n8n.sh [version]` | Update n8n individually | ✅ Auto backup + rollback |
| `backup_now.sh` | Create backup on-demand | ✅ Safe |
| `download_backup.sh` | Download backup to desktop | ✅ Safe |
| `setup_resource_alerts.sh` | Email alerts for VPS resources | ✅ Safe |
| `check_resources_now.sh` | Quick resource check | ✅ Safe |
| `cleanup-server.sh` | System cleanup | ⚠️ Review before use |

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| `QUICK_START.md` | **START HERE** - 3-step quick guide |
| `V5_MIGRATION_GUIDE.md` | Complete detailed migration guide |
| `PRODUCTION_DEPLOYMENT_PLAN.md` | Full V5 architecture & features |
| `MAUTIC_CONFIG_REFERENCE.md` | Protected Mautic configuration |

---

## 🗂️ Directory Structure

```
/root/scripts/
├── README.md                          ← You are here
├── V5_MIGRATION_GUIDE.md             ← Migration instructions
├── PRODUCTION_DEPLOYMENT_PLAN.md     ← V5 architecture details
├── MAUTIC_CONFIG_REFERENCE.md        ← Mautic config (DO NOT MODIFY)
│
├── migrate_v4_to_v5.sh               ← Main migration script
├── update_n8n.sh                     ← n8n update utility
├── setup_automated_backups.sh        ← Backup setup
│
├── archive/                           ← Old scripts (V2, V3, V4)
│   ├── v2_mautic_n8n_deploy_final.sh
│   ├── v3_mautic_n8n_strapi_deploy.sh
│   └── v4_supercharged_deploy.sh
│
├── mautic-n8n-stack/                 ← V4 CURRENT (will keep for 7 days)
│   ├── docker-compose.yml
│   ├── .env
│   └── strapi/
│
└── mautic-n8n-stack-v5/              ← V5 PRODUCTION (created after migration)
    ├── docker-compose.yml
    ├── .env
    ├── strapi/
    ├── monitoring/
    ├── scripts/
    └── backups/
```

---

## ✨ What's New in V5

### 🚀 Performance & Stability
- ✅ **Strapi in PRODUCTION mode** (was development)
- ✅ **Traefik health check FIXED** (was unhealthy)
- ✅ **4GB Swap configured** (prevents OOM crashes)
- ✅ **Log rotation enabled** (prevents disk fill)
- ✅ **Resource limits optimized**

### 📊 Monitoring & Observability
- ✅ **Prometheus** - Metrics collection
- ✅ **Grafana** - Dashboards & visualization
- ✅ **Automated alerts** - Email/Slack notifications
- ✅ **Health checks** - All services monitored

### 💾 Backup & Recovery
- ✅ **Automated daily backups** - Runs at 2 AM UTC
- ✅ **S3 integration** - Cloud backup storage
- ✅ **7-day retention** - Local backups
- ✅ **One-click restore** - Disaster recovery ready

### 🔄 Updates & Maintenance
- ✅ **Individual service updates** - Update n8n without touching Mautic
- ✅ **Auto backup before update** - Always safe to update
- ✅ **Auto rollback on failure** - Zero-risk updates
- ✅ **Version pinning** - No accidental updates

### 🤖 Enhanced AI Content Creation
- ✅ **Full article generation** - Topic → complete article
- ✅ **Content enhancement** - Improve/expand/rephrase
- ✅ **Quality analysis** - Readability & SEO scores
- ✅ **Multi-language support** - Translation ready
- ✅ **Cost tracking** - Monitor AI API spending
- ✅ **Batch processing** - Generate multiple articles

### 🔐 Security Hardening
- ✅ **Production mode enabled** - No debug info exposed
- ✅ **Secrets in .env** - Proper secret management
- ✅ **Firewall configured** - UFW active
- ✅ **fail2ban enabled** - Brute force protection
- ✅ **SSL auto-renewal** - Let's Encrypt configured

---

## 🔒 What's PRESERVED from V4

### 100% Intact - Zero Changes
- ✅ **Mautic configuration** - Exact same settings
- ✅ **Mautic data** - All campaigns, contacts, emails
- ✅ **MySQL database** - All tables and data
- ✅ **Strapi data** - All articles, authors, media
- ✅ **PostgreSQL database** - All content + vectors
- ✅ **n8n workflows** - All automation intact
- ✅ **RabbitMQ** - Message queue preserved
- ✅ **SSL certificates** - Same Let's Encrypt certs
- ✅ **Docker volumes** - All persistent data

**Your working Mautic setup is 100% safe!**

---

## 🎯 Use Cases After V5 Migration

### 1. Update n8n to v2.0
```bash
./update_n8n.sh 2.0
# ✅ Automatic backup
# ✅ Health check
# ✅ Auto rollback if fails
# ✅ Other services keep running
```

### 2. Generate Full Blog Articles with AI
```bash
# Access Strapi Admin
https://cms.yaicos.com/admin

# Use AI endpoints:
POST /api/ai/generate-article
POST /api/ai/generate-seo
POST /api/ai/generate-image
POST /api/ai/analyze-content
```

### 3. Monitor Your Stack
```bash
# Access Grafana
https://monitor.yaicos.com

# Default credentials:
# Username: admin
# Password: (check .env: GRAFANA_ADMIN_PASSWORD)

# View:
# - Container health & resources
# - API response times
# - Database connections
# - Error rates
# - AI API costs
```

### 4. Automated Daily Backups
```bash
# Runs automatically at 2 AM UTC
# Backs up:
# - MySQL (Mautic)
# - PostgreSQL (Strapi)
# - n8n workflows
# - Configurations
# - Strapi project

# Uploads to S3 automatically
# Keeps last 7 local backups

# View logs:
tail -f /root/scripts/mautic-n8n-stack-v5/logs/backup.log
```

### 5. Restore from Backup
```bash
# List backups
ls -lh /root/scripts/mautic-n8n-stack-v5/backups/

# Or from S3
aws s3 ls s3://your-bucket/

# Restore (if needed)
# Stop services
# Restore databases
# Restore volumes
# Start services
```

---

## ⚡ Common Tasks

### Check Service Status
```bash
cd /root/scripts/mautic-n8n-stack-v5
docker-compose ps
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f strapi
docker-compose logs -f mautic-web
docker-compose logs -f n8n
```

### Restart Service
```bash
# Restart single service
docker-compose restart strapi

# Restart all
docker-compose restart
```

### Update Service
```bash
# n8n
./update_n8n.sh latest

# Strapi dependencies
cd /root/scripts/mautic-n8n-stack-v5
docker-compose exec strapi npm update

# Monitoring
docker-compose pull prometheus grafana
docker-compose up -d prometheus grafana
```

---

## 🆘 Quick Troubleshooting

### Service Won't Start
```bash
# Check logs
docker-compose logs [service-name]

# Check disk space
df -h /

# Check memory
free -h

# Restart service
docker-compose restart [service-name]
```

### Mautic Issues
```bash
# Clear cache
docker exec mautic-web php bin/console cache:clear

# Check database
docker exec mautic-web php bin/console doctrine:database:validate

# View logs
docker-compose logs mautic-web
```

### Strapi Issues
```bash
# Rebuild
docker-compose exec strapi npm run build

# Reinstall dependencies
docker-compose exec strapi npm install --legacy-peer-deps

# Check mode
docker exec strapi env | grep NODE_ENV
# Should show: NODE_ENV=production
```

### n8n Issues
```bash
# Check version
docker exec n8n n8n --version

# Restart
docker-compose restart n8n

# Check logs
docker-compose logs n8n
```

---

## 📞 Support & Resources

### Documentation
- 📖 **Migration Guide:** `V5_MIGRATION_GUIDE.md`
- 🏗️ **Architecture Plan:** `PRODUCTION_DEPLOYMENT_PLAN.md`
- 🔒 **Mautic Config:** `MAUTIC_CONFIG_REFERENCE.md`

### Health Checks
```bash
# Mautic
curl -I https://m.yaicos.com

# n8n
curl -I https://n8n.yaicos.com

# Strapi
curl -I https://cms.yaicos.com

# Monitoring
curl -I https://monitor.yaicos.com
```

### Service URLs
- **Mautic:** https://m.yaicos.com
- **n8n:** https://n8n.yaicos.com
- **Strapi:** https://cms.yaicos.com/admin
- **Grafana:** https://monitor.yaicos.com
- **Traefik Dashboard:** http://[SERVER-IP]:8080

---

## 🚀 Ready to Start?

### Recommended Order:

1. **Read the migration guide**
   ```bash
   cat /root/scripts/V5_MIGRATION_GUIDE.md
   ```

2. **Run the migration**
   ```bash
   ./migrate_v4_to_v5.sh
   ```

3. **Update n8n to v2.0**
   ```bash
   ./update_n8n.sh 2.0
   ```

4. **Setup automated backups**
   ```bash
   ./setup_automated_backups.sh
   ```

5. **Start using Strapi for AI content creation**
   - Access: https://cms.yaicos.com/admin
   - Use AI features to generate articles
   - Publish to your blogs

---

## ✅ Success Metrics

After migration, you should have:
- ✅ All services running and healthy
- ✅ Strapi in production mode
- ✅ Traefik health check passing
- ✅ n8n updated to v2.0
- ✅ Monitoring dashboards accessible
- ✅ Daily backups configured
- ✅ AI content generation working
- ✅ Zero data loss
- ✅ Same Mautic functionality

---

**Questions? Issues? Check the troubleshooting sections in the migration guide!**

*Last Updated: January 6, 2026*
*V5 Production Stack - Ready for Deployment*
