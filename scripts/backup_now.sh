#!/bin/bash

# =============================================================================
# On-Demand Backup Script
# Create a complete backup whenever you need it
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Determine project directory
if [[ -d "/root/scripts/mautic-n8n-stack-v5" ]]; then
    PROJECT_DIR="/root/scripts/mautic-n8n-stack-v5"
elif [[ -d "/root/scripts/mautic-n8n-stack" ]]; then
    PROJECT_DIR="/root/scripts/mautic-n8n-stack"
else
    print_error "Project directory not found"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$PROJECT_DIR/backups/manual-$TIMESTAMP"
BACKUP_NAME="backup-$TIMESTAMP.tar.gz"

echo
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              On-Demand Backup Creator                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo
print_status "Project: $PROJECT_DIR"
print_status "Backup will be saved as: $BACKUP_NAME"
echo

# Create backup directory
mkdir -p "$BACKUP_DIR"

cd "$PROJECT_DIR"

# Check if .env exists
if [[ ! -f .env ]]; then
    print_error ".env file not found"
    exit 1
fi

source .env

# =============================================================================
# BACKUP PROCESS
# =============================================================================

print_status "Starting backup process..."
echo

# 1. Backup MySQL (Mautic)
if docker ps | grep -q "mautic-mysql"; then
    print_status "Backing up MySQL (Mautic database)..."
    if docker-compose exec -T mysql mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases > "$BACKUP_DIR/mysql.sql" 2>/dev/null; then
        MYSQL_SIZE=$(du -h "$BACKUP_DIR/mysql.sql" | cut -f1)
        print_success "✓ MySQL backed up ($MYSQL_SIZE)"
    else
        print_warning "✗ MySQL backup failed (container may not be running)"
    fi
else
    print_warning "MySQL container not running - skipping"
fi

# 2. Backup PostgreSQL (Strapi)
if docker ps | grep -q "strapi-postgres"; then
    print_status "Backing up PostgreSQL (Strapi + vectors)..."
    if docker-compose exec -T postgres pg_dumpall -U strapi > "$BACKUP_DIR/postgres.sql" 2>/dev/null; then
        PG_SIZE=$(du -h "$BACKUP_DIR/postgres.sql" | cut -f1)
        print_success "✓ PostgreSQL backed up ($PG_SIZE)"
    else
        print_warning "✗ PostgreSQL backup failed"
    fi
else
    print_warning "PostgreSQL container not running - skipping"
fi

# 3. Backup configuration files
print_status "Backing up configuration files..."
cp .env "$BACKUP_DIR/.env" 2>/dev/null && print_success "✓ .env file backed up"
cp docker-compose.yml "$BACKUP_DIR/docker-compose.yml" 2>/dev/null && print_success "✓ docker-compose.yml backed up"

# 4. Backup Strapi project
if [[ -d "strapi" ]]; then
    print_status "Backing up Strapi project (excluding node_modules)..."
    if tar czf "$BACKUP_DIR/strapi-project.tar.gz" -C . strapi \
        --exclude='strapi/node_modules' \
        --exclude='strapi/.cache' \
        --exclude='strapi/build' \
        --exclude='strapi/.tmp' 2>/dev/null; then
        STRAPI_SIZE=$(du -h "$BACKUP_DIR/strapi-project.tar.gz" | cut -f1)
        print_success "✓ Strapi project backed up ($STRAPI_SIZE)"
    else
        print_warning "✗ Strapi backup failed"
    fi
fi

# 5. Backup Docker volumes
print_status "Backing up Docker volumes..."

# Mautic config volume
if docker volume ls | grep -q "mautic_data_config"; then
    docker run --rm -v mautic-n8n-stack_mautic_data_config:/source:ro -v "$BACKUP_DIR":/backup alpine tar czf /backup/mautic_config.tar.gz -C /source . 2>/dev/null && print_success "✓ Mautic config backed up"
fi

# Mautic media volume
if docker volume ls | grep -q "mautic_data_media_images"; then
    docker run --rm -v mautic-n8n-stack_mautic_data_media_images:/source:ro -v "$BACKUP_DIR":/backup alpine tar czf /backup/mautic_media.tar.gz -C /source . 2>/dev/null && print_success "✓ Mautic media backed up"
fi

# n8n data volume
if docker volume ls | grep -q "n8n_data"; then
    docker run --rm -v mautic-n8n-stack_n8n_data:/source:ro -v "$BACKUP_DIR":/backup alpine tar czf /backup/n8n_data.tar.gz -C /source . 2>/dev/null && print_success "✓ n8n workflows backed up"
fi

# 6. Create backup info file
print_status "Creating backup metadata..."
cat > "$BACKUP_DIR/backup_info.txt" << EOF
Backup Information
==================
Created: $(date)
Server: $(hostname)
IP: $(curl -4 -s ifconfig.me 2>/dev/null || echo "Unknown")
Type: Manual on-demand backup
Stack Version: V5 Production

Included:
- MySQL database (Mautic)
- PostgreSQL database (Strapi + pgvector)
- Configuration files (.env, docker-compose.yml)
- Strapi project (excluding node_modules)
- Docker volumes (Mautic config, media, n8n workflows)

Services backed up:
$(docker-compose ps --services 2>/dev/null || echo "Unknown")

Disk usage before backup:
$(df -h / | tail -1)
EOF

print_success "✓ Metadata created"

# 7. Create final compressed archive
echo
print_status "Creating final compressed archive..."
cd "$PROJECT_DIR/backups"

if tar czf "$BACKUP_NAME" -C "manual-$TIMESTAMP" .; then
    # Remove temporary directory
    rm -rf "manual-$TIMESTAMP"

    FINAL_SIZE=$(du -h "$BACKUP_NAME" | cut -f1)

    echo
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              Backup Completed Successfully!               ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo
    print_success "Backup file: $BACKUP_NAME"
    print_success "Location: $PROJECT_DIR/backups/"
    print_success "Size: $FINAL_SIZE"
    echo

    # Show full path
    FULL_PATH="$PROJECT_DIR/backups/$BACKUP_NAME"
    print_status "Full path: $FULL_PATH"
    echo

    # Download instructions
    echo "📥 To download to your desktop:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "Option 1 - Use the download helper:"
    echo "  ./download_backup.sh $BACKUP_NAME"
    echo
    echo "Option 2 - Manual SCP (from your desktop):"
    SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo "  scp root@${SERVER_IP}:${FULL_PATH} ~/Desktop/"
    echo
    echo "Option 3 - Manual download via SFTP:"
    echo "  Server: ${SERVER_IP}"
    echo "  Path: ${FULL_PATH}"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # Cleanup suggestion
    print_warning "Remember to remove old backups to save space:"
    echo "  ls -lh $PROJECT_DIR/backups/"
    echo "  rm $PROJECT_DIR/backups/backup-YYYYMMDD_HHMMSS.tar.gz"
    echo

else
    print_error "Failed to create final archive"
    exit 1
fi
