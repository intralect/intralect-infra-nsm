#!/bin/bash

# =============================================================================
# n8n Update Utility - Safe Individual Service Update
# =============================================================================
#
# Usage:
#   ./update_n8n.sh                    # Update to latest
#   ./update_n8n.sh 2.0                # Update to v2.0
#   ./update_n8n.sh 1.68.0             # Update to specific version
#
# Features:
#   ✅ Automatic backup before update
#   ✅ Health check after update
#   ✅ Automatic rollback on failure
#   ✅ Zero downtime for other services
#
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
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

BACKUP_DIR="$PROJECT_DIR/backups/n8n-pre-update-$(date +%Y%m%d_%H%M%S)"

# Get target version
TARGET_VERSION="${1:-latest}"
if [[ "$TARGET_VERSION" != "latest" ]] && [[ ! "$TARGET_VERSION" =~ ^[0-9] ]]; then
    print_error "Invalid version format. Use: 2.0 or 1.68.0 or latest"
    exit 1
fi

# Add v prefix if not present and not latest
if [[ "$TARGET_VERSION" != "latest" ]] && [[ ! "$TARGET_VERSION" =~ ^v ]]; then
    N8N_IMAGE="n8nio/n8n:$TARGET_VERSION"
else
    N8N_IMAGE="n8nio/n8n:$TARGET_VERSION"
fi

echo
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              n8n Update Utility - V5                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo
print_status "Project: $PROJECT_DIR"
print_status "Target version: $TARGET_VERSION"
echo

# =============================================================================
# PREFLIGHT
# =============================================================================

print_status "Checking current n8n status..."
cd "$PROJECT_DIR"

if ! docker ps | grep -q "n8n"; then
    print_error "n8n container not running"
    exit 1
fi

# Get current version
CURRENT_VERSION=$(docker exec n8n n8n --version 2>/dev/null | head -1 || echo "unknown")
print_status "Current version: $CURRENT_VERSION"

# Check if already on target
if [[ "$CURRENT_VERSION" == *"$TARGET_VERSION"* ]] && [[ "$TARGET_VERSION" != "latest" ]]; then
    print_warning "Already on version $TARGET_VERSION"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

# =============================================================================
# BACKUP
# =============================================================================

print_status "Creating backup..."
mkdir -p "$BACKUP_DIR"

# Backup n8n data volume
print_status "Backing up n8n workflows and credentials..."
docker run --rm \
    -v mautic-n8n-stack_n8n_data:/source:ro \
    -v "$BACKUP_DIR":/backup \
    alpine tar czf /backup/n8n_data.tar.gz -C /source .

# Save current image name
docker inspect n8n --format='{{.Config.Image}}' > "$BACKUP_DIR/previous_image.txt"

print_success "Backup created: $BACKUP_DIR"

# =============================================================================
# UPDATE
# =============================================================================

print_warning "Ready to update n8n to $TARGET_VERSION"
print_warning "This will:"
echo "  • Stop n8n container"
echo "  • Pull new n8n image"
echo "  • Start n8n with new version"
echo "  • Verify health"
echo "  • Rollback if health check fails"
echo
read -p "Continue? (y/N): " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

print_status "Stopping n8n..."
docker-compose stop n8n

print_status "Updating docker-compose to use $N8N_IMAGE..."

# Update docker-compose.yml
if command -v yq >/dev/null 2>&1; then
    # If yq is available, use it
    yq e ".services.n8n.image = \"$N8N_IMAGE\"" -i docker-compose.yml
else
    # Use sed as fallback
    sed -i "s|image: n8nio/n8n:.*|image: $N8N_IMAGE|" docker-compose.yml
fi

print_status "Pulling new image..."
docker-compose pull n8n

print_status "Starting n8n with new version..."
docker-compose up -d n8n

# =============================================================================
# VERIFICATION
# =============================================================================

print_status "Waiting for n8n to start..."
sleep 10

# Health check (try for 60 seconds)
print_status "Checking n8n health..."
HEALTHY=false
for i in {1..12}; do
    if docker ps | grep -q "n8n.*Up"; then
        # Try to get version
        NEW_VERSION=$(docker exec n8n n8n --version 2>/dev/null | head -1 || echo "")
        if [[ -n "$NEW_VERSION" ]]; then
            HEALTHY=true
            break
        fi
    fi
    echo -n "."
    sleep 5
done
echo

if [[ "$HEALTHY" == "true" ]]; then
    print_success "✓ n8n is running and healthy!"
    print_success "✓ New version: $NEW_VERSION"
    echo
    echo "🎉 Update completed successfully!"
    echo
    print_status "Access n8n at: https://$(grep N8N_URL .env | cut -d= -f2)"
    echo
    print_warning "Backup kept at: $BACKUP_DIR"
    print_status "Remove after verifying everything works"
    echo
else
    print_error "✗ Health check failed!"
    echo
    print_warning "Rolling back to previous version..."

    # Rollback
    docker-compose stop n8n

    # Restore previous image
    PREVIOUS_IMAGE=$(cat "$BACKUP_DIR/previous_image.txt")
    sed -i "s|image: n8nio/n8n:.*|image: $PREVIOUS_IMAGE|" docker-compose.yml

    docker-compose up -d n8n

    sleep 10

    if docker ps | grep -q "n8n.*Up"; then
        print_success "Rollback successful - n8n restored to previous version"
    else
        print_error "Rollback failed! Manual intervention required."
        print_error "Restore from backup: $BACKUP_DIR"
    fi

    exit 1
fi

# =============================================================================
# CLEANUP
# =============================================================================

print_status "Cleaning up old Docker images..."
docker image prune -f >/dev/null 2>&1

print_success "Update completed!"
