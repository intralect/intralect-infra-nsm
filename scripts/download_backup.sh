#!/bin/bash

# =============================================================================
# Backup Download Helper
# Easy way to download backups to your desktop
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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

BACKUP_DIR="$PROJECT_DIR/backups"

echo
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║            Backup Download Helper                        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo

# Check if backup file specified
if [[ -n "$1" ]]; then
    BACKUP_FILE="$1"
else
    # List available backups
    print_status "Available backups:"
    echo
    if ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | nl; then
        echo
        read -p "Enter backup number or filename: " SELECTION

        if [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
            # User entered a number
            BACKUP_FILE=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | sed -n "${SELECTION}p" | xargs basename)
        else
            # User entered filename
            BACKUP_FILE="$SELECTION"
        fi
    else
        print_error "No backups found in $BACKUP_DIR"
        exit 1
    fi
fi

# Verify backup exists
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"
if [[ ! -f "$BACKUP_PATH" ]]; then
    print_error "Backup not found: $BACKUP_FILE"
    exit 1
fi

# Get server info
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)

echo
print_status "Backup: $BACKUP_FILE"
print_status "Size: $BACKUP_SIZE"
print_status "Server IP: $SERVER_IP"
echo

# Show download instructions
echo "📥 Download Instructions:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

echo "1️⃣  Using SCP (Recommended)"
echo "   Run this on YOUR DESKTOP/LAPTOP (not on the server):"
echo
echo -e "${GREEN}   scp root@${SERVER_IP}:${BACKUP_PATH} ~/Desktop/${NC}"
echo

echo "2️⃣  Using SFTP Client (FileZilla, Cyberduck, WinSCP)"
echo "   Server: ${SERVER_IP}"
echo "   Username: root"
echo "   Path: ${BACKUP_PATH}"
echo

echo "3️⃣  Using wget (if HTTP server is running)"
echo "   First, make accessible:"
echo "   python3 -m http.server 8888 -d $BACKUP_DIR"
echo
echo "   Then download:"
echo "   wget http://${SERVER_IP}:8888/${BACKUP_FILE}"
echo

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Offer to start temporary HTTP server
print_warning "Start temporary HTTP server for download? (Y/n)"
read -n 1 -r
echo

if [[ ${REPLY:-Y} =~ ^[Yy]$ ]]; then
    print_status "Starting HTTP server on port 8888..."
    print_warning "Server will be accessible at: http://${SERVER_IP}:8888/"
    echo
    print_status "Download your file:"
    echo "  http://${SERVER_IP}:8888/${BACKUP_FILE}"
    echo
    print_warning "Press Ctrl+C to stop the server when download completes"
    echo

    cd "$BACKUP_DIR"
    python3 -m http.server 8888
fi
