#!/bin/bash

# Enhanced S3 Backup Script for Mautic + n8n Stack
# Integrates with deploy-mautic-n8n.sh management system

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/mautic-n8n-stack"
ENV_FILE="$PROJECT_DIR/.env"
BACKUP_CREDENTIALS_FILE="$PROJECT_DIR/.env.backup"

# Print functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check required commands
check_requirements() {
    for cmd in tar mysqldump gzip docker docker-compose; do
        if ! command -v $cmd &>/dev/null; then
            print_error "'$cmd' is not installed. Please install it first."
            exit 1
        fi
    done
}

# Load or configure backup credentials
setup_backup_credentials() {
    if [[ -f "$BACKUP_CREDENTIALS_FILE" ]]; then
        source "$BACKUP_CREDENTIALS_FILE"
        return 0
    fi

    clear
    echo "╔════════════════════════════════════════════╗"
    echo "║   AWS S3 Backup Configuration Setup       ║"
    echo "╚════════════════════════════════════════════╝"
    echo
    print_status "First-time S3 backup setup. Credentials will be stored securely."
    echo

    read -p "Enter AWS S3 bucket name: " AWS_S3_BUCKET

    echo
    print_status "AWS Credentials (leave empty to use AWS CLI/IAM role):"
    read -p "AWS Access Key ID (optional): " AWS_ACCESS_KEY_ID
    if [[ -n "$AWS_ACCESS_KEY_ID" ]]; then
        read -sp "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
        echo
    fi

    echo
    print_status "Backup Retention Policy:"
    read -p "Keep last N backups locally (default: 5): " LOCAL_BACKUP_RETENTION
    LOCAL_BACKUP_RETENTION=${LOCAL_BACKUP_RETENTION:-5}

    read -p "Keep last N backups in S3 (default: 10): " S3_BACKUP_RETENTION
    S3_BACKUP_RETENTION=${S3_BACKUP_RETENTION:-10}

    # Save credentials securely
    cat > "$BACKUP_CREDENTIALS_FILE" << EOF
# AWS S3 Backup Configuration
# Created: $(date)
AWS_S3_BUCKET="$AWS_S3_BUCKET"
AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
LOCAL_BACKUP_RETENTION=$LOCAL_BACKUP_RETENTION
S3_BACKUP_RETENTION=$S3_BACKUP_RETENTION
EOF

    chmod 600 "$BACKUP_CREDENTIALS_FILE"
    print_success "Backup credentials saved securely to $BACKUP_CREDENTIALS_FILE"
    echo

    # Source the file
    source "$BACKUP_CREDENTIALS_FILE"
}

# Main backup function
create_backup() {
    clear
    echo "╔════════════════════════════════════════════╗"
    echo "║     Mautic + n8n Backup to S3             ║"
    echo "╚════════════════════════════════════════════╝"
    echo

    check_requirements

    local TIMESTAMP=$(date +%Y-%m-%d-%H%M)
    local backup_dir="$PROJECT_DIR/backups/backup-$TIMESTAMP"

    mkdir -p "$backup_dir" || {
        print_error "Could not create backup directory"
        exit 1
    }

    print_status "Creating backup: backup-$TIMESTAMP"
    echo

    cd "$PROJECT_DIR" || exit 1

    # Load environment variables
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE"
    else
        print_error "Environment file not found at $ENV_FILE"
        exit 1
    fi

    # 1. Backup MySQL Database
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_status "Step 1/4: Backing up MySQL database..."

    if docker-compose ps mysql 2>/dev/null | grep -q Up; then
        docker-compose exec -T mysql mysqldump \
            -u root \
            -p"$MYSQL_ROOT_PASSWORD" \
            --all-databases \
            --single-transaction \
            --quick \
            --lock-tables=false \
            > "$backup_dir/database.sql" 2>/dev/null

        if [[ $? -eq 0 && -s "$backup_dir/database.sql" ]]; then
            local db_size=$(du -h "$backup_dir/database.sql" | cut -f1)
            print_success "✓ Database backed up ($db_size)"
        else
            print_warning "⚠ Database backup failed or empty"
        fi
    else
        print_warning "⚠ MySQL container not running, skipping database backup"
    fi
    echo

    # 2. Backup Configuration Files
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_status "Step 2/4: Backing up configuration files..."

    cp "$ENV_FILE" "$backup_dir/.env" 2>/dev/null && print_success "✓ .env"
    cp "$PROJECT_DIR/docker-compose.yml" "$backup_dir/docker-compose.yml" 2>/dev/null && print_success "✓ docker-compose.yml"

    if [[ -f "$BACKUP_CREDENTIALS_FILE" ]]; then
        cp "$BACKUP_CREDENTIALS_FILE" "$backup_dir/.env.backup" 2>/dev/null && print_success "✓ .env.backup"
    fi
    echo

    # 3. Backup Docker Volumes
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_status "Step 3/4: Backing up Docker volumes..."

    local volumes=(
        "mautic_data_config"
        "mautic_data_media_files"
        "mautic_data_media_images"
        "n8n_data"
        "traefik_data"
    )

    for vol in "${volumes[@]}"; do
        local vol_name=$(docker volume ls -q | grep "mautic-n8n-stack_${vol}" | head -1)
        if [[ -n "$vol_name" ]]; then
            print_status "  → $vol"
            docker run --rm \
                -v "${vol_name}:/source:ro" \
                -v "$backup_dir":/backup \
                alpine tar czf "/backup/${vol}.tar.gz" -C /source . 2>/dev/null

            if [[ $? -eq 0 ]]; then
                local vol_size=$(du -h "$backup_dir/${vol}.tar.gz" | cut -f1)
                print_success "    ✓ Backed up ($vol_size)"
            else
                print_warning "    ⚠ Failed to backup"
            fi
        fi
    done
    echo

    # Create backup info file
    cat > "$backup_dir/backup_info.txt" << EOF
╔════════════════════════════════════════════╗
║         Backup Information                 ║
╚════════════════════════════════════════════╝

Backup Created: $(date)
Timestamp: $TIMESTAMP
Server IP: ${SERVER_IP:-N/A}
Mautic URL: ${MAUTIC_URL:-N/A}
n8n URL: ${N8N_URL:-N/A}
Docker Compose: $(docker-compose version --short 2>/dev/null || echo "Unknown")

Backup Contents:
  • MySQL Database (all databases)
  • Environment configuration (.env)
  • Docker Compose configuration
  • Mautic configuration data
  • Mautic media files (files & images)
  • n8n workflow data
  • Traefik SSL certificates

Restore Instructions:
1. Extract backup: tar -xzf server-backup-$TIMESTAMP.tar.gz
2. Stop services: docker-compose down
3. Restore volumes using docker run with alpine
4. Restore database: docker-compose exec -T mysql mysql -u root -p < database.sql
5. Restore configs: cp .env and docker-compose.yml to project directory
6. Start services: docker-compose up -d
EOF

    # 4. Create compressed archive
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_status "Step 4/4: Creating compressed archive..."

    local BACKUP_FILENAME="server-backup-$TIMESTAMP.tar.gz"
    cd "$PROJECT_DIR/backups"

    tar -czf "$BACKUP_FILENAME" -C "backup-$TIMESTAMP" . 2>/dev/null

    if [[ $? -ne 0 ]]; then
        print_error "Failed to create compressed archive"
        exit 1
    fi

    local BACKUP_SIZE=$(du -h "$BACKUP_FILENAME" | cut -f1)
    print_success "✓ Archive created: $BACKUP_FILENAME ($BACKUP_SIZE)"
    echo

    # Upload to S3
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "Upload backup to AWS S3? (y/N): " UPLOAD_S3

    if [[ "$UPLOAD_S3" =~ ^[Yy]$ ]]; then
        # Check AWS CLI
        if ! command -v aws &>/dev/null; then
            print_error "AWS CLI is not installed."
            print_status "Install with: sudo apt-get install awscli"
            echo
            print_success "Local backup completed: $PROJECT_DIR/backups/$BACKUP_FILENAME"
            exit 0
        fi

        # Setup credentials
        setup_backup_credentials

        if [[ -z "$AWS_S3_BUCKET" ]]; then
            print_error "S3 bucket not configured"
            exit 1
        fi

        # Choose S3 Storage Class
        echo
        print_status "Choose S3 Storage Class:"
        echo "  1) STANDARD          - Frequent access, highest cost"
        echo "  2) STANDARD_IA       - Infrequent access (Recommended)"
        echo "  3) GLACIER_IR        - Instant retrieval, lower cost"
        echo "  4) DEEP_ARCHIVE      - 12+ hour retrieval, lowest cost"
        read -p "Enter choice (1-4, default: 2): " STORAGE_CHOICE

        case ${STORAGE_CHOICE:-2} in
            1) STORAGE_CLASS="STANDARD" ;;
            2) STORAGE_CLASS="STANDARD_IA" ;;
            3) STORAGE_CLASS="GLACIER_IR" ;;
            4) STORAGE_CLASS="DEEP_ARCHIVE" ;;
            *) STORAGE_CLASS="STANDARD_IA" ;;
        esac

        echo
        print_status "Uploading to S3..."
        print_status "  Bucket: $AWS_S3_BUCKET"
        print_status "  Storage Class: $STORAGE_CLASS"
        print_status "  File: $BACKUP_FILENAME"
        echo

        # Set AWS credentials if provided
        if [[ -n "$AWS_ACCESS_KEY_ID" ]]; then
            export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
            export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
        fi

        # Upload to S3 with progress
        aws s3 cp "$BACKUP_FILENAME" "s3://$AWS_S3_BUCKET/$BACKUP_FILENAME" \
            --storage-class "$STORAGE_CLASS" 2>&1

        if [[ $? -eq 0 ]]; then
            echo
            print_success "✓ Successfully uploaded to S3!"
            echo
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  Backup Locations:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  📁 Local:  $PROJECT_DIR/backups/$BACKUP_FILENAME"
            echo "  ☁️  S3:     s3://$AWS_S3_BUCKET/$BACKUP_FILENAME"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
            echo
            print_error "S3 upload failed!"
            print_status "Check AWS credentials and bucket permissions."
            print_status "Local backup available: $PROJECT_DIR/backups/$BACKUP_FILENAME"
        fi

        # Unset AWS credentials
        unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

        # Cleanup old S3 backups
        if [[ -n "$S3_BACKUP_RETENTION" ]] && [[ $? -eq 0 ]]; then
            echo
            print_status "Cleaning up old S3 backups (keeping last $S3_BACKUP_RETENTION)..."

            aws s3 ls "s3://$AWS_S3_BUCKET/" | grep "server-backup-" | sort -r | tail -n +$((S3_BACKUP_RETENTION + 1)) | awk '{print $4}' | while read old_backup; do
                aws s3 rm "s3://$AWS_S3_BUCKET/$old_backup" 2>/dev/null && print_status "  → Deleted: $old_backup"
            done
        fi
    else
        echo
        print_success "Local backup completed!"
        echo "  📁 Location: $PROJECT_DIR/backups/$BACKUP_FILENAME"
    fi

    # Cleanup old local backups
    if [[ -f "$BACKUP_CREDENTIALS_FILE" ]]; then
        source "$BACKUP_CREDENTIALS_FILE"
        if [[ -n "$LOCAL_BACKUP_RETENTION" ]]; then
            echo
            print_status "Cleaning up old local backups (keeping last $LOCAL_BACKUP_RETENTION)..."
            cd "$PROJECT_DIR/backups"

            ls -t server-backup-*.tar.gz 2>/dev/null | tail -n +$((LOCAL_BACKUP_RETENTION + 1)) | while read old_file; do
                rm -f "$old_file" && print_status "  → Deleted: $old_file"
            done

            ls -dt backup-*/ 2>/dev/null | tail -n +$((LOCAL_BACKUP_RETENTION + 1)) | while read old_dir; do
                rm -rf "$old_dir" && print_status "  → Deleted: $old_dir"
            done
        fi
    fi

    echo
    echo "╔════════════════════════════════════════════╗"
    echo "║     Backup Process Completed! ✓            ║"
    echo "╚════════════════════════════════════════════╝"
}

# Run backup
create_backup
