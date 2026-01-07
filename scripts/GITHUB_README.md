# V5 Production Stack - Mautic + n8n + Strapi AI-Enhanced

Production-ready deployment scripts for a complete marketing automation and content management stack with AI capabilities.

## 🚀 Quick Start

```bash
# Clone the repository
git clone <your-repo-url>
cd <repo-name>

# Run the unified manager
./v5_manager.sh
```

## 📦 What's Included

### Services
- **Mautic 5** - Marketing automation platform
- **n8n** - Workflow automation
- **Strapi 4** - Headless CMS with AI content generation
- **Traefik** - Reverse proxy with SSL
- **Prometheus + Grafana** - Monitoring and metrics
- **PostgreSQL + pgvector** - Database with vector search
- **MySQL** - Mautic database
- **RabbitMQ** - Message queue

### AI Features
- 🤖 **Full article generation** (Gemini 2.0)
- 🎨 **Image generation** (DALL-E 3)
- 🔍 **Semantic search** (OpenAI embeddings)
- ✍️ **Content enhancement** (improve, expand, rephrase)
- 📊 **Quality analysis** (readability, SEO scores)
- 🌍 **Multi-language support**
- 💰 **Cost tracking** for AI API usage

## 📋 Prerequisites

- Ubuntu 20.04+ or Debian 11+
- 8GB+ RAM (recommended)
- 50GB+ disk space
- Docker & Docker Compose
- Domain with DNS configured
- OpenAI API key (for AI features)
- Google Gemini API key (for AI features)

## 🎯 Usage

### Unified Manager Interface

```bash
./v5_manager.sh
```

Interactive menu with options for:
- Migration from V4 to V5
- Service updates (n8n, Strapi, all services)
- Backup creation and download
- Resource monitoring and alerts
- Service management
- Log viewing
- Documentation access

### Individual Scripts (Optional)

```bash
./migrate_v4_to_v5.sh        # Migrate from V4
./update_n8n.sh 2.0          # Update n8n to specific version
./backup_now.sh              # Create on-demand backup
./download_backup.sh         # Download backup to desktop
./setup_resource_alerts.sh   # Configure email alerts
```

## 📚 Documentation

- **QUICK_START.md** - 3-step quick guide
- **V5_MIGRATION_GUIDE.md** - Detailed migration instructions
- **MAUTIC_CONFIG_REFERENCE.md** - Production Mautic configuration
- **PRODUCTION_DEPLOYMENT_PLAN.md** - Complete architecture overview
- **README.md** - Complete reference

## ✨ Features

### Production Optimizations
- ✅ Strapi in production mode
- ✅ Automated health checks
- ✅ Resource monitoring
- ✅ Log rotation
- ✅ Swap configuration
- ✅ SSL auto-renewal

### Backup & Recovery
- ✅ On-demand backups
- ✅ S3 cloud storage integration
- ✅ Easy download to desktop
- ✅ One-click restore capability

### Monitoring & Alerts
- ✅ Grafana dashboards
- ✅ Prometheus metrics
- ✅ Email alerts (CPU, Memory, Disk)
- ✅ Container health monitoring

### Updates & Maintenance
- ✅ Individual service updates
- ✅ Automatic backup before updates
- ✅ Auto rollback on failure
- ✅ Zero-downtime updates

## 🔐 Security Features

- Firewall configuration (UFW)
- fail2ban for brute force protection
- SSL/TLS with Let's Encrypt
- Secret management
- Rate limiting
- CORS configuration
- Production mode security

## 📊 System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 2 cores | 4 cores |
| RAM | 4GB | 8GB+ |
| Disk | 30GB | 50GB+ |
| Swap | 2GB | 4GB |

## 🌐 Default URLs

After deployment:
- Mautic: `https://m.yourdomain.com`
- n8n: `https://n8n.yourdomain.com`
- Strapi: `https://cms.yourdomain.com/admin`
- Grafana: `https://monitor.yourdomain.com`
- Traefik: `http://SERVER-IP:8080`

## 🤖 AI API Configuration

Required environment variables:
```bash
OPENAI_API_KEY=sk-...        # For DALL-E and embeddings
GEMINI_API_KEY=...           # For content generation
ENABLE_SEMANTIC_SEARCH=true  # Enable vector search
```

## 💰 Cost Estimate

Monthly operational costs:
- AI APIs (Gemini + OpenAI): ~$150-170/month (1,500 articles)
- VPS (8GB RAM): ~$40-60/month
- S3 Storage (100GB): ~$3/month
- CloudFlare Pro: ~$20/month
- **Total: ~$213-253/month**

## 🚦 Migration Path

### From V4 to V5
```bash
./v5_manager.sh
# Select: "1) Migrate to V5 Production Stack"
```

**Migration time:** 30-45 minutes
**Downtime:** 5-10 minutes
**Data loss:** Zero (full backup created automatically)

### What Changes
- ✅ Strapi: development → production mode
- ✅ Traefik: health check fixed
- ✅ Monitoring: Added Prometheus + Grafana
- ✅ Backups: On-demand capability
- ✅ Swap: 4GB configured

### What Stays the Same
- ✅ Mautic configuration (100% preserved)
- ✅ All data (MySQL, PostgreSQL)
- ✅ SSL certificates
- ✅ Docker volumes
- ✅ n8n workflows

## 📈 Performance

Expected metrics after V5 deployment:
- API response time: <200ms (p50), <500ms (p95)
- System uptime: >99.9%
- Error rate: <0.1%
- Content generation: <2 minutes per article
- Cost per article: ~$0.15

## 🆘 Support

### Quick Commands
```bash
# Check status
./v5_manager.sh
# Select: "11) View Service Status"

# View logs
./v5_manager.sh
# Select: "12) View Logs"

# Check resources
./check_resources_now.sh

# Create backup
./backup_now.sh
```

### Troubleshooting
See `V5_MIGRATION_GUIDE.md` for detailed troubleshooting steps.

## 📝 License

MIT License - See LICENSE file for details

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## ⚠️ Important Notes

### Mautic Configuration
The Mautic configuration is **production-tested and working**. The migration scripts preserve this configuration exactly. Do not modify Mautic settings during migration.

See `MAUTIC_CONFIG_REFERENCE.md` for details.

### Secrets Management
- Never commit `.env` files
- Use environment variables for API keys
- Rotate credentials regularly
- Use S3 encryption for backups

## 📅 Version History

- **V5.0** - Production-ready stack with unified manager
- **V4.0** - AI-enhanced Strapi with content generation
- **V3.0** - Added Strapi CMS
- **V2.0** - Mautic + n8n base stack

## 🔗 Links

- [Mautic Documentation](https://docs.mautic.org/)
- [n8n Documentation](https://docs.n8n.io/)
- [Strapi Documentation](https://docs.strapi.io/)
- [OpenAI API](https://platform.openai.com/)
- [Google Gemini API](https://ai.google.dev/)

---

**Built with ❤️ for production marketing automation and AI-powered content creation**

*Last Updated: January 2026*
