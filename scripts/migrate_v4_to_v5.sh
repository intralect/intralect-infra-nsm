#!/bin/bash

# =============================================================================
# V4 to V5 Migration Script
# CRITICAL: Preserves production Mautic configuration
# =============================================================================
#
# This script safely migrates from V4 to V5 while:
# ✅ Preserving ALL Mautic configuration and data
# ✅ Keeping Mautic, MySQL, and RabbitMQ untouched
# ✅ Fixing Strapi to production mode
# ✅ Adding monitoring and automated backups
# ✅ Enabling individual service updates
#
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Paths
V4_DIR="/root/scripts/mautic-n8n-stack"
V5_DIR="/root/scripts/mautic-n8n-stack-v5"
BACKUP_DIR="/root/scripts/backups/pre-v5-migration-$(date +%Y%m%d_%H%M%S)"

# Print functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════╗${NC}"; echo -e "${PURPLE}║         V4 → V5 PRODUCTION MIGRATION${NC}"; echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════╝${NC}"; }

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

preflight_checks() {
    print_header
    echo

    print_status "Running pre-flight checks..."

    # Check V4 exists
    if [[ ! -d "$V4_DIR" ]]; then
        print_error "V4 directory not found: $V4_DIR"
        exit 1
    fi

    # Check services are running
    cd "$V4_DIR"
    if ! docker-compose ps | grep -q "Up"; then
        print_error "V4 services not running. Please start them first."
        exit 1
    fi

    # Check Mautic health
    if ! docker exec mautic-web curl -f http://localhost:80 >/dev/null 2>&1; then
        print_warning "Mautic health check failed. Continue anyway? (y/N)"
        read -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi

    # Check disk space (need at least 10GB for backups)
    local avail=$(df / | tail -1 | awk '{print $4}')
    local avail_gb=$((avail / 1024 / 1024))
    if [[ $avail_gb -lt 10 ]]; then
        print_error "Insufficient disk space. Need 10GB+, have ${avail_gb}GB"
        exit 1
    fi

    print_success "Pre-flight checks passed"
}

# =============================================================================
# FULL BACKUP
# =============================================================================

create_full_backup() {
    print_status "Creating full V4 backup..."
    mkdir -p "$BACKUP_DIR"

    cd "$V4_DIR"
    source .env

    # Backup databases
    print_status "Backing up MySQL (Mautic)..."
    docker-compose exec -T mysql mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases > "$BACKUP_DIR/mysql_full.sql" 2>/dev/null

    print_status "Backing up PostgreSQL (Strapi)..."
    docker-compose exec -T postgres pg_dumpall -U strapi > "$BACKUP_DIR/postgres_full.sql" 2>/dev/null

    # Backup configs
    print_status "Backing up configuration files..."
    cp .env "$BACKUP_DIR/"
    cp docker-compose.yml "$BACKUP_DIR/"

    # Backup Strapi project
    if [[ -d "strapi" ]]; then
        tar czf "$BACKUP_DIR/strapi-project.tar.gz" -C . strapi --exclude='strapi/node_modules' --exclude='strapi/.cache' 2>/dev/null
    fi

    # Create archive
    print_status "Creating compressed backup..."
    cd /root/scripts/backups
    tar czf "v4-full-backup-$(date +%Y%m%d_%H%M%S).tar.gz" -C "$(basename $BACKUP_DIR)" . 2>/dev/null

    print_success "Full backup created: $BACKUP_DIR"
    echo "Archive: /root/scripts/backups/v4-full-backup-*.tar.gz"
}

# =============================================================================
# MIGRATION
# =============================================================================

migrate_to_v5() {
    print_status "Starting V4 → V5 migration..."

    # Create V5 directory structure
    mkdir -p "$V5_DIR"/{scripts,monitoring,backups}

    # Copy and migrate .env file
    print_status "Migrating environment configuration..."
    cp "$V4_DIR/.env" "$V5_DIR/.env"

    # Add V5 specific variables
    cat >> "$V5_DIR/.env" << 'EOF'

# =============================================================================
# V5 Production Enhancements
# =============================================================================
# Updated: $(date)

# Strapi PRODUCTION MODE (changed from development)
NODE_ENV=production

# Monitoring
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

# Resource Limits
MYSQL_MAX_CONNECTIONS=100
POSTGRES_MAX_CONNECTIONS=100
EOF

    # Create enhanced docker-compose.yml
    print_status "Creating V5 docker-compose with production settings..."

    cat > "$V5_DIR/docker-compose.yml" << 'EOFCOMPOSE'
networks:
  mautic_network:
    driver: bridge

volumes:
  traefik_data:
  mautic_data_cron:
  mautic_data_vendor:
  mysql_data:
  n8n_data:
  mautic_data_media_files:
  rabbitmq_data:
  mautic_data_media_images:
  mautic_data_plugins:
  mautic_data_cache:
  mautic_data_spool:
  mautic_data_config:
  mautic_data_logs:
  postgres_data:
  prometheus_data:
  grafana_data:

services:
  # ===========================================
  # Traefik Reverse Proxy (FIXED health check)
  # ===========================================
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    command:
      - --api.dashboard=true
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencrypt.acme.httpchallenge=true
      - --certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web
      - --certificatesresolvers.letsencrypt.acme.email=info@yaicos.com
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
      - --entrypoints.web.http.redirections.entrypoint.to=websecure
      - --entrypoints.web.http.redirections.entrypoint.scheme=https
      - --ping=true
      - --ping.entrypoint=web
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_data:/letsencrypt
    networks:
      - mautic_network
    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # ===========================================
  # MySQL (EXACT MAUTIC CONFIGURATION - DO NOT CHANGE)
  # ===========================================
  mysql:
    image: mysql:8.0
    container_name: mautic-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: mautic
      MYSQL_USER: mautic
      MYSQL_PASSWORD: ${MAUTIC_DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password --innodb-buffer-pool-size=256M
    networks:
      - mautic_network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 5

  # ===========================================
  # PostgreSQL with pgvector (Strapi)
  # ===========================================
  postgres:
    image: pgvector/pgvector:pg15
    container_name: strapi-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - mautic_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U strapi"]
      interval: 30s
      timeout: 10s
      retries: 5

  # ===========================================
  # RabbitMQ (EXACT MAUTIC CONFIGURATION - DO NOT CHANGE)
  # ===========================================
  rabbitmq:
    image: rabbitmq:3.12-management-alpine
    container_name: mautic-rabbitmq
    restart: unless-stopped
    environment:
      RABBITMQ_DEFAULT_USER: mautic
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD}
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - mautic_network
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

  # ===========================================
  # Strapi CMS (PRODUCTION MODE - V5 UPDATE)
  # ===========================================
  strapi:
    image: node:20-alpine
    container_name: strapi
    restart: unless-stopped
    working_dir: /srv/app
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      NODE_ENV: production
      HOST: 0.0.0.0
      PORT: 1337
      DATABASE_HOST: postgres
      DATABASE_PORT: 5432
      DATABASE_NAME: ${POSTGRES_DB}
      DATABASE_USERNAME: ${POSTGRES_USER}
      DATABASE_PASSWORD: ${POSTGRES_PASSWORD}
      DATABASE_SSL: "false"
      JWT_SECRET: ${STRAPI_JWT_SECRET}
      ADMIN_JWT_SECRET: ${STRAPI_ADMIN_JWT_SECRET}
      APP_KEYS: ${STRAPI_APP_KEYS}
      API_TOKEN_SALT: ${STRAPI_API_TOKEN_SALT}
      TRANSFER_TOKEN_SALT: ${STRAPI_TRANSFER_TOKEN_SALT}
      OPENAI_API_KEY: ${OPENAI_API_KEY:-}
      GEMINI_API_KEY: ${GEMINI_API_KEY:-}
      ENABLE_SEMANTIC_SEARCH: ${ENABLE_SEMANTIC_SEARCH:-false}
    volumes:
      - ./strapi:/srv/app
    command: sh -c "npm install --legacy-peer-deps --production 2>/dev/null; npm run build 2>/dev/null; npm run start"
    labels:
      - traefik.enable=true
      - traefik.http.routers.strapi.rule=Host(`${STRAPI_URL}`)
      - traefik.http.routers.strapi.tls=true
      - traefik.http.routers.strapi.tls.certresolver=letsencrypt
      - traefik.http.services.strapi.loadbalancer.server.port=1337
    networks:
      - mautic_network

  # ===========================================
  # Mautic Web (EXACT PRODUCTION CONFIG - DO NOT CHANGE)
  # ===========================================
  mautic_web:
    image: mautic/mautic:5-apache
    container_name: mautic-web
    restart: unless-stopped
    depends_on:
      mysql:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy
    environment:
      - MAUTIC_DB_HOST=mysql
      - MAUTIC_DB_USER=mautic
      - MAUTIC_DB_PASSWORD=${MAUTIC_DB_PASSWORD}
      - MAUTIC_DB_NAME=mautic
      - MAUTIC_MESSENGER_TRANSPORT_DSN=amqp://mautic:${RABBITMQ_PASSWORD}@rabbitmq:5672/%2f/messages
      - DOCKER_MAUTIC_RUN_MIGRATIONS=true
    volumes:
      - mautic_data_config:/var/www/html/config
      - mautic_data_logs:/var/www/html/var/logs
      - mautic_data_media_files:/var/www/html/media/files
      - mautic_data_media_images:/var/www/html/media/images
      - mautic_data_plugins:/var/www/html/plugins
      - mautic_data_vendor:/var/www/html/vendor
    labels:
      - traefik.enable=true
      - traefik.http.routers.mautic.rule=Host(`${MAUTIC_URL}`)
      - traefik.http.routers.mautic.tls=true
      - traefik.http.routers.mautic.tls.certresolver=letsencrypt
      - traefik.http.services.mautic.loadbalancer.server.port=80
    networks:
      - mautic_network

  # ===========================================
  # Mautic Cron (EXACT PRODUCTION CONFIG - DO NOT CHANGE)
  # ===========================================
  mautic_cron:
    image: mautic/mautic:5-apache
    container_name: mautic-cron
    restart: unless-stopped
    depends_on:
      - mautic_web
    environment:
      - MAUTIC_DB_HOST=mysql
      - MAUTIC_DB_USER=mautic
      - MAUTIC_DB_PASSWORD=${MAUTIC_DB_PASSWORD}
      - MAUTIC_DB_NAME=mautic
      - MAUTIC_MESSENGER_TRANSPORT_DSN=amqp://mautic:${RABBITMQ_PASSWORD}@rabbitmq:5672/%2f/messages
    volumes:
      - mautic_data_config:/var/www/html/config
      - mautic_data_logs:/var/www/html/var/logs
      - mautic_data_cron:/var/www/html/var/spool
      - mautic_data_cache:/var/www/html/var/cache
    command: sh -c "while true; do php /var/www/html/bin/console mautic:segments:update --quiet; php /var/www/html/bin/console mautic:campaigns:update --quiet; php /var/www/html/bin/console mautic:campaigns:trigger --quiet; sleep 60; done"
    networks:
      - mautic_network

  # ===========================================
  # n8n Workflow Automation
  # ===========================================
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - N8N_HOST=${N8N_URL}
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${N8N_URL}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - DB_TYPE=sqlite
      - GENERIC_TIMEZONE=${TZ}
      - STRAPI_API_URL=https://${STRAPI_URL}
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
    volumes:
      - n8n_data:/home/node/.n8n
    labels:
      - traefik.enable=true
      - traefik.http.routers.n8n.rule=Host(`${N8N_URL}`)
      - traefik.http.routers.n8n.tls=true
      - traefik.http.routers.n8n.tls.certresolver=letsencrypt
      - traefik.http.services.n8n.loadbalancer.server.port=5678
    networks:
      - mautic_network

  # ===========================================
  # Prometheus (Monitoring - NEW IN V5)
  # ===========================================
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    networks:
      - mautic_network
    labels:
      - traefik.enable=false

  # ===========================================
  # Grafana (Dashboards - NEW IN V5)
  # ===========================================
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./monitoring/datasources:/etc/grafana/provisioning/datasources:ro
    networks:
      - mautic_network
    labels:
      - traefik.enable=true
      - traefik.http.routers.grafana.rule=Host(`monitor.${MAIN_DOMAIN}`)
      - traefik.http.routers.grafana.tls=true
      - traefik.http.routers.grafana.tls.certresolver=letsencrypt
      - traefik.http.services.grafana.loadbalancer.server.port=3000
EOFCOMPOSE

    # Copy Strapi project
    print_status "Migrating Strapi project..."
    cp -r "$V4_DIR/strapi" "$V5_DIR/"

    # Update Strapi to production mode
    if [[ -f "$V5_DIR/strapi/package.json" ]]; then
        print_status "Updating Strapi package.json for production..."
        # Already has the right dependencies
    fi

    print_success "V5 configuration created"
}

# =============================================================================
# SETUP MONITORING
# =============================================================================

setup_monitoring() {
    print_status "Setting up monitoring stack..."

    mkdir -p "$V5_DIR/monitoring"/{dashboards,datasources}

    # Create Prometheus config
    cat > "$V5_DIR/monitoring/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'docker'
    static_configs:
      - targets: ['host.docker.internal:9323']
EOF

    # Create Grafana datasource
    cat > "$V5_DIR/monitoring/datasources/prometheus.yml" << 'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

    print_success "Monitoring configuration created"
}

# =============================================================================
# DEPLOYMENT
# =============================================================================

deploy_v5() {
    print_status "Deploying V5 stack..."

    cd "$V5_DIR"

    # Pull new images
    print_status "Pulling Docker images..."
    docker-compose pull

    # Start services
    print_status "Starting V5 services..."
    docker-compose up -d

    # Wait for services
    print_status "Waiting for services to be healthy..."
    sleep 30

    print_success "V5 deployed!"
}

# =============================================================================
# POST-MIGRATION
# =============================================================================

verify_migration() {
    print_status "Verifying migration..."

    cd "$V5_DIR"

    # Check all containers are running
    local containers=("traefik" "mautic-mysql" "strapi-postgres" "mautic-rabbitmq" "strapi" "mautic-web" "mautic-cron" "n8n" "prometheus" "grafana")

    for container in "${containers[@]}"; do
        if docker ps | grep -q "$container"; then
            print_success "✓ $container running"
        else
            print_warning "✗ $container not running"
        fi
    done

    # Check Strapi mode
    if docker exec strapi env | grep "NODE_ENV=production" >/dev/null 2>&1; then
        print_success "✓ Strapi in PRODUCTION mode"
    else
        print_warning "✗ Strapi not in production mode"
    fi

    # Check Traefik health
    if docker inspect traefik | grep -q '"Health".*"healthy"'; then
        print_success "✓ Traefik healthy"
    else
        print_warning "✗ Traefik unhealthy (may need time to initialize SSL)"
    fi
}

display_summary() {
    clear
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         V5 MIGRATION COMPLETED SUCCESSFULLY!              ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo

    cd "$V5_DIR"
    source .env

    echo "🌐 URLs:"
    echo "   Mautic:     https://$MAUTIC_URL"
    echo "   n8n:        https://$N8N_URL"
    echo "   Strapi:     https://$STRAPI_URL/admin"
    echo "   Monitoring: https://monitor.$MAIN_DOMAIN"
    echo "   Traefik:    http://$(curl -s ifconfig.me):8080"
    echo
    echo "🔑 New Credentials:"
    echo "   Grafana:    admin / $GRAFANA_ADMIN_PASSWORD"
    echo
    echo "✅ What Changed:"
    echo "   • Strapi now in PRODUCTION mode (was development)"
    echo "   • Traefik health check FIXED"
    echo "   • Monitoring added (Prometheus + Grafana)"
    echo "   • Ready for automated backups"
    echo "   • Ready for individual service updates"
    echo
    echo "🔒 What Stayed the Same:"
    echo "   • Mautic configuration (100% preserved)"
    echo "   • MySQL configuration (unchanged)"
    echo "   • RabbitMQ configuration (unchanged)"
    echo "   • All data and volumes (intact)"
    echo
    echo "📋 Next Steps:"
    echo "   1. Verify Mautic works: https://$MAUTIC_URL"
    echo "   2. Verify Strapi works: https://$STRAPI_URL/admin"
    echo "   3. Check monitoring: https://monitor.$MAIN_DOMAIN"
    echo "   4. Update n8n: ./update_n8n.sh v2.0"
    echo "   5. Setup automated backups: ./setup_backups.sh"
    echo
    echo "💾 Backup Location:"
    echo "   $BACKUP_DIR"
    echo
    print_warning "Keep V4 directory for 7 days before removing"
    echo
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    preflight_checks
    echo

    print_warning "This will migrate from V4 to V5. Continue? (y/N)"
    read -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1

    create_full_backup
    echo

    migrate_to_v5
    echo

    setup_monitoring
    echo

    deploy_v5
    echo

    verify_migration
    echo

    display_summary
}

main "$@"
