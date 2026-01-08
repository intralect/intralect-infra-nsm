# V5 Unified Server Management Script - Implementation Plan

**Created:** 2026-01-08
**Purpose:** Consolidate all V5 scripts into ONE powerful unified script
**Target:** server_manager_v5.sh

---

## 1. EXECUTIVE SUMMARY

### 1.1 Current State
The V5 stack currently has **9 separate scripts** managing different aspects of the infrastructure:
- v5_manager.sh (menu interface)
- backup_now.sh (manual backups)
- download_backup.sh (backup download)
- update_n8n.sh (n8n updates)
- setup_automated_backups.sh (automated backups + S3)
- setup_resource_alerts.sh (monitoring + alerts)
- migrate_v4_to_v5.sh (migration)
- cleanup-server.sh (server cleanup)
- update-gemini-key.sh (API key management)

### 1.2 Target State
**ONE unified script** (`server_manager_v5.sh`) that:
- Provides a single menu-driven interface
- Consolidates all functionality
- Uses modular functions for maintainability
- Includes all safety features (backups, rollbacks, health checks)
- Supports both interactive and command-line modes

### 1.3 Benefits
- **Simplified Management:** One script to rule them all
- **Easier Deployment:** Single file to copy/distribute
- **Better Maintainability:** All code in one place
- **Consistent UX:** Unified interface and error handling
- **Reduced Complexity:** No multiple scripts to track

---

## 2. ARCHITECTURE

### 2.1 Script Structure

```bash
#!/bin/bash
# server_manager_v5.sh - Unified V5 Production Stack Manager

# ============================================================================
# SECTION 1: CONFIGURATION & GLOBALS
# ============================================================================
# - Color definitions
# - Path configuration
# - Global variables
# - Version information

# ============================================================================
# SECTION 2: UTILITY FUNCTIONS
# ============================================================================
# - print_status(), print_success(), print_error(), print_warning()
# - show_header(), show_main_menu()
# - detect_environment()
# - check_prerequisites()

# ============================================================================
# SECTION 3: SERVICE MANAGEMENT
# ============================================================================
# - view_status() - Show all service status
# - view_logs() - View service logs
# - restart_services() - Restart individual or all services
# - check_health() - Health check for all services

# ============================================================================
# SECTION 4: UPDATE MANAGEMENT
# ============================================================================
# - update_n8n() - Update n8n (with backup/rollback)
# - update_strapi() - Update Strapi dependencies
# - update_mautic() - Update Mautic
# - update_all_services() - Update all Docker images
# - update_docker_images() - Pull latest images

# ============================================================================
# SECTION 5: BACKUP MANAGEMENT
# ============================================================================
# - create_backup() - On-demand backup
# - setup_automated_backups() - Configure daily backups + S3
# - download_backup() - Download backup to desktop
# - list_backups() - List all backups (local + S3)
# - restore_backup() - Restore from backup
# - cleanup_old_backups() - Remove old backups

# ============================================================================
# SECTION 6: MONITORING & ALERTS
# ============================================================================
# - check_resources() - Check CPU/RAM/Disk
# - setup_alerts() - Configure email alerts
# - view_grafana_info() - Show Grafana dashboard info
# - send_test_alert() - Send test email

# ============================================================================
# SECTION 7: SECURITY
# ============================================================================
# - update_api_keys() - Update Gemini/OpenAI keys
# - run_security_audit() - Security checks
# - configure_firewall() - UFW configuration
# - ssl_certificate_check() - Check SSL status

# ============================================================================
# SECTION 8: MIGRATION & DEPLOYMENT
# ============================================================================
# - migrate_v4_to_v5() - Full migration from V4
# - fresh_install() - Fresh V5 installation
# - cleanup_server() - Server cleanup

# ============================================================================
# SECTION 9: DOCUMENTATION & INFO
# ============================================================================
# - view_documentation() - Show docs
# - show_service_info() - URLs and credentials
# - show_architecture() - System architecture diagram

# ============================================================================
# SECTION 10: MAIN MENU & CLI
# ============================================================================
# - main() - Main menu loop
# - parse_cli_args() - Command-line interface
# - show_help() - CLI help
```

### 2.2 Modular Design Philosophy

Each section is **self-contained** with:
- Clear function names
- Consistent error handling
- Rollback capabilities where applicable
- Logging to syslog
- User confirmation for destructive operations

---

## 3. FEATURE CONSOLIDATION

### 3.1 Service Management Module

**Consolidates:**
- v5_manager.sh (service status viewing)
- Docker container management
- Log viewing

**Functions:**
```bash
view_status()           # docker-compose ps + stats
view_logs()             # Follow logs for service
restart_services()      # Restart single/all services
check_health()          # Health check all services
start_stack()           # Start all services
stop_stack()            # Stop all services gracefully
```

**Features:**
- Real-time container stats
- Log filtering by service
- Health status indicators
- Resource usage per container

---

### 3.2 Update Management Module

**Consolidates:**
- update_n8n.sh
- Individual service updates
- Bulk updates

**Functions:**
```bash
update_n8n()            # Safe n8n update with rollback
update_strapi()         # Strapi dependency update
update_mautic()         # Mautic update
update_all_services()   # Update all services
pull_latest_images()    # Pull without restart
```

**Safety Features:**
- ✅ Automatic pre-update backup
- ✅ Health check after update
- ✅ Automatic rollback on failure
- ✅ Image cleanup
- ✅ Zero downtime for other services

**Update Process:**
```
1. Create backup
2. Stop service
3. Pull new image
4. Start service
5. Health check (60s timeout)
6. If fail → Rollback
7. If success → Cleanup old images
```

---

### 3.3 Backup Management Module

**Consolidates:**
- backup_now.sh
- download_backup.sh
- setup_automated_backups.sh

**Functions:**
```bash
create_backup()                 # Manual on-demand backup
setup_automated_backups()       # Daily backups + S3 setup
download_backup()               # Download to desktop
list_backups()                  # List local + S3 backups
restore_backup()                # Restore from backup
cleanup_old_backups()           # Remove old backups
configure_s3()                  # S3 configuration
test_s3_connection()            # Verify S3 works
```

**Backup Contents:**
- MySQL database (Mautic)
- PostgreSQL database (Strapi + pgvector)
- Configuration files (.env, docker-compose.yml)
- Strapi project (excludes node_modules)
- Docker volumes (Mautic config, media, n8n workflows)
- Metadata (timestamp, server info, service versions)

**Backup Types:**
1. **Manual:** On-demand via menu
2. **Automated:** Daily at 2 AM UTC via cron
3. **Pre-update:** Before any service update
4. **Pre-migration:** Before V4→V5 migration

**S3 Integration:**
- Upload to S3 after backup
- Storage class: STANDARD_IA (Infrequent Access)
- Retention: Configurable
- Local retention: 7 days
- AWS CLI configuration

**Download Methods:**
1. SCP (direct secure copy)
2. SFTP (GUI clients)
3. HTTP (temporary server on port 8888)

---

### 3.4 Monitoring & Alerts Module

**Consolidates:**
- setup_resource_alerts.sh
- check_resources_now.sh
- Grafana integration

**Functions:**
```bash
check_resources()       # Instant CPU/RAM/Disk check
setup_alerts()          # Configure email alerts
view_grafana_info()     # Grafana dashboard access
send_test_alert()       # Test email notification
configure_thresholds()  # Set alert thresholds
view_alert_history()    # Show past alerts
```

**Monitoring Targets:**
- CPU usage (threshold: 80%)
- Memory usage (threshold: 85%)
- Disk usage (threshold: 80%)
- Docker container health
- Service availability

**Alert System:**
- Email notifications via SMTP
- Configurable thresholds
- Check frequency: Every 15 minutes (cron)
- Alert includes:
  - Current resource usage
  - Top processes
  - Docker container status
  - Remediation suggestions
  - Server access info

**Grafana Integration:**
- Dashboard URL
- Login credentials
- Prometheus metrics
- Service-specific dashboards

---

### 3.5 Security Module

**New consolidation of security features**

**Functions:**
```bash
update_api_keys()           # Update Gemini/OpenAI/etc
run_security_audit()        # Security checks
configure_firewall()        # UFW setup
ssl_certificate_check()     # SSL status
rotate_database_passwords() # Password rotation
view_security_logs()        # Auth logs, failed logins
```

**Security Checks:**
- SSL certificate expiration
- Exposed ports audit
- Docker security scanning
- Database password strength
- API key validation
- File permission checks
- Unauthorized access attempts

**API Key Management:**
- Gemini API key rotation
- OpenAI API key rotation
- Update .env securely
- Restart affected services
- Verify new keys work

---

### 3.6 Migration & Deployment Module

**Consolidates:**
- migrate_v4_to_v5.sh
- cleanup-server.sh
- Fresh installation

**Functions:**
```bash
migrate_v4_to_v5()      # V4 to V5 migration
fresh_install()         # New V5 installation
cleanup_server()        # Clean slate
rollback_to_v4()        # Emergency rollback
```

**Migration Process:**
1. Pre-flight checks (disk space, services)
2. Full V4 backup
3. .env migration with V5 enhancements
4. Service updates
5. Strapi production mode fix
6. Monitoring setup
7. Health verification
8. V4 archive (kept for 7 days)

**Fresh Install Process:**
1. Server cleanup
2. Install Docker + dependencies
3. Clone repository
4. Environment configuration
5. SSL certificate generation
6. Service deployment
7. Initial backup
8. Monitoring setup

---

## 4. MENU STRUCTURE

### 4.1 Main Menu (Pre-Migration)

```
╔════════════════════════════════════════════════════════════════════╗
║           V5 Unified Server Manager                                ║
║           Version 5.0 - Build 2026-01-08                           ║
╚════════════════════════════════════════════════════════════════════╝

Status: V4 Stack Running (Ready to migrate to V5)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  V5 NOT YET DEPLOYED

  1) 🚀 Migrate to V5 Production Stack  ← Start here!
  2) 🆕 Fresh V5 Installation
  3) 📖 Read Documentation
  4) 🔍 View System Info

  q) Exit

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Select option:
```

### 4.2 Main Menu (Post-Migration - V5 Active)

```
╔════════════════════════════════════════════════════════════════════╗
║           V5 Unified Server Manager                                ║
║           Version 5.0 - Build 2026-01-08                           ║
╚════════════════════════════════════════════════════════════════════╝

Status: V5 Production Stack Active ✅
Running: 8 containers | Healthy: 7 | Unhealthy: 1
Last Backup: 2 hours ago | Disk: 45% | Memory: 62%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 MAIN MENU
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ┌─ SERVICE MANAGEMENT
  │ 1)  📊 View service status
  │ 2)  📜 View logs
  │ 3)  🔄 Restart services
  │ 4)  ⚡ Start/Stop stack
  │ 5)  🏥 Health check all services

  ┌─ UPDATES
  │ 6)  🔄 Update n8n
  │ 7)  🔄 Update Strapi
  │ 8)  🔄 Update Mautic
  │ 9)  🔄 Update all services
  │ 10) 📥 Pull latest images

  ┌─ BACKUP & RECOVERY
  │ 11) 💾 Create backup now
  │ 12) ⚙️  Setup automated backups (daily + S3)
  │ 13) 📥 Download backup to desktop
  │ 14) 📋 List all backups
  │ 15) 🔙 Restore from backup
  │ 16) 🗑️  Cleanup old backups

  ┌─ MONITORING & ALERTS
  │ 17) 📊 Check server resources (CPU/RAM/Disk)
  │ 18) ⚙️  Setup email alerts
  │ 19) 📧 Send test alert
  │ 20) 📈 View Grafana dashboard info
  │ 21) 📜 View alert history

  ┌─ SECURITY
  │ 22) 🔑 Update API keys (Gemini/OpenAI)
  │ 23) 🛡️  Run security audit
  │ 24) 🔥 Configure firewall
  │ 25) 🔒 Check SSL certificates
  │ 26) 🔐 Rotate database passwords

  ┌─ INFORMATION
  │ 27) ℹ️  Show service URLs & credentials
  │ 28) 📖 View documentation
  │ 29) 🏗️  Show system architecture
  │ 30) 🔍 System diagnostics

  q) Exit

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Select option:
```

---

## 5. COMMAND-LINE INTERFACE (CLI MODE)

### 5.1 CLI Usage

**Instead of interactive menu, support direct commands:**

```bash
# Service management
./server_manager_v5.sh status
./server_manager_v5.sh logs [service]
./server_manager_v5.sh restart [service|all]
./server_manager_v5.sh start
./server_manager_v5.sh stop
./server_manager_v5.sh health

# Updates
./server_manager_v5.sh update n8n [version]
./server_manager_v5.sh update strapi
./server_manager_v5.sh update mautic
./server_manager_v5.sh update all

# Backups
./server_manager_v5.sh backup
./server_manager_v5.sh backup --setup-automated
./server_manager_v5.sh backup --download
./server_manager_v5.sh backup --list
./server_manager_v5.sh backup --restore [backup-file]
./server_manager_v5.sh backup --cleanup

# Monitoring
./server_manager_v5.sh monitor
./server_manager_v5.sh monitor --setup-alerts
./server_manager_v5.sh monitor --test-alert
./server_manager_v5.sh grafana

# Security
./server_manager_v5.sh security audit
./server_manager_v5.sh security update-keys
./server_manager_v5.sh security firewall
./server_manager_v5.sh security ssl

# Migration
./server_manager_v5.sh migrate
./server_manager_v5.sh install

# Information
./server_manager_v5.sh info
./server_manager_v5.sh docs
./server_manager_v5.sh help
```

### 5.2 CLI Arguments

```bash
# Global flags
--quiet, -q         # Suppress non-error output
--verbose, -v       # Verbose output
--no-color          # Disable colored output
--yes, -y           # Auto-confirm prompts
--help, -h          # Show help

# Examples
./server_manager_v5.sh update n8n latest --yes
./server_manager_v5.sh backup --quiet
./server_manager_v5.sh status --verbose
```

---

## 6. CONFIGURATION MANAGEMENT

### 6.1 Configuration File

**Location:** `/root/scripts/.server_manager_config`

```bash
# Server Manager Configuration
# Auto-generated on first run

# Project paths
PROJECT_DIR=/root/scripts/mautic-n8n-stack-v5
BACKUP_DIR=/root/scripts/mautic-n8n-stack-v5/backups
LOG_DIR=/root/scripts/mautic-n8n-stack-v5/logs

# S3 Configuration
S3_ENABLED=true
S3_BUCKET=your-backup-bucket
S3_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret

# Alert Configuration
ALERTS_ENABLED=true
ALERT_EMAIL=admin@example.com
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=alerts@example.com
SMTP_PASSWORD=your-password

# Alert Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=80

# Backup Configuration
BACKUP_RETENTION_DAYS=7
S3_STORAGE_CLASS=STANDARD_IA
AUTO_BACKUP_TIME="0 2 * * *"  # 2 AM daily

# Update Configuration
AUTO_BACKUP_BEFORE_UPDATE=true
AUTO_ROLLBACK_ON_FAILURE=true
HEALTH_CHECK_TIMEOUT=60

# Notification Settings
NOTIFY_ON_BACKUP=false
NOTIFY_ON_UPDATE=true
NOTIFY_ON_ERROR=true
```

### 6.2 First-Run Setup

**On first run, script will:**
1. Detect if config exists
2. If not, run interactive setup wizard
3. Create config file with defaults
4. Save to `.server_manager_config`
5. Secure file permissions (600)

---

## 7. LOGGING & DEBUGGING

### 7.1 Log Structure

**Log files:**
```
/root/scripts/mautic-n8n-stack-v5/logs/
├── server_manager.log          # Main log
├── backup.log                  # Backup operations
├── update.log                  # Update operations
├── security.log                # Security events
└── error.log                   # Errors only
```

**Log format:**
```
[2026-01-08 14:23:45] [INFO] Starting n8n update to version 2.0
[2026-01-08 14:23:50] [SUCCESS] Pre-update backup created: backup-20260108_142350.tar.gz
[2026-01-08 14:24:15] [INFO] Pulling n8n image: n8nio/n8n:2.0
[2026-01-08 14:24:45] [INFO] Starting n8n container
[2026-01-08 14:25:00] [SUCCESS] Health check passed
[2026-01-08 14:25:05] [SUCCESS] n8n updated successfully to version 2.0
```

### 7.2 Logging Functions

```bash
log_info()      # General information
log_success()   # Successful operations
log_warning()   # Warnings
log_error()     # Errors
log_debug()     # Debug info (verbose mode only)
```

### 7.3 Syslog Integration

**All critical events logged to syslog:**
```bash
logger -t server_manager_v5 "[INFO] n8n update started"
```

---

## 8. ERROR HANDLING & ROLLBACK

### 8.1 Error Handling Strategy

**Every critical function must:**
1. Check prerequisites
2. Create backup if modifying data
3. Validate inputs
4. Log all operations
5. Handle errors gracefully
6. Provide rollback capability
7. Notify user of errors
8. Suggest remediation

### 8.2 Rollback Capabilities

**Update rollback:**
```
1. Detect health check failure
2. Stop failed service
3. Restore previous Docker image
4. Restart service
5. Verify health
6. Log rollback event
7. Notify user
```

**Backup restoration:**
```
1. List available backups
2. User selects backup
3. Confirm restoration
4. Stop all services
5. Restore databases
6. Restore volumes
7. Restore configuration
8. Restart services
9. Health check
10. Verify data integrity
```

---

## 9. SAFETY FEATURES

### 9.1 Confirmation Prompts

**Require confirmation for:**
- Service updates
- Backup restoration
- Server cleanup
- Database password rotation
- Destructive operations

**Example:**
```
⚠️  WARNING: This will update n8n to version 2.0

This will:
  • Stop n8n container
  • Pull new n8n image
  • Start n8n with new version
  • Verify health
  • Rollback if health check fails

A backup will be created automatically.

Continue? (y/N):
```

### 9.2 Dry-Run Mode

**Support --dry-run flag:**
```bash
./server_manager_v5.sh update n8n 2.0 --dry-run
```

**Output:**
```
[DRY RUN] Would create backup: backup-20260108_142350.tar.gz
[DRY RUN] Would stop n8n container
[DRY RUN] Would pull image: n8nio/n8n:2.0
[DRY RUN] Would start n8n container
[DRY RUN] Would perform health check
[DRY RUN] Would cleanup old images

No changes were made.
```

---

## 10. INTEGRATION POINTS

### 10.1 External Tools

**Required:**
- Docker & Docker Compose
- AWS CLI (for S3 backups)
- Python 3 (for email alerts)
- curl, jq (for API calls)

**Optional:**
- yq (for YAML editing)
- pgcli (for database management)

### 10.2 Docker Integration

**Commands used:**
```bash
docker-compose ps               # Service status
docker-compose logs             # View logs
docker-compose restart          # Restart services
docker-compose pull             # Pull images
docker-compose up -d            # Start services
docker exec                     # Execute commands
docker inspect                  # Get container info
docker stats                    # Resource usage
```

### 10.3 Cron Integration

**Automated tasks:**
```bash
# Daily backup at 2 AM
0 2 * * * /root/scripts/server_manager_v5.sh backup --quiet

# Resource check every 15 minutes
*/15 * * * * /root/scripts/server_manager_v5.sh monitor --quiet

# Weekly security audit
0 3 * * 0 /root/scripts/server_manager_v5.sh security audit --quiet

# Monthly SSL check
0 4 1 * * /root/scripts/server_manager_v5.sh security ssl --quiet
```

---

## 11. TESTING PLAN

### 11.1 Unit Tests

**Test each function:**
- Service status detection
- Backup creation
- S3 upload
- Email sending
- Update process
- Rollback process
- Health checks

### 11.2 Integration Tests

**Test workflows:**
1. Fresh installation
2. V4 to V5 migration
3. n8n update with rollback
4. Backup and restore
5. Alert triggering
6. CLI commands

### 11.3 Edge Cases

**Test scenarios:**
- Disk full during backup
- Network failure during S3 upload
- Service fails to start after update
- Invalid configuration
- Missing dependencies
- Concurrent script execution

---

## 12. DEPLOYMENT PLAN

### 12.1 Development

**Phase 1: Core Structure (Week 1)**
- [ ] Create basic script structure
- [ ] Implement utility functions
- [ ] Implement main menu
- [ ] Implement CLI parser

**Phase 2: Service Management (Week 1)**
- [ ] Service status viewing
- [ ] Log viewing
- [ ] Service restart
- [ ] Health checks

**Phase 3: Backup Module (Week 2)**
- [ ] Manual backup
- [ ] S3 integration
- [ ] Download helper
- [ ] List backups
- [ ] Restore functionality

**Phase 4: Update Module (Week 2)**
- [ ] n8n update
- [ ] Strapi update
- [ ] Mautic update
- [ ] All services update
- [ ] Rollback capability

**Phase 5: Monitoring Module (Week 3)**
- [ ] Resource checking
- [ ] Email alerts setup
- [ ] Grafana integration
- [ ] Alert history

**Phase 6: Security Module (Week 3)**
- [ ] API key management
- [ ] Security audit
- [ ] Firewall configuration
- [ ] SSL checks

**Phase 7: Migration Module (Week 4)**
- [ ] V4 to V5 migration
- [ ] Fresh installation
- [ ] Server cleanup

**Phase 8: Testing & Polish (Week 4)**
- [ ] Unit tests
- [ ] Integration tests
- [ ] Documentation
- [ ] Error handling review

### 12.2 Production Rollout

**Step 1: Beta Testing**
- Deploy to test server
- Run all functions
- Collect feedback
- Fix bugs

**Step 2: Production Deployment**
- Push to GitHub
- Tag release v5.0.0
- Update documentation
- Announce to team

**Step 3: Migration**
- Backup existing scripts
- Deploy new script
- Run migration
- Verify functionality

---

## 13. SUCCESS METRICS

### 13.1 Key Performance Indicators

**Functionality:**
- ✅ All 9 existing scripts consolidated
- ✅ Zero functionality lost
- ✅ New features added (CLI mode, dry-run, etc.)
- ✅ All safety features preserved

**Reliability:**
- ✅ 100% uptime during updates
- ✅ Zero data loss incidents
- ✅ Successful rollback capability
- ✅ All backups verified restorable

**Usability:**
- ✅ Single command to run
- ✅ Intuitive menu structure
- ✅ Clear error messages
- ✅ Comprehensive documentation

**Performance:**
- ✅ Backup completion < 5 minutes
- ✅ Update completion < 10 minutes
- ✅ Health check timeout 60 seconds
- ✅ CLI response time < 1 second

---

## 14. MIGRATION FROM EXISTING SCRIPTS

### 14.1 Migration Path

**Current users can:**
1. Keep existing scripts (deprecated)
2. Run new unified script alongside
3. Gradually transition
4. Archive old scripts after validation

### 14.2 Compatibility

**Ensure compatibility with:**
- Existing .env files
- Existing docker-compose.yml
- Existing backups
- Existing cron jobs
- Existing S3 configuration

### 14.3 Data Migration

**Migrate existing:**
- Backup files (compatible format)
- Configuration files
- Log files
- Cron jobs (auto-update)

---

## 15. DOCUMENTATION

### 15.1 Required Documentation

**Create:**
1. **README_SERVER_MANAGER_V5.md**
   - Quick start guide
   - Feature overview
   - Installation instructions

2. **COMMAND_REFERENCE.md**
   - All CLI commands
   - Examples
   - Advanced usage

3. **TROUBLESHOOTING.md**
   - Common issues
   - Error messages
   - Solutions

4. **MIGRATION_GUIDE.md**
   - Migrating from old scripts
   - Configuration migration
   - Backup migration

### 15.2 Inline Documentation

**Every function must have:**
```bash
# ============================================================================
# Function: update_n8n
# Description: Update n8n to specific version with automatic backup/rollback
# Arguments:
#   $1 - Target version (e.g., "2.0", "latest")
# Returns:
#   0 - Success
#   1 - Failure
# Safety:
#   - Creates backup before update
#   - Health check after update
#   - Automatic rollback on failure
# ============================================================================
update_n8n() {
    local target_version="${1:-latest}"
    # ... implementation
}
```

---

## 16. FUTURE ENHANCEMENTS

### 16.1 Short Term (v5.1)

- [ ] **Web UI:** Browser-based management interface
- [ ] **API:** RESTful API for remote management
- [ ] **Webhooks:** Slack/Discord notifications
- [ ] **Database Management:** Built-in DB tools
- [ ] **Performance Profiling:** Identify bottlenecks

### 16.2 Long Term (v6.0)

- [ ] **Multi-Server Support:** Manage multiple servers
- [ ] **Auto-Scaling:** Automatic resource scaling
- [ ] **Load Balancing:** Distribute traffic
- [ ] **High Availability:** Failover support
- [ ] **Container Orchestration:** Kubernetes migration

---

## 17. MAINTENANCE

### 17.1 Regular Updates

**Monthly:**
- Security patches
- Dependency updates
- Bug fixes

**Quarterly:**
- Feature additions
- Performance improvements
- Documentation updates

**Yearly:**
- Major version releases
- Architecture review
- Technology stack updates

### 17.2 Version Control

**Semantic Versioning:**
```
v5.0.0 - Initial unified script
v5.1.0 - Web UI added
v5.1.1 - Bug fix release
v5.2.0 - API added
v6.0.0 - Major rewrite
```

---

## 18. FINAL DELIVERABLES

### 18.1 Script File

**Primary:**
- `server_manager_v5.sh` (single unified script)

### 18.2 Documentation

**Files:**
- README_SERVER_MANAGER_V5.md
- COMMAND_REFERENCE.md
- TROUBLESHOOTING.md
- MIGRATION_GUIDE.md
- V5_UNIFIED_SCRIPT_PLAN.md (this document)

### 18.3 Configuration

**Files:**
- .server_manager_config.example
- crontab.example

### 18.4 Repository

**GitHub structure:**
```
/root/scripts/
├── server_manager_v5.sh          ← Main script
├── .server_manager_config         ← Config (gitignored)
├── .server_manager_config.example ← Config template
├── README_SERVER_MANAGER_V5.md
├── COMMAND_REFERENCE.md
├── TROUBLESHOOTING.md
├── MIGRATION_GUIDE.md
├── V5_UNIFIED_SCRIPT_PLAN.md
├── archive/                       ← Old scripts (deprecated)
│   ├── v5_manager.sh
│   ├── backup_now.sh
│   ├── update_n8n.sh
│   └── ... (all old scripts)
└── mautic-n8n-stack-v5/          ← Production stack
    └── ... (existing structure)
```

---

## 19. SIGN-OFF CRITERIA

### 19.1 Acceptance Criteria

**Must achieve ALL:**
- ✅ All 9 existing scripts consolidated
- ✅ Zero regression in functionality
- ✅ All safety features working (backup/rollback)
- ✅ CLI mode fully functional
- ✅ Interactive menu fully functional
- ✅ S3 backups working
- ✅ Email alerts working
- ✅ All services updatable
- ✅ Documentation complete
- ✅ Testing complete

### 19.2 Sign-Off

**Approvals required:**
- [ ] Developer (code review)
- [ ] QA (testing complete)
- [ ] DevOps (infrastructure review)
- [ ] Project Owner (acceptance)

---

## 20. APPENDIX

### 20.1 Services Managed

| Service | Purpose | Port | Health Check |
|---------|---------|------|--------------|
| Traefik | Reverse proxy | 80, 443, 8080 | HTTP /ping |
| Mautic | Marketing automation | - | HTTP / |
| n8n | Workflow automation | - | HTTP /healthz |
| Strapi | CMS + AI | - | HTTP /_health |
| MySQL | Mautic database | 3306 | mysqladmin ping |
| PostgreSQL | Strapi database | 5432 | pg_isready |
| RabbitMQ | Message queue | 5672, 15672 | rabbitmqctl status |
| Prometheus | Metrics | 9090 | HTTP /-/healthy |
| Grafana | Dashboards | - | HTTP /api/health |

### 20.2 Environment Variables

**Critical .env variables:**
```bash
# Domains
MAIN_DOMAIN=yaicos.com
MAUTIC_URL=mautic.yaicos.com
N8N_URL=n8n.yaicos.com
STRAPI_URL=strapi.yaicos.com

# Database passwords
MYSQL_ROOT_PASSWORD=
POSTGRES_PASSWORD=

# API Keys
GEMINI_API_KEY=
OPENAI_API_KEY=

# Email
MAILER_DSN=

# Security
GRAFANA_ADMIN_PASSWORD=
```

### 20.3 Directory Permissions

**Required:**
```bash
/root/scripts/                      # 755
/root/scripts/server_manager_v5.sh  # 755 (executable)
/root/scripts/.server_manager_config # 600 (secure)
/root/scripts/mautic-n8n-stack-v5/  # 755
/root/scripts/mautic-n8n-stack-v5/backups/ # 755
```

---

## END OF PLAN

**Next Steps:**
1. Review plan
2. Approve plan
3. Begin implementation
4. Track progress against milestones
5. Deploy to production
6. Push to GitHub

**Estimated Timeline:** 4 weeks
**Estimated Effort:** 160 hours (1 FTE)
**Risk Level:** Low (consolidation of proven components)

---

**Plan Created By:** Claude (AI Assistant)
**Plan Reviewed By:** [Pending]
**Plan Approved By:** [Pending]
**Implementation Start:** [Pending]
**Target Completion:** [Pending]
