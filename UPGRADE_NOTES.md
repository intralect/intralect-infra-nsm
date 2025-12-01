# n8n MCP Server Update & Enhanced Backup - Upgrade Notes

## 🚀 What's New

### 1. n8n MCP (Model Context Protocol) Server Support

The n8n instance is now configured for MCP Server compatibility, preparing it for n8n v2 AI-powered features.

**Changes Made:**
- ✅ Added MCP environment variables to n8n service
- ✅ Exposed port 3100 for MCP server communication
- ✅ Enabled AI features with OpenAI integration
- ✅ Updated firewall rules to allow MCP port

**Configuration Added:**
```yaml
# n8n MCP Server Configuration
N8N_MCP_ENABLED=true
N8N_MCP_SERVER_PORT=3100
N8N_AI_ENABLED=true
N8N_AI_OPENAI_API_KEY=${OPENAI_API_KEY}
```

**Firewall:**
- Port 3100/tcp now open for MCP server connections

---

### 2. Enhanced Backup System with AWS S3 Integration

Professional-grade backup solution with S3 support and smart credential management.

**Features:**
- ✅ **Comprehensive Backups:** MySQL databases, Docker volumes, configurations
- ✅ **AWS S3 Upload:** Optional cloud backup with storage class selection
- ✅ **Secure Credentials:** First-time setup stores credentials in `.env.backup` (chmod 600)
- ✅ **Smart Retention:** Configurable local and S3 backup retention policies
- ✅ **Storage Classes:** Choose from Standard, Standard-IA, Glacier IR, Deep Archive
- ✅ **Detailed Info:** Each backup includes comprehensive metadata
- ✅ **Auto Cleanup:** Automatically removes old backups per retention policy

**New Files:**
- `backup-to-s3.sh` - Standalone enhanced backup script
- `.env.backup` - Secure credential storage (auto-created on first run)

**Menu Integration:**
- Option 6 "Create Backup" now uses the enhanced script
- Interactive prompts for S3 upload and storage class selection
- One-time credential setup (reused for all future backups)

---

## 🔧 How to Use

### Deploying the Updates

1. **Pull the latest changes:**
   ```bash
   cd /path/to/mautic-n8n-infra
   git pull origin claude/n8n-mcp-server-update-0157P5g2RZk6d6eix9hJKpo8
   ```

2. **Run the deployment script:**
   ```bash
   ./deploy-mautic-n8n.sh
   ```

3. **If stack already exists, select option to update:**
   - Choose option 7: "Update Images"
   - This will pull the latest n8n image and restart with MCP support

### Using the Enhanced Backup

#### From Management Menu:
```bash
./deploy-mautic-n8n.sh
# Select option 6: Create Backup
```

#### Standalone Usage:
```bash
./backup-to-s3.sh
```

#### First-Time Backup Setup:
The script will prompt you for:
- **AWS S3 Bucket Name:** Your target bucket
- **AWS Credentials:** (optional if using IAM role/AWS CLI)
- **Retention Policies:**
  - Local backups to keep (default: 5)
  - S3 backups to keep (default: 10)

These settings are saved securely and reused automatically.

#### Backup Process:
1. Creates comprehensive backup of:
   - All MySQL databases
   - n8n workflow data
   - Mautic configuration and media
   - Traefik SSL certificates
   - Docker Compose and environment files

2. Compresses into timestamped archive

3. Optionally uploads to S3 with your chosen storage class

4. Cleans up old backups per retention policy

---

## 📊 S3 Storage Classes Explained

| Storage Class | Retrieval Time | Use Case | Cost |
|--------------|----------------|----------|------|
| **STANDARD** | Instant | Frequent access | Highest |
| **STANDARD_IA** | Instant | Monthly access (Recommended) | Medium |
| **GLACIER_IR** | 1-5 minutes | Quarterly access | Lower |
| **DEEP_ARCHIVE** | 12+ hours | Yearly/Compliance | Lowest |

💡 **Recommendation:** Use STANDARD_IA for most backup scenarios.

---

## 🔐 Security Notes

### Credential Storage
- Backup credentials stored in `mautic-n8n-stack/.env.backup`
- File permissions set to `600` (owner read/write only)
- Not committed to git (add to .gitignore if not already)

### Best Practices
1. Use IAM roles when possible (no hardcoded credentials needed)
2. Restrict S3 bucket access with proper IAM policies
3. Enable S3 bucket versioning for additional protection
4. Regularly test backup restoration process

---

## 🧪 Testing the Updates

### Verify n8n MCP Configuration
```bash
# Check n8n container environment
docker exec n8n env | grep MCP

# Should show:
# N8N_MCP_ENABLED=true
# N8N_MCP_SERVER_PORT=3100
```

### Verify Firewall Rules
```bash
sudo ufw status numbered | grep 3100
# Should show port 3100/tcp allowed
```

### Test Backup System
```bash
# Run a test backup
./backup-to-s3.sh

# Choose 'N' for S3 upload on first test
# Verify backup created in mautic-n8n-stack/backups/
```

---

## 🔄 Rollback Instructions

If you need to revert these changes:

```bash
# Revert to previous commit
git reset --hard 9d2e7b9

# Or revert specific changes
git revert HEAD

# Rebuild stack
cd mautic-n8n-stack
docker-compose down
docker-compose up -d
```

---

## 📝 Migration Path

### For Existing Deployments

1. **Backup current setup** (using old method)
2. **Update firewall manually** if needed:
   ```bash
   sudo ufw allow 3100/tcp comment 'n8n MCP Server'
   ```
3. **Update stack:**
   ```bash
   ./deploy-mautic-n8n.sh
   # Choose option 7: Update Images
   ```
4. **Test MCP connectivity** (if using MCP clients)
5. **Configure backup credentials:**
   ```bash
   ./backup-to-s3.sh
   # Follow first-time setup prompts
   ```

### For Fresh Installations

Everything is configured automatically during deployment!

---

## 🤝 Support

- **Issues:** Check `/home/user/mautic-n8n-infra/mautic-n8n-stack/logs/`
- **Backup logs:** Verbose output during backup process
- **n8n logs:** `docker logs n8n -f`

---

## 📌 Version Info

- **Update Date:** 2025-12-01
- **n8n Image:** `n8nio/n8n:latest` (MCP-ready)
- **Branch:** `claude/n8n-mcp-server-update-0157P5g2RZk6d6eix9hJKpo8`
- **Deployment Script:** `v1.1` (Enhanced Backup)

---

## 🎯 What's Next

After deploying these updates:

1. ✅ n8n MCP server ready for AI agent connections
2. ✅ Professional backup system with cloud storage
3. ✅ Secure credential management
4. ✅ Automated retention policies

**Recommended:**
- Set up a cron job for automated backups
- Configure S3 bucket lifecycle policies
- Test disaster recovery procedures
- Monitor backup sizes and adjust retention as needed

---

*Created: 2025-12-01*
*Author: Claude Code Assistant*
