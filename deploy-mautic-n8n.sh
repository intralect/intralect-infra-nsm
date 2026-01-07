#!/bin/bash

# Production Mautic + n8n Docker Stack Deployment Script
# Version: 1.0
# Compatible with Ubuntu 20.04+ and KVM hosting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/mautic-n8n-stack"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/.env"
BACKUP_CREDENTIALS_FILE="$PROJECT_DIR/.env.backup"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}[DEPLOY]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. For security, consider using a non-root user with sudo privileges."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Check if this is a fresh installation or existing deployment
check_deployment_state() {
    if [[ -f "$COMPOSE_FILE" ]] && docker-compose -f "$COMPOSE_FILE" ps -q &> /dev/null; then
        return 0  # Existing deployment
    else
        return 1  # Fresh installation needed
    fi
}

# Generate secure random password
generate_password() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Check DNS propagation
check_dns() {
    local domain=$1
    local expected_ip=$2
    local resolved_ip=$(dig +short "$domain" | tail -n1)
    
    if [[ "$resolved_ip" == "$expected_ip" ]]; then
        return 0
    else
        return 1
    fi
}

# Update system packages
update_system() {
    print_status "Updating system packages..."
    
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get upgrade -y -qq
        sudo apt-get install -y -qq curl wget git unzip ca-certificates gnupg lsb-release jq openssl ufw fail2ban
    else
        print_error "This script requires Ubuntu/Debian. Unsupported system detected."
        exit 1
    fi
    
    print_success "System packages updated"
}

# Configure firewall
setup_firewall() {
    print_status "Configuring UFW firewall..."

    sudo ufw --force reset > /dev/null 2>&1
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 3100/tcp comment 'n8n MCP Server'
    sudo ufw --force enable > /dev/null 2>&1

    print_success "Firewall configured (ports 22, 80, 443, 3100 open)"
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        print_success "Docker is already installed"
        return 0
    fi

    print_status "Installing Docker..."
    
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh
    
    # Add current user to docker group (if not root)
    if [[ $EUID -ne 0 ]]; then
        sudo usermod -aG docker $USER
        print_warning "Added to docker group. Please run 'newgrp docker' or logout/login"
    fi
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    print_success "Docker installed successfully"
}

# Install Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose is already installed"
        return 0
    fi

    print_status "Installing Docker Compose..."
    
    # Get latest version
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name 2>/dev/null || echo "v2.20.0")
    
    # Download and install
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 2>/dev/null
    sudo chmod +x /usr/local/bin/docker-compose
    
    print_success "Docker Compose installed successfully"
}

# Configure automatic security updates
setup_auto_updates() {
    print_status "Configuring automatic security updates..."
    
    sudo apt-get install -y -qq unattended-upgrades
    
    # Enable automatic security updates
    echo 'Unattended-Upgrade::Automatic-Reboot "false";' | sudo tee /etc/apt/apt.conf.d/50unattended-upgrades-custom > /dev/null
    echo 'Unattended-Upgrade::Remove-Unused-Dependencies "true";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades-custom > /dev/null
    
    sudo systemctl enable unattended-upgrades
    
    print_success "Automatic security updates configured"
}

# Get server IP address
get_server_ip() {
    local ip=$(curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s icanhazip.com 2>/dev/null)
    echo "$ip"
}

# Get configuration from user
get_configuration() {
    print_header "Configuration Setup"
    echo
    
    # Get server IP
    SERVER_IP=$(get_server_ip)
    if [[ -z "$SERVER_IP" ]]; then
        print_error "Could not detect server IP address. Please check internet connection."
        exit 1
    fi
    print_status "Detected server IP: $SERVER_IP"
    echo
    
    # Domain configuration
    while true; do
        read -p "Enter your main domain (e.g., example.com): " MAIN_DOMAIN
        if [[ -n "$MAIN_DOMAIN" ]] && [[ "$MAIN_DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            print_error "Invalid domain format. Please enter a valid domain."
        fi
    done
    
    read -p "Enter subdomain for Mautic (default: m): " MAUTIC_SUBDOMAIN
    read -p "Enter subdomain for n8n (default: n8n): " N8N_SUBDOMAIN
    
    MAUTIC_SUBDOMAIN=${MAUTIC_SUBDOMAIN:-m}
    N8N_SUBDOMAIN=${N8N_SUBDOMAIN:-n8n}
    
    MAUTIC_URL="${MAUTIC_SUBDOMAIN}.${MAIN_DOMAIN}"
    N8N_URL="${N8N_SUBDOMAIN}.${MAIN_DOMAIN}"
    
    echo
    print_warning "DNS SETUP REQUIRED"
    echo "----------------------------------------"
    echo "Create these A records pointing to: $SERVER_IP"
    echo "  $MAUTIC_URL"
    echo "  $N8N_URL"
    echo "----------------------------------------"
    echo
    
    # Check if user wants to proceed with DNS check
    read -p "Have you created the DNS A records? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Please create the DNS records first, then run this script again."
        exit 1
    fi
    
    # Check DNS propagation
    print_status "Checking DNS propagation..."
    
    local dns_checks=0
    local max_checks=10
    
    while [[ $dns_checks -lt $max_checks ]]; do
        if check_dns "$MAUTIC_URL" "$SERVER_IP" && check_dns "$N8N_URL" "$SERVER_IP"; then
            print_success "DNS propagation confirmed!"
            break
        else
            dns_checks=$((dns_checks + 1))
            if [[ $dns_checks -lt $max_checks ]]; then
                print_warning "DNS not propagated yet. Retrying in 30 seconds... ($dns_checks/$max_checks)"
                sleep 30
            else
                print_error "DNS propagation failed after $max_checks attempts."
                print_error "Please verify your DNS records and try again later."
                exit 1
            fi
        fi
    done
    
    # Generate passwords
    print_status "Generating secure passwords..."
    
    MYSQL_ROOT_PASSWORD=$(generate_password 32)
    MAUTIC_DB_PASSWORD=$(generate_password 32)
    RABBITMQ_PASSWORD=$(generate_password 24)
    N8N_ENCRYPTION_KEY=$(generate_password 64)
    
    # SMTP configuration (optional)
    echo
    print_status "SMTP Configuration (Optional - can configure AWS SES later)"
    read -p "Enter SMTP host (press Enter to skip): " SMTP_HOST
    
    if [[ -n "$SMTP_HOST" ]]; then
        read -p "Enter SMTP port (default: 587): " SMTP_PORT
        read -p "Enter SMTP username: " SMTP_USER
        read -p "Enter SMTP password: " -s SMTP_PASSWORD
        echo
        SMTP_PORT=${SMTP_PORT:-587}
    fi
    
    print_success "Configuration completed"
}

# Create directory structure
create_directories() {
    print_status "Creating project structure..."
    
    mkdir -p "$PROJECT_DIR"/{backups,logs}
    cd "$PROJECT_DIR"
    
    print_success "Project directories created"
}

# Create environment file
create_env_file() {
    print_status "Creating environment configuration..."
    
    cat > "$ENV_FILE" << EOF
# Domain Configuration
MAIN_DOMAIN=$MAIN_DOMAIN
MAUTIC_URL=$MAUTIC_URL
N8N_URL=$N8N_URL
SERVER_IP=$SERVER_IP

# Database Configuration
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MAUTIC_DB_PASSWORD=$MAUTIC_DB_PASSWORD
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD

# n8n Configuration
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY

# SMTP Configuration (Optional)
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASSWORD

# Timezone
TZ=UTC
EOF
    
    chmod 600 "$ENV_FILE"
    print_success "Environment file created securely"
}

# Create Docker Compose file
create_docker_compose() {
    print_status "Creating Docker Compose configuration..."
    
    cat > "$COMPOSE_FILE" << 'EOF'
version: '3.8'

networks:
  mautic_network:
    driver: bridge

volumes:
  traefik_data:
  mautic_data_cron:
  qdrant_data:
  mautic_data_vendor:
  mysql_data:
  n8n_data:
  mautic_data_media_files:
  rabbitmq_data:
  mautic_data_media_images:
  mautic_data_plugins:
  mautic_data_cache:
  mautic_data_bin:
  mautic_data_spool:
  mautic_data_config:
  mautic_data_logs:

services:
  # Reverse Proxy & SSL
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
      - --certificatesresolvers.letsencrypt.acme.email=admin@${MAIN_DOMAIN}
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
      - --entrypoints.web.http.redirections.entrypoint.to=websecure
      - --entrypoints.web.http.redirections.entrypoint.scheme=https
      - --log.level=INFO
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
      test: ["CMD", "traefik", "healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Database
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
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Message Queue
  rabbitmq:
    image: rabbitmq:3.12-management-alpine
    container_name: mautic-rabbitmq
    restart: unless-stopped
    environment:
      RABBITMQ_DEFAULT_USER: mautic
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD}
      RABBITMQ_VM_MEMORY_HIGH_WATERMARK: 0.8
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - mautic_network
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

  # PDF Generation Service
  gotenberg:
    image: gotenberg/gotenberg:7
    container_name: mautic-gotenberg
    restart: unless-stopped
    command:
      - "gotenberg"
      - "--chromium-disable-web-security"
      - "--chromium-allow-list=file:///*"
    networks:
      - mautic_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Vector Database
  qdrant:
    image: qdrant/qdrant:latest
    container_name: mautic-qdrant
    restart: unless-stopped
    volumes:
      - qdrant_data:/qdrant/storage
    networks:
      - mautic_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6333/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Mautic Web Application
  mautic_web:
    image: mautic/mautic:v5-apache
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
      - MAUTIC_TRUSTED_PROXIES=0.0.0.0/0
      - MAUTIC_CORS_VALID_ORIGINS=^https?://.*$
      - MAUTIC_MESSENGER_TRANSPORT_DSN=amqp://mautic:${RABBITMQ_PASSWORD}@rabbitmq:5672/%2f/messages
      - DOCKER_MAUTIC_LOAD_TEST_DATA=false
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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 60s
      timeout: 30s
      retries: 3
      start_period: 120s

  # Mautic Cron Worker
  mautic_cron:
    image: mautic/mautic:v5-apache
    container_name: mautic-cron
    restart: unless-stopped
    depends_on:
      mysql:
        condition: service_healthy
      mautic_web:
        condition: service_started
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
    command: |
      sh -c "
      while true; do
        echo '[$(date)] Running Mautic cron jobs...'
        php /var/www/html/bin/console mautic:segments:update --batch-limit=300 --quiet
        php /var/www/html/bin/console mautic:campaigns:update --batch-limit=100 --quiet
        php /var/www/html/bin/console mautic:campaigns:trigger --batch-limit=100 --quiet
        php /var/www/html/bin/console mautic:emails:send --batch-limit=100 --quiet
        sleep 60
      done
      "
    networks:
      - mautic_network

  # n8n Workflow Automation (MCP Server Ready)
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - N8N_HOST=${N8N_URL}
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${N8N_URL}
      - GENERIC_TIMEZONE=${TZ}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - DB_TYPE=sqlite
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
      - N8N_TEMPLATES_ENABLED=true
      - N8N_ONBOARDING_FLOW_DISABLED=true
      # === MCP SERVER CONFIGURATION ===
      - N8N_MCP_ENABLED=true
      - N8N_MCP_SERVER_PORT=3100
      - N8N_AI_ENABLED=true
      - N8N_AI_OPENAI_API_KEY=${OPENAI_API_KEY}
      # === WORKFLOW API VARIABLES ===
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - PERPLEXITY_API_KEY=${PERPLEXITY_API_KEY}
      - TWILIO_ACCOUNT_SID=${TWILIO_ACCOUNT_SID}
      - TWILIO_WHATSAPP_NUMBER=${TWILIO_WHATSAPP_NUMBER}
      - SES_FROM_EMAIL=${SES_FROM_EMAIL}
      - COUNSELOR_EMAIL=${COUNSELOR_EMAIL}
      - ADMIN_EMAIL=${ADMIN_EMAIL}
      - VERIFICATION_EMAIL=${VERIFICATION_EMAIL}
      - GOOGLE_SHEETS_ID=${GOOGLE_SHEETS_ID}
      - FACEBOOK_PAGE_ID=${FACEBOOK_PAGE_ID}
      - FACEBOOK_ACCESS_TOKEN=${FACEBOOK_ACCESS_TOKEN}
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
      - REDIS_URL=${REDIS_URL}

    ports:
      - "3100:3100"  # MCP Server Port
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
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
    
    print_success "Docker Compose configuration created"
}

# Deploy the stack
deploy_stack() {
    print_status "Pulling Docker images..."
    docker-compose pull
    
    print_status "Starting services..."
    docker-compose up -d
    
    print_status "Waiting for services to be healthy..."
    sleep 30
    
    # Check service health
    local max_attempts=20
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker-compose ps | grep -q "Up (healthy)"; then
            print_success "Services are running and healthy!"
            break
        else
            print_status "Waiting for services to start... ($attempt/$max_attempts)"
            sleep 15
            attempt=$((attempt + 1))
        fi
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        print_warning "Some services may still be starting. Check status with: docker-compose ps"
    fi
}

# Display deployment information
display_deployment_info() {
    clear
    echo
    print_success "=== DEPLOYMENT COMPLETED SUCCESSFULLY ==="
    echo
    echo "🌐 Access URLs:"
    echo "   Mautic:    https://$MAUTIC_URL"
    echo "   n8n:       https://$N8N_URL"
    echo "   Traefik:   http://$SERVER_IP:8080"
    echo
    echo "🔐 Generated Passwords (SAVE THESE SECURELY):"
    echo "   MySQL Root:      $MYSQL_ROOT_PASSWORD"
    echo "   Mautic DB:       $MAUTIC_DB_PASSWORD"
    echo "   RabbitMQ:        $RABBITMQ_PASSWORD"
    echo "   n8n Encryption:  $N8N_ENCRYPTION_KEY"
    echo
    echo "📧 Email Configuration:"
    if [[ -n "$SMTP_HOST" ]]; then
        echo "   SMTP configured - update settings in Mautic admin panel"
    else
        echo "   Configure AWS SES in Mautic: Settings > Configuration > Email Settings"
    fi
    echo
    echo "🔧 Management:"
    echo "   Run this script again to access management options"
    echo "   All credentials saved in: $ENV_FILE"
    echo
    echo "📋 Next Steps:"
    echo "   1. Wait 2-3 minutes for SSL certificates"
    echo "   2. Access Mautic and complete setup wizard"
    echo "   3. Configure AWS SES for email sending"
    echo "   4. Set up your first n8n workflow"
    echo
    print_warning "Save the passwords above - they won't be displayed again!"
}

# Management menu functions
show_status() {
    clear
    print_header "Service Status"
    echo
    
    cd "$PROJECT_DIR"
    docker-compose ps
    echo
    
    print_status "Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $(docker-compose ps -q) 2>/dev/null || echo "No containers running"
    echo
    
    print_status "Disk Usage:"
    df -h / | tail -1
    echo
    
    read -p "Press Enter to continue..."
}

start_services() {
    print_status "Starting all services..."
    cd "$PROJECT_DIR"
    docker-compose up -d
    print_success "Services started"
    sleep 2
}

stop_services() {
    print_status "Stopping all services..."
    cd "$PROJECT_DIR"
    docker-compose down
    print_success "Services stopped"
    sleep 2
}

restart_services() {
    print_status "Restarting all services..."
    cd "$PROJECT_DIR"
    docker-compose restart
    print_success "Services restarted"
    sleep 2
}

view_logs() {
    clear
    print_header "Service Logs"
    echo

    cd "$PROJECT_DIR"
    echo "Available services:"
    docker-compose ps --services
    echo

    read -p "Enter service name (or 'all' for all services): " service_name

    if [[ "$service_name" == "all" ]]; then
        docker-compose logs --tail=100 -f
    else
        docker-compose logs --tail=100 -f "$service_name"
    fi
}

# Load or configure backup credentials
setup_backup_credentials() {
    if [[ -f "$BACKUP_CREDENTIALS_FILE" ]]; then
        source "$BACKUP_CREDENTIALS_FILE"
        return 0
    fi

    clear
    print_header "AWS S3 Backup Configuration"
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

    # Save credentials securely
    cat > "$BACKUP_CREDENTIALS_FILE" << EOF
# AWS S3 Backup Configuration
# Created: $(date)
AWS_S3_BUCKET="$AWS_S3_BUCKET"
AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
LOCAL_BACKUP_RETENTION=$LOCAL_BACKUP_RETENTION
EOF

    chmod 600 "$BACKUP_CREDENTIALS_FILE"
    print_success "Backup credentials saved securely to $BACKUP_CREDENTIALS_FILE"
    echo

    # Source the file
    source "$BACKUP_CREDENTIALS_FILE"
}

create_backup() {
    # Call enhanced backup script with S3 support
    "$SCRIPT_DIR/backup-to-s3.sh"

    # Return to menu
    echo
    read -p "Press Enter to return to menu..."
}

update_images() {
    print_status "Updating Docker images..."
    cd "$PROJECT_DIR"
    
    docker-compose pull
    docker-compose up -d
    
    # Clean up old images
    print_status "Cleaning up old images..."
    docker image prune -f
    
    print_success "Images updated successfully"
    read -p "Press Enter to continue..."
}

# Management menu
show_management_menu() {
    while true; do
        clear
        print_header "Mautic + n8n Stack Management"
        echo
        echo "Current status: $(cd "$PROJECT_DIR" && docker-compose ps --services | wc -l) services configured"
        echo
        echo "1. Show Status & Resource Usage"
        echo "2. Start Services"
        echo "3. Stop Services" 
        echo "4. Restart Services"
        echo "5. View Logs"
        echo "6. Create Backup"
        echo "7. Update Images"
        echo "8. Show Access URLs & Passwords"
        echo "9. Exit"
        echo
        
        read -p "Choose an option (1-9): " choice
        
        case $choice in
            1) show_status ;;
            2) start_services ;;
            3) stop_services ;;
            4) restart_services ;;
            5) view_logs ;;
            6) create_backup ;;
            7) update_images ;;
            8) 
                clear
                if [[ -f "$ENV_FILE" ]]; then
                    source "$ENV_FILE"
                    echo "Access URLs:"
                    echo "   Mautic:    https://$MAUTIC_URL"
                    echo "   n8n:       https://$N8N_URL"
                    echo "   Traefik:   http://$SERVER_IP:8080"
                    echo
                    echo "Passwords:"
                    echo "   MySQL Root:      $MYSQL_ROOT_PASSWORD"
                    echo "   Mautic DB:       $MAUTIC_DB_PASSWORD"
                    echo "   RabbitMQ:        $RABBITMQ_PASSWORD"
                    echo "   n8n Encryption:  $N8N_ENCRYPTION_KEY"
                else
                    print_error "Environment file not found"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            9) 
                print_success "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-9."
                sleep 1
                ;;
        esac
    done
}

# Main installation function
run_installation() {
    clear
    print_header "Mautic + n8n Production Stack Installer"
    echo
    print_status "This script will install a complete Mautic + n8n stack with:"
    echo "  • Traefik (Reverse proxy with SSL)"
    echo "  • MySQL (Database)"
    echo "  • RabbitMQ (Message queue)"
    echo "  • Mautic (Marketing automation)"
    echo "  • n8n (Workflow automation)"
    echo "  • Gotenberg (PDF generation)"
    echo "  • Qdrant (Vector database)"
    echo
    
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Installation cancelled"
        exit 1
    fi
    
    # Run installation steps
    check_root
    update_system
    setup_firewall
    install_docker
    install_docker_compose
    setup_auto_updates
    get_configuration
    create_directories
    create_env_file
    create_docker_compose
    deploy_stack
    display_deployment_info
}

# Main function
main() {
    # Check if this is an existing deployment
    if check_deployment_state; then
        # Load environment variables
        if [[ -f "$ENV_FILE" ]]; then
            source "$ENV_FILE"
        fi
        show_management_menu
    else
        # Fresh installation
        run_installation
    fi
}

# Cleanup function for interrupts
cleanup() {
    print_warning "Installation interrupted"
    if [[ -d "$PROJECT_DIR" ]]; then
        print_status "Cleaning up partial installation..."
        cd "$PROJECT_DIR" && docker-compose down 2>/dev/null || true
    fi
    exit 1
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Run main function
main "$@"
