#!/bin/bash

# Production Mautic + n8n + Strapi Docker Stack Deployment Script
# Version: 3.0
# Based on V2 structure - adds Strapi CMS + S3 Backup
# Safely upgrades existing V2 deployments
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
S3_CONFIG_FILE="$PROJECT_DIR/.s3-config"
STRAPI_DIR="$PROJECT_DIR/strapi"

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

# Check if Strapi is already installed
check_strapi_installed() {
    if [[ -d "$STRAPI_DIR" ]] && [[ -f "$STRAPI_DIR/package.json" ]]; then
        return 0  # Strapi exists
    else
        return 1  # Strapi not installed
    fi
}

# Check if S3 is configured
check_s3_configured() {
    if [[ -f "$S3_CONFIG_FILE" ]]; then
        return 0
    else
        return 1
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

# Install AWS CLI
install_awscli() {
    if command -v aws &> /dev/null; then
        print_success "AWS CLI is already installed"
        return 0
    fi
    
    print_status "Installing AWS CLI..."
    sudo apt-get install -y -qq awscli
    print_success "AWS CLI installed"
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
    sudo ufw --force enable > /dev/null 2>&1
    
    print_success "Firewall configured (ports 22, 80, 443 open)"
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

# Get configuration from user (Fresh Install)
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
        read -p "Enter your main domain (e.g., yaicos.com): " MAIN_DOMAIN
        if [[ -n "$MAIN_DOMAIN" ]] && [[ "$MAIN_DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            print_error "Invalid domain format. Please enter a valid domain."
        fi
    done
    
    read -p "Enter subdomain for Mautic (default: m): " MAUTIC_SUBDOMAIN
    read -p "Enter subdomain for n8n (default: n8n): " N8N_SUBDOMAIN
    read -p "Enter subdomain for Strapi CMS (default: cms): " STRAPI_SUBDOMAIN
    
    MAUTIC_SUBDOMAIN=${MAUTIC_SUBDOMAIN:-m}
    N8N_SUBDOMAIN=${N8N_SUBDOMAIN:-n8n}
    STRAPI_SUBDOMAIN=${STRAPI_SUBDOMAIN:-cms}
    
    MAUTIC_URL="${MAUTIC_SUBDOMAIN}.${MAIN_DOMAIN}"
    N8N_URL="${N8N_SUBDOMAIN}.${MAIN_DOMAIN}"
    STRAPI_URL="${STRAPI_SUBDOMAIN}.${MAIN_DOMAIN}"
    
    # Blog domains for CORS
    echo
    print_status "Blog Domains Configuration (for Strapi CORS)"
    read -p "Enter blog domain 1 (e.g., guardscan.io): " BLOG_DOMAIN_1
    read -p "Enter blog domain 2 (e.g., yaicos.com): " BLOG_DOMAIN_2
    read -p "Enter blog domain 3 (press Enter to skip): " BLOG_DOMAIN_3
    
    BLOG_DOMAIN_1=${BLOG_DOMAIN_1:-"localhost"}
    BLOG_DOMAIN_2=${BLOG_DOMAIN_2:-"localhost"}
    BLOG_DOMAIN_3=${BLOG_DOMAIN_3:-""}
    
    echo
    print_warning "DNS SETUP REQUIRED (Cloudflare)"
    echo "----------------------------------------"
    echo "Create these A records pointing to: $SERVER_IP"
    echo "  $MAUTIC_URL"
    echo "  $N8N_URL"
    echo "  $STRAPI_URL"
    echo "----------------------------------------"
    echo
    
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
        if check_dns "$MAUTIC_URL" "$SERVER_IP" && check_dns "$N8N_URL" "$SERVER_IP" && check_dns "$STRAPI_URL" "$SERVER_IP"; then
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
    
    # Strapi passwords
    POSTGRES_PASSWORD=$(generate_password 32)
    STRAPI_APP_KEYS="$(generate_password 24),$(generate_password 24)"
    STRAPI_API_TOKEN_SALT=$(generate_password 24)
    STRAPI_ADMIN_JWT_SECRET=$(generate_password 24)
    STRAPI_JWT_SECRET=$(generate_password 24)
    STRAPI_TRANSFER_TOKEN_SALT=$(generate_password 24)
    
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

# Get Strapi configuration for upgrade
get_strapi_configuration() {
    print_header "Strapi Configuration"
    echo
    
    # Load existing env
    source "$ENV_FILE"
    
    SERVER_IP=$(get_server_ip)
    
    read -p "Enter subdomain for Strapi CMS (default: cms): " STRAPI_SUBDOMAIN
    STRAPI_SUBDOMAIN=${STRAPI_SUBDOMAIN:-cms}
    STRAPI_URL="${STRAPI_SUBDOMAIN}.${MAIN_DOMAIN}"
    
    # Blog domains for CORS
    echo
    print_status "Blog Domains Configuration (for Strapi CORS)"
    read -p "Enter blog domain 1 (e.g., guardscan.io): " BLOG_DOMAIN_1
    read -p "Enter blog domain 2 (e.g., yaicos.com): " BLOG_DOMAIN_2
    read -p "Enter blog domain 3 (press Enter to skip): " BLOG_DOMAIN_3
    
    BLOG_DOMAIN_1=${BLOG_DOMAIN_1:-"localhost"}
    BLOG_DOMAIN_2=${BLOG_DOMAIN_2:-"localhost"}
    BLOG_DOMAIN_3=${BLOG_DOMAIN_3:-""}
    
    echo
    print_warning "DNS SETUP REQUIRED (Cloudflare)"
    echo "----------------------------------------"
    echo "Add this A record pointing to: $SERVER_IP"
    echo "  $STRAPI_URL"
    echo "----------------------------------------"
    echo
    
    read -p "Have you created the DNS A record for Strapi? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Please create the DNS record first, then run this script again."
        return 1
    fi
    
    # Check DNS
    print_status "Checking DNS propagation for $STRAPI_URL..."
    local dns_checks=0
    local max_checks=5
    
    while [[ $dns_checks -lt $max_checks ]]; do
        if check_dns "$STRAPI_URL" "$SERVER_IP"; then
            print_success "DNS propagation confirmed!"
            break
        else
            dns_checks=$((dns_checks + 1))
            if [[ $dns_checks -lt $max_checks ]]; then
                print_warning "DNS not propagated yet. Retrying in 20 seconds... ($dns_checks/$max_checks)"
                sleep 20
            else
                print_warning "DNS not fully propagated. Continuing anyway (Cloudflare may proxy)..."
            fi
        fi
    done
    
    # Generate Strapi passwords
    print_status "Generating Strapi credentials..."
    POSTGRES_PASSWORD=$(generate_password 32)
    STRAPI_APP_KEYS="$(generate_password 24),$(generate_password 24)"
    STRAPI_API_TOKEN_SALT=$(generate_password 24)
    STRAPI_ADMIN_JWT_SECRET=$(generate_password 24)
    STRAPI_JWT_SECRET=$(generate_password 24)
    STRAPI_TRANSFER_TOKEN_SALT=$(generate_password 24)
    
    print_success "Strapi configuration completed"
    return 0
}

# Create directory structure
create_directories() {
    print_status "Creating project structure..."
    
    mkdir -p "$PROJECT_DIR"/{backups,logs}
    mkdir -p "$STRAPI_DIR"
    cd "$PROJECT_DIR"
    
    print_success "Project directories created"
}

# Create environment file
create_env_file() {
    print_status "Creating environment configuration..."
    
    cat > "$ENV_FILE" << EOF
# ===========================================
# Domain Configuration
# ===========================================
MAIN_DOMAIN=$MAIN_DOMAIN
MAUTIC_URL=$MAUTIC_URL
N8N_URL=$N8N_URL
STRAPI_URL=$STRAPI_URL
SERVER_IP=$SERVER_IP

# ===========================================
# Blog Domains (Strapi CORS)
# ===========================================
BLOG_DOMAIN_1=$BLOG_DOMAIN_1
BLOG_DOMAIN_2=$BLOG_DOMAIN_2
BLOG_DOMAIN_3=$BLOG_DOMAIN_3

# ===========================================
# MySQL Database (Mautic)
# ===========================================
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MAUTIC_DB_PASSWORD=$MAUTIC_DB_PASSWORD

# ===========================================
# PostgreSQL Database (Strapi)
# ===========================================
POSTGRES_USER=strapi
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=strapi

# ===========================================
# Strapi Configuration
# ===========================================
STRAPI_APP_KEYS=$STRAPI_APP_KEYS
STRAPI_API_TOKEN_SALT=$STRAPI_API_TOKEN_SALT
STRAPI_ADMIN_JWT_SECRET=$STRAPI_ADMIN_JWT_SECRET
STRAPI_JWT_SECRET=$STRAPI_JWT_SECRET
STRAPI_TRANSFER_TOKEN_SALT=$STRAPI_TRANSFER_TOKEN_SALT

# ===========================================
# RabbitMQ (Mautic)
# ===========================================
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD

# ===========================================
# n8n Configuration
# ===========================================
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
N8N_WEBHOOK_BASE_URL=https://${N8N_URL}

# ===========================================
# SMTP Configuration (Optional)
# ===========================================
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASSWORD

# ===========================================
# Timezone
# ===========================================
TZ=UTC
EOF
    
    chmod 600 "$ENV_FILE"
    print_success "Environment file created securely"
}

# Append Strapi config to existing env file
append_strapi_to_env() {
    print_status "Adding Strapi configuration to environment..."
    
    # Check if Strapi vars already exist
    if grep -q "STRAPI_URL" "$ENV_FILE"; then
        print_warning "Strapi configuration already exists in .env"
        return 0
    fi
    
    cat >> "$ENV_FILE" << EOF

# ===========================================
# Strapi Configuration (Added by V3 upgrade)
# ===========================================
STRAPI_URL=$STRAPI_URL

# Blog Domains (Strapi CORS)
BLOG_DOMAIN_1=$BLOG_DOMAIN_1
BLOG_DOMAIN_2=$BLOG_DOMAIN_2
BLOG_DOMAIN_3=$BLOG_DOMAIN_3

# PostgreSQL Database (Strapi)
POSTGRES_USER=strapi
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=strapi

# Strapi Secrets
STRAPI_APP_KEYS=$STRAPI_APP_KEYS
STRAPI_API_TOKEN_SALT=$STRAPI_API_TOKEN_SALT
STRAPI_ADMIN_JWT_SECRET=$STRAPI_ADMIN_JWT_SECRET
STRAPI_JWT_SECRET=$STRAPI_JWT_SECRET
STRAPI_TRANSFER_TOKEN_SALT=$STRAPI_TRANSFER_TOKEN_SALT
EOF
    
    print_success "Strapi configuration added to environment"
}

# Create Strapi project structure
create_strapi_project() {
    print_status "Creating Strapi project structure..."
    
    mkdir -p "$STRAPI_DIR"/{config,src/api,public/uploads,database}
    
    # Load environment for variable substitution
    source "$ENV_FILE" 2>/dev/null || true
    
    # Create package.json
    cat > "$STRAPI_DIR/package.json" << 'EOF'
{
  "name": "strapi-cms",
  "private": true,
  "version": "1.0.0",
  "description": "Multi-blog CMS",
  "scripts": {
    "develop": "strapi develop",
    "start": "strapi start",
    "build": "strapi build",
    "strapi": "strapi"
  },
  "dependencies": {
    "@strapi/strapi": "^4.25.0",
    "@strapi/plugin-users-permissions": "^4.25.0",
    "@strapi/plugin-i18n": "^4.25.0",
    "pg": "^8.11.0"
  },
  "engines": {
    "node": ">=18.0.0 <=20.x.x",
    "npm": ">=6.0.0"
  }
}
EOF
    
    # Create database.js config
    cat > "$STRAPI_DIR/config/database.js" << 'EOF'
module.exports = ({ env }) => ({
  connection: {
    client: 'postgres',
    connection: {
      host: env('DATABASE_HOST', 'postgres'),
      port: env.int('DATABASE_PORT', 5432),
      database: env('DATABASE_NAME', 'strapi'),
      user: env('DATABASE_USERNAME', 'strapi'),
      password: env('DATABASE_PASSWORD', ''),
      ssl: env.bool('DATABASE_SSL', false),
    },
    debug: false,
  },
});
EOF
    
    # Create server.js config
    cat > "$STRAPI_DIR/config/server.js" << 'EOF'
module.exports = ({ env }) => ({
  host: env('HOST', '0.0.0.0'),
  port: env.int('PORT', 1337),
  url: env('PUBLIC_URL', 'http://localhost:1337'),
  app: {
    keys: env.array('APP_KEYS'),
  },
  webhooks: {
    populateRelations: env.bool('WEBHOOKS_POPULATE_RELATIONS', false),
  },
});
EOF
    
    # Create admin.js config
    cat > "$STRAPI_DIR/config/admin.js" << 'EOF'
module.exports = ({ env }) => ({
  auth: {
    secret: env('ADMIN_JWT_SECRET'),
  },
  apiToken: {
    salt: env('API_TOKEN_SALT'),
  },
  transfer: {
    token: {
      salt: env('TRANSFER_TOKEN_SALT'),
    },
  },
  flags: {
    nps: env.bool('FLAG_NPS', true),
    promoteEE: env.bool('FLAG_PROMOTE_EE', true),
  },
});
EOF
    
    # Create middlewares.js with CORS config
    local cors_origins="'http://localhost:3000', 'http://localhost:5173'"
    [[ -n "$BLOG_DOMAIN_1" ]] && cors_origins="$cors_origins, 'https://$BLOG_DOMAIN_1'"
    [[ -n "$BLOG_DOMAIN_2" ]] && cors_origins="$cors_origins, 'https://$BLOG_DOMAIN_2'"
    [[ -n "$BLOG_DOMAIN_3" ]] && cors_origins="$cors_origins, 'https://$BLOG_DOMAIN_3'"
    [[ -n "$STRAPI_URL" ]] && cors_origins="$cors_origins, 'https://$STRAPI_URL'"
    
    cat > "$STRAPI_DIR/config/middlewares.js" << EOF
module.exports = [
  'strapi::logger',
  'strapi::errors',
  {
    name: 'strapi::security',
    config: {
      contentSecurityPolicy: {
        useDefaults: true,
        directives: {
          'connect-src': ["'self'", 'https:'],
          'img-src': ["'self'", 'data:', 'blob:', 'https:'],
          'media-src': ["'self'", 'data:', 'blob:', 'https:'],
          upgradeInsecureRequests: null,
        },
      },
    },
  },
  {
    name: 'strapi::cors',
    config: {
      enabled: true,
      origin: [$cors_origins],
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS', 'HEAD'],
      headers: ['Content-Type', 'Authorization', 'Origin', 'Accept'],
      keepHeaderOnError: true,
    },
  },
  'strapi::poweredBy',
  'strapi::query',
  'strapi::body',
  'strapi::session',
  'strapi::favicon',
  'strapi::public',
];
EOF
    
    # Create plugins.js
    cat > "$STRAPI_DIR/config/plugins.js" << 'EOF'
module.exports = ({ env }) => ({
  'users-permissions': {
    config: {
      jwt: {
        expiresIn: '7d',
      },
    },
  },
});
EOF
    
    # Create index.js entry point
    cat > "$STRAPI_DIR/src/index.js" << 'EOF'
'use strict';

module.exports = {
  register(/* { strapi } */) {},
  bootstrap(/* { strapi } */) {},
};
EOF
    
    # Create .gitignore
    cat > "$STRAPI_DIR/.gitignore" << 'EOF'
node_modules/
build/
.strapi/
.cache/
dist/
*.log
.env
EOF
    
    # Set permissions
    chmod -R 755 "$STRAPI_DIR"
    
    print_success "Strapi project structure created"
}

# Create Docker Compose file (Full V3)
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
  postgres_data:

services:
  # ===========================================
  # Reverse Proxy & SSL
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

  # ===========================================
  # MySQL Database (Mautic)
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
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 30s
      timeout: 10s
      retries: 5

  # ===========================================
  # PostgreSQL Database (Strapi)
  # ===========================================
  postgres:
    image: postgres:15-alpine
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
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 30s
      timeout: 10s
      retries: 5

  # ===========================================
  # Message Queue (Mautic)
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
  # Strapi CMS
  # ===========================================
  strapi:
    image: node:18-alpine
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
      PUBLIC_URL: https://${STRAPI_URL}
      APP_KEYS: ${STRAPI_APP_KEYS}
      API_TOKEN_SALT: ${STRAPI_API_TOKEN_SALT}
      ADMIN_JWT_SECRET: ${STRAPI_ADMIN_JWT_SECRET}
      JWT_SECRET: ${STRAPI_JWT_SECRET}
      TRANSFER_TOKEN_SALT: ${STRAPI_TRANSFER_TOKEN_SALT}
      DATABASE_HOST: postgres
      DATABASE_PORT: 5432
      DATABASE_NAME: ${POSTGRES_DB}
      DATABASE_USERNAME: ${POSTGRES_USER}
      DATABASE_PASSWORD: ${POSTGRES_PASSWORD}
      DATABASE_SSL: "false"
    volumes:
      - ./strapi:/srv/app
    entrypoint: /bin/sh
    command:
      - -c
      - |
        if [ ! -d "node_modules" ]; then
          echo "Installing dependencies..."
          npm install --legacy-peer-deps
        fi
        if [ ! -d "build" ]; then
          echo "Building Strapi admin..."
          npm run build
        fi
        echo "Starting Strapi..."
        npm run start
    labels:
      - traefik.enable=true
      - traefik.http.routers.strapi.rule=Host(`${STRAPI_URL}`)
      - traefik.http.routers.strapi.tls=true
      - traefik.http.routers.strapi.tls.certresolver=letsencrypt
      - traefik.http.services.strapi.loadbalancer.server.port=1337
    networks:
      - mautic_network

  # ===========================================
  # Mautic Web Application
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
      - MAUTIC_DB_PORT=3306
      - MAUTIC_DB_DATABASE=mautic
      - MAUTIC_DB_HOST=mysql
      - MAUTIC_DB_USER=mautic
      - MAUTIC_DB_PASSWORD=${MAUTIC_DB_PASSWORD}
      - MAUTIC_DB_NAME=mautic
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

  # ===========================================
  # Mautic Cron Worker
  # ===========================================
  mautic_cron:
    image: mautic/mautic:5-apache
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
        echo '[\$(date)] Running Mautic cron jobs...'
        php /var/www/html/bin/console mautic:segments:update --batch-limit=300 --quiet
        php /var/www/html/bin/console mautic:campaigns:update --batch-limit=100 --quiet
        php /var/www/html/bin/console mautic:campaigns:trigger --batch-limit=100 --quiet
        php /var/www/html/bin/console mautic:emails:send --batch-limit=100 --quiet
        sleep 60
      done
      "
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
      - NODE_ENV=production
      - WEBHOOK_URL=https://${N8N_URL}
      - GENERIC_TIMEZONE=${TZ}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - DB_TYPE=sqlite
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
      - N8N_TEMPLATES_ENABLED=true
      - N8N_ONBOARDING_FLOW_DISABLED=true
      - N8N_BLOCK_ENV_ACCESS_IN_NODE=false
      # Strapi API URL for workflows
      - STRAPI_API_URL=https://${STRAPI_URL}
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
EOF
    
    print_success "Docker Compose configuration created"
}

# Deploy the stack
deploy_stack() {
    print_status "Pulling Docker images..."
    cd "$PROJECT_DIR"
    docker-compose pull
    
    print_status "Starting services..."
    docker-compose up -d
    
    print_status "Waiting for services to be healthy..."
    sleep 30
    
    # Check service health
    local max_attempts=20
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker-compose ps | grep -q "Up"; then
            print_success "Services are running!"
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

# Upgrade existing V2 to V3
upgrade_to_v3() {
    print_header "Upgrading to V3 (Adding Strapi)"
    echo
    
    print_warning "This will:"
    echo "  • Stop and remove Gotenberg container (if exists)"
    echo "  • Stop and remove Qdrant container (if exists)"
    echo "  • Add PostgreSQL for Strapi"
    echo "  • Add Strapi CMS"
    echo "  • Keep all existing services running"
    echo
    
    read -p "Continue with upgrade? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Upgrade cancelled"
        return 1
    fi
    
    # Get Strapi configuration
    if ! get_strapi_configuration; then
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    # Stop and remove old services
    print_status "Removing Gotenberg and Qdrant (if present)..."
    docker-compose stop gotenberg qdrant 2>/dev/null || true
    docker-compose rm -f gotenberg qdrant 2>/dev/null || true
    
    # Remove old volumes
    docker volume rm mautic-n8n-stack_qdrant_data 2>/dev/null || true
    
    # Append Strapi config to env
    append_strapi_to_env
    
    # Create Strapi project
    mkdir -p "$STRAPI_DIR"
    create_strapi_project
    
    # Backup old compose file
    cp "$COMPOSE_FILE" "$COMPOSE_FILE.v2.backup"
    print_status "V2 compose file backed up to: $COMPOSE_FILE.v2.backup"
    
    # Create new compose file
    create_docker_compose
    
    # Deploy new services
    print_status "Starting upgraded stack..."
    docker-compose up -d
    
    print_success "Upgrade to V3 completed!"
    echo
    print_warning "Strapi is building (first run takes 2-5 minutes)..."
    print_status "Check progress with: docker-compose logs -f strapi"
    
    return 0
}

# Display deployment information
display_deployment_info() {
    clear
    echo
    print_success "=== DEPLOYMENT COMPLETED SUCCESSFULLY ==="
    echo
    echo "🌐 Access URLs:"
    echo "   Mautic:     https://$MAUTIC_URL"
    echo "   n8n:        https://$N8N_URL"
    echo "   Strapi:     https://$STRAPI_URL/admin"
    echo "   Traefik:    http://$SERVER_IP:8080"
    echo
    echo "🔐 Generated Passwords (SAVE THESE SECURELY):"
    echo "   MySQL Root:      $MYSQL_ROOT_PASSWORD"
    echo "   Mautic DB:       $MAUTIC_DB_PASSWORD"
    echo "   RabbitMQ:        $RABBITMQ_PASSWORD"
    echo "   n8n Encryption:  $N8N_ENCRYPTION_KEY"
    echo "   PostgreSQL:      $POSTGRES_PASSWORD"
    echo
    echo "📝 Blog Domains (CORS configured):"
    [[ -n "$BLOG_DOMAIN_1" && "$BLOG_DOMAIN_1" != "localhost" ]] && echo "   - https://$BLOG_DOMAIN_1"
    [[ -n "$BLOG_DOMAIN_2" && "$BLOG_DOMAIN_2" != "localhost" ]] && echo "   - https://$BLOG_DOMAIN_2"
    [[ -n "$BLOG_DOMAIN_3" ]] && echo "   - https://$BLOG_DOMAIN_3"
    echo
    echo "📋 Next Steps:"
    echo "   1. Wait 2-5 minutes for Strapi to build (first run)"
    echo "   2. Access Strapi at https://$STRAPI_URL/admin"
    echo "   3. Create admin account (email: info@yaicos.com)"
    echo "   4. Create content types for each blog"
    echo "   5. Generate API tokens for n8n integration"
    echo
    print_warning "Save the passwords above - they won't be displayed again!"
    echo
    read -p "Press Enter to continue to management menu..."
}

# =====================================================
# MANAGEMENT MENU FUNCTIONS
# =====================================================

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

update_images() {
    print_status "Updating Docker images..."
    cd "$PROJECT_DIR"
    
    docker-compose pull
    docker-compose up -d
    
    print_status "Cleaning up old images..."
    docker image prune -f
    
    print_success "Images updated successfully"
    read -p "Press Enter to continue..."
}

# =====================================================
# BACKUP FUNCTIONS
# =====================================================

configure_s3() {
    print_header "AWS S3 Configuration"
    echo
    
    read -p "Enter AWS Access Key ID: " AWS_ACCESS_KEY_ID
    read -s -p "Enter AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    echo
    read -p "Enter S3 Bucket Name: " S3_BUCKET_NAME
    read -p "Enter AWS Region (default: us-east-1): " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    
    echo
    print_status "Select default storage class:"
    echo "  1) STANDARD (Frequent Access)"
    echo "  2) STANDARD_IA (Infrequent Access - Recommended)"
    echo "  3) GLACIER_IR (Instant Retrieval)"
    echo "  4) DEEP_ARCHIVE (Cheapest, 12+ hour retrieval)"
    read -p "Choose (1-4, default: 2): " storage_choice
    
    case $storage_choice in
        1) S3_STORAGE_CLASS="STANDARD" ;;
        3) S3_STORAGE_CLASS="GLACIER_IR" ;;
        4) S3_STORAGE_CLASS="DEEP_ARCHIVE" ;;
        *) S3_STORAGE_CLASS="STANDARD_IA" ;;
    esac
    
    # Save config
    cat > "$S3_CONFIG_FILE" << EOF
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
S3_BUCKET_NAME=$S3_BUCKET_NAME
AWS_REGION=$AWS_REGION
S3_STORAGE_CLASS=$S3_STORAGE_CLASS
EOF
    chmod 600 "$S3_CONFIG_FILE"
    
    # Configure AWS CLI
    aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
    aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
    aws configure set default.region "$AWS_REGION"
    
    print_success "AWS S3 configured successfully"
    read -p "Press Enter to continue..."
}

create_local_backup() {
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local backup_dir="$PROJECT_DIR/backups/$timestamp"
    mkdir -p "$backup_dir"
    
    print_status "Creating backup in $backup_dir..."
    
    cd "$PROJECT_DIR"
    source "$ENV_FILE"
    
    # Backup MySQL
    if docker-compose ps mysql | grep -q Up; then
        print_status "Backing up MySQL (Mautic)..."
        docker-compose exec -T mysql mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases > "$backup_dir/mysql_backup.sql" 2>/dev/null
    fi
    
    # Backup PostgreSQL
    if docker-compose ps postgres | grep -q Up; then
        print_status "Backing up PostgreSQL (Strapi)..."
        docker-compose exec -T postgres pg_dumpall -U strapi > "$backup_dir/postgres_backup.sql" 2>/dev/null
    fi
    
    # Backup config files
    cp "$ENV_FILE" "$backup_dir/"
    cp "$COMPOSE_FILE" "$backup_dir/"
    [[ -f "$S3_CONFIG_FILE" ]] && cp "$S3_CONFIG_FILE" "$backup_dir/"
    
    # Backup Strapi project
    if [[ -d "$STRAPI_DIR" ]]; then
        print_status "Backing up Strapi project..."
        tar czf "$backup_dir/strapi_project.tar.gz" -C "$PROJECT_DIR" strapi --exclude='strapi/node_modules' --exclude='strapi/.cache' --exclude='strapi/build' 2>/dev/null || true
    fi
    
    # Backup volumes
    print_status "Backing up application data..."
    
    docker run --rm -v mautic-n8n-stack_mautic_data_config:/source:ro -v "$backup_dir":/backup alpine tar czf /backup/mautic_config.tar.gz -C /source . 2>/dev/null || true
    docker run --rm -v mautic-n8n-stack_mautic_data_media_images:/source:ro -v "$backup_dir":/backup alpine tar czf /backup/mautic_media.tar.gz -C /source . 2>/dev/null || true
    docker run --rm -v mautic-n8n-stack_n8n_data:/source:ro -v "$backup_dir":/backup alpine tar czf /backup/n8n_data.tar.gz -C /source . 2>/dev/null || true
    
    # Create info file
    cat > "$backup_dir/backup_info.txt" << EOF
Backup created: $(date)
Server IP: $(get_server_ip)
Type: Local
Version: V3
EOF
    
    # Create final archive
    local backup_name="full-backup-$timestamp.tar.gz"
    cd "$PROJECT_DIR/backups"
    tar czf "$backup_name" -C "$timestamp" .
    rm -rf "$timestamp"
    
    print_success "Backup completed: $PROJECT_DIR/backups/$backup_name"
    
    # Cleanup old backups (keep last 5)
    find "$PROJECT_DIR/backups" -maxdepth 1 -name "full-backup-*.tar.gz" -type f | sort | head -n -5 | xargs rm -f 2>/dev/null || true
    
    read -p "Press Enter to continue..."
}

create_s3_backup() {
    if ! check_s3_configured; then
        print_error "AWS S3 not configured. Please configure it first."
        read -p "Press Enter to continue..."
        return
    fi
    
    source "$S3_CONFIG_FILE"
    
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local backup_dir="$PROJECT_DIR/backups/temp_$timestamp"
    mkdir -p "$backup_dir"
    
    print_status "Creating backup for S3 upload..."
    
    cd "$PROJECT_DIR"
    source "$ENV_FILE"
    
    # Backup databases
    if docker-compose ps mysql | grep -q Up; then
        print_status "Backing up MySQL..."
        docker-compose exec -T mysql mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases > "$backup_dir/mysql_backup.sql" 2>/dev/null
    fi
    
    if docker-compose ps postgres | grep -q Up; then
        print_status "Backing up PostgreSQL..."
        docker-compose exec -T postgres pg_dumpall -U strapi > "$backup_dir/postgres_backup.sql" 2>/dev/null
    fi
    
    # Backup configs
    cp "$ENV_FILE" "$backup_dir/"
    cp "$COMPOSE_FILE" "$backup_dir/"
    
    # Backup Strapi
    if [[ -d "$STRAPI_DIR" ]]; then
        tar czf "$backup_dir/strapi_project.tar.gz" -C "$PROJECT_DIR" strapi --exclude='strapi/node_modules' --exclude='strapi/.cache' --exclude='strapi/build' 2>/dev/null || true
    fi
    
    # Backup volumes
    docker run --rm -v mautic-n8n-stack_mautic_data_config:/source:ro -v "$backup_dir":/backup alpine tar czf /backup/mautic_config.tar.gz -C /source . 2>/dev/null || true
    docker run --rm -v mautic-n8n-stack_mautic_data_media_images:/source:ro -v "$backup_dir":/backup alpine tar czf /backup/mautic_media.tar.gz -C /source . 2>/dev/null || true
    docker run --rm -v mautic-n8n-stack_n8n_data:/source:ro -v "$backup_dir":/backup alpine tar czf /backup/n8n_data.tar.gz -C /source . 2>/dev/null || true
    
    # Create archive
    local backup_name="server-backup-$timestamp.tar.gz"
    cd "$PROJECT_DIR/backups"
    tar czf "$backup_name" -C "temp_$timestamp" .
    rm -rf "temp_$timestamp"
    
    # Select storage class
    echo
    print_status "Select S3 storage class:"
    echo "  1) STANDARD"
    echo "  2) STANDARD_IA (Recommended)"
    echo "  3) GLACIER_IR"
    echo "  4) DEEP_ARCHIVE"
    read -p "Choose (1-4, default uses configured): " choice
    
    case $choice in
        1) storage="STANDARD" ;;
        2) storage="STANDARD_IA" ;;
        3) storage="GLACIER_IR" ;;
        4) storage="DEEP_ARCHIVE" ;;
        *) storage="$S3_STORAGE_CLASS" ;;
    esac
    
    # Upload
    print_status "Uploading to S3 ($storage)..."
    
    if aws s3 cp "$backup_name" "s3://$S3_BUCKET_NAME/$backup_name" --storage-class "$storage"; then
        print_success "Backup uploaded: s3://$S3_BUCKET_NAME/$backup_name"
        rm -f "$backup_name"
    else
        print_error "Upload failed. Local backup: $PROJECT_DIR/backups/$backup_name"
    fi
    
    read -p "Press Enter to continue..."
}

list_s3_backups() {
    if ! check_s3_configured; then
        print_error "AWS S3 not configured."
        read -p "Press Enter to continue..."
        return
    fi
    
    source "$S3_CONFIG_FILE"
    
    print_status "Backups in s3://$S3_BUCKET_NAME/"
    echo
    aws s3 ls "s3://$S3_BUCKET_NAME/" --human-readable | grep -E "server-backup|full-backup" || echo "No backups found"
    echo
    read -p "Press Enter to continue..."
}

download_s3_backup() {
    if ! check_s3_configured; then
        print_error "AWS S3 not configured."
        read -p "Press Enter to continue..."
        return
    fi
    
    source "$S3_CONFIG_FILE"
    
    print_status "Available backups:"
    echo
    aws s3 ls "s3://$S3_BUCKET_NAME/" | grep -E "server-backup|full-backup" | nl
    echo
    
    read -p "Enter filename to download: " filename
    
    if [[ -z "$filename" ]]; then
        print_error "No filename provided"
        read -p "Press Enter to continue..."
        return
    fi
    
    print_status "Downloading $filename..."
    
    if aws s3 cp "s3://$S3_BUCKET_NAME/$filename" "$PROJECT_DIR/backups/$filename"; then
        print_success "Downloaded to: $PROJECT_DIR/backups/$filename"
    else
        print_error "Download failed"
    fi
    
    read -p "Press Enter to continue..."
}

restore_backup() {
    print_warning "⚠️  RESTORE WILL OVERWRITE ALL CURRENT DATA ⚠️"
    echo
    
    print_status "Available local backups:"
    ls -la "$PROJECT_DIR/backups/"*.tar.gz 2>/dev/null || echo "  No local backups"
    echo
    
    read -p "Enter full path to backup file (or 'cancel'): " backup_path
    
    if [[ "$backup_path" == "cancel" ]] || [[ -z "$backup_path" ]]; then
        return
    fi
    
    if [[ ! -f "$backup_path" ]]; then
        print_error "File not found: $backup_path"
        read -p "Press Enter to continue..."
        return
    fi
    
    read -p "Type 'YES' to confirm restore: " confirm
    if [[ "$confirm" != "YES" ]]; then
        print_status "Restore cancelled"
        read -p "Press Enter to continue..."
        return
    fi
    
    print_status "Stopping services..."
    cd "$PROJECT_DIR"
    docker-compose down
    
    # Extract
    local restore_dir="$PROJECT_DIR/backups/restore_temp"
    mkdir -p "$restore_dir"
    tar xzf "$backup_path" -C "$restore_dir"
    
    # Restore configs
    [[ -f "$restore_dir/.env" ]] && cp "$restore_dir/.env" "$ENV_FILE"
    [[ -f "$restore_dir/docker-compose.yml" ]] && cp "$restore_dir/docker-compose.yml" "$COMPOSE_FILE"
    
    # Restore Strapi project
    if [[ -f "$restore_dir/strapi_project.tar.gz" ]]; then
        print_status "Restoring Strapi project..."
        rm -rf "$STRAPI_DIR"
        tar xzf "$restore_dir/strapi_project.tar.gz" -C "$PROJECT_DIR"
    fi
    
    # Start databases
    print_status "Starting databases..."
    docker-compose up -d mysql postgres
    sleep 20
    
    # Restore MySQL
    if [[ -f "$restore_dir/mysql_backup.sql" ]]; then
        print_status "Restoring MySQL..."
        source "$ENV_FILE"
        docker-compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" < "$restore_dir/mysql_backup.sql" 2>/dev/null
    fi
    
    # Restore PostgreSQL
    if [[ -f "$restore_dir/postgres_backup.sql" ]]; then
        print_status "Restoring PostgreSQL..."
        docker-compose exec -T postgres psql -U strapi -d postgres < "$restore_dir/postgres_backup.sql" 2>/dev/null
    fi
    
    # Restore volumes
    print_status "Restoring volumes..."
    [[ -f "$restore_dir/mautic_config.tar.gz" ]] && docker run --rm -v mautic-n8n-stack_mautic_data_config:/target -v "$restore_dir":/backup alpine sh -c "rm -rf /target/* && tar xzf /backup/mautic_config.tar.gz -C /target" 2>/dev/null
    [[ -f "$restore_dir/mautic_media.tar.gz" ]] && docker run --rm -v mautic-n8n-stack_mautic_data_media_images:/target -v "$restore_dir":/backup alpine sh -c "rm -rf /target/* && tar xzf /backup/mautic_media.tar.gz -C /target" 2>/dev/null
    [[ -f "$restore_dir/n8n_data.tar.gz" ]] && docker run --rm -v mautic-n8n-stack_n8n_data:/target -v "$restore_dir":/backup alpine sh -c "rm -rf /target/* && tar xzf /backup/n8n_data.tar.gz -C /target" 2>/dev/null
    
    rm -rf "$restore_dir"
    
    print_status "Starting all services..."
    docker-compose up -d
    
    print_success "Restore completed!"
    read -p "Press Enter to continue..."
}

# Backup submenu
backup_menu() {
    while true; do
        clear
        print_header "Backup Management"
        echo
        
        if check_s3_configured; then
            echo "S3 Status: ✅ Configured"
        else
            echo "S3 Status: ❌ Not configured"
        fi
        echo
        
        echo "1. Create Local Backup"
        echo "2. Create S3 Backup"
        echo "3. Download from S3"
        echo "4. List S3 Backups"
        echo "5. Restore from Backup"
        echo "6. Configure AWS S3"
        echo "7. Back to Main Menu"
        echo
        
        read -p "Choose (1-7): " choice
        
        case $choice in
            1) create_local_backup ;;
            2) create_s3_backup ;;
            3) download_s3_backup ;;
            4) list_s3_backups ;;
            5) restore_backup ;;
            6) configure_s3 ;;
            7) return ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# =====================================================
# STRAPI MANAGEMENT
# =====================================================

strapi_menu() {
    while true; do
        clear
        print_header "Strapi CMS Management"
        echo
        
        source "$ENV_FILE" 2>/dev/null
        if [[ -n "$STRAPI_URL" ]]; then
            echo "URL: https://$STRAPI_URL/admin"
        fi
        echo
        
        echo "1. View Strapi Logs"
        echo "2. Restart Strapi"
        echo "3. Rebuild Strapi (npm install + build)"
        echo "4. API Token Instructions"
        echo "5. Content Types Guide"
        echo "6. Back to Main Menu"
        echo
        
        read -p "Choose (1-6): " choice
        
        case $choice in
            1)
                cd "$PROJECT_DIR"
                docker-compose logs --tail=100 -f strapi
                ;;
            2)
                cd "$PROJECT_DIR"
                docker-compose restart strapi
                print_success "Strapi restarted"
                sleep 2
                ;;
            3)
                cd "$PROJECT_DIR"
                print_status "Rebuilding Strapi (this may take a few minutes)..."
                docker-compose exec strapi sh -c "rm -rf node_modules build && npm install --legacy-peer-deps && npm run build"
                docker-compose restart strapi
                print_success "Strapi rebuilt"
                read -p "Press Enter to continue..."
                ;;
            4)
                clear
                print_header "Strapi API Token Setup"
                echo
                echo "1. Go to: https://$STRAPI_URL/admin"
                echo "2. Navigate to: Settings → API Tokens"
                echo "3. Click: Create new API Token"
                echo "4. Configure:"
                echo "   • Name: n8n-integration"
                echo "   • Type: Full access"
                echo "   • Duration: Unlimited"
                echo "5. Copy token to n8n credentials"
                echo
                echo "In n8n HTTP Header Auth:"
                echo "   Header: Authorization"
                echo "   Value: Bearer YOUR_TOKEN"
                echo
                read -p "Press Enter to continue..."
                ;;
            5)
                clear
                print_header "Content Types Guide"
                echo
                echo "Create these collections in Content-Type Builder:"
                echo
                echo "━━━ guardscan-article ━━━"
                echo "  • title (Text, required)"
                echo "  • slug (UID from title)"
                echo "  • content (Rich Text)"
                echo "  • excerpt (Text, max 300)"
                echo "  • featured_image (Media)"
                echo "  • category (Enum: security,news,guides)"
                echo "  • published_at (DateTime)"
                echo "  • seo_title (Text)"
                echo "  • seo_description (Text)"
                echo
                echo "━━━ yaicos-article ━━━"
                echo "  (same structure)"
                echo
                echo "━━━ amabex-article ━━━"
                echo "  (same structure)"
                echo
                echo "━━━ author (shared) ━━━"
                echo "  • name (Text)"
                echo "  • bio (Text)"
                echo "  • avatar (Media)"
                echo
                read -p "Press Enter to continue..."
                ;;
            6) return ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# =====================================================
# MAIN MENU
# =====================================================

show_management_menu() {
    while true; do
        clear
        print_header "Mautic + n8n + Strapi Stack v3.0"
        echo
        
        cd "$PROJECT_DIR" 2>/dev/null
        local running=$(docker-compose ps -q 2>/dev/null | wc -l)
        echo "Running containers: $running"
        
        # Check if Strapi is installed
        if check_strapi_installed; then
            echo "Strapi: ✅ Installed"
        else
            echo "Strapi: ❌ Not installed"
        fi
        echo
        
        echo "1.  Show Status & Resources"
        echo "2.  Start Services"
        echo "3.  Stop Services"
        echo "4.  Restart Services"
        echo "5.  View Logs"
        echo "6.  Backup Management →"
        echo "7.  Update Images"
        echo "8.  Show URLs & Passwords"
        echo "9.  Strapi Management →"
        echo "10. Add Strapi (V2→V3 Upgrade)"
        echo "11. Exit"
        echo
        
        read -p "Choose (1-11): " choice
        
        case $choice in
            1) show_status ;;
            2) start_services ;;
            3) stop_services ;;
            4) restart_services ;;
            5) view_logs ;;
            6) backup_menu ;;
            7) update_images ;;
            8)
                clear
                source "$ENV_FILE" 2>/dev/null
                print_header "Access URLs & Credentials"
                echo
                echo "🌐 URLs:"
                echo "   Mautic:  https://$MAUTIC_URL"
                echo "   n8n:     https://$N8N_URL"
                [[ -n "$STRAPI_URL" ]] && echo "   Strapi:  https://$STRAPI_URL/admin"
                echo "   Traefik: http://$SERVER_IP:8080"
                echo
                echo "🔐 Passwords:"
                echo "   MySQL Root:     $MYSQL_ROOT_PASSWORD"
                echo "   Mautic DB:      $MAUTIC_DB_PASSWORD"
                echo "   RabbitMQ:       $RABBITMQ_PASSWORD"
                echo "   n8n Encryption: $N8N_ENCRYPTION_KEY"
                [[ -n "$POSTGRES_PASSWORD" ]] && echo "   PostgreSQL:     $POSTGRES_PASSWORD"
                echo
                read -p "Press Enter to continue..."
                ;;
            9) strapi_menu ;;
            10)
                if check_strapi_installed; then
                    print_warning "Strapi is already installed"
                    read -p "Press Enter to continue..."
                else
                    upgrade_to_v3
                    read -p "Press Enter to continue..."
                fi
                ;;
            11)
                print_success "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# =====================================================
# FRESH INSTALLATION
# =====================================================

run_installation() {
    clear
    print_header "Mautic + n8n + Strapi Production Stack v3.0"
    echo
    print_status "This will install:"
    echo "  • Traefik (Reverse proxy + SSL)"
    echo "  • MySQL (Mautic database)"
    echo "  • PostgreSQL (Strapi database)"
    echo "  • RabbitMQ (Message queue)"
    echo "  • Mautic (Marketing automation)"
    echo "  • n8n (Workflow automation)"
    echo "  • Strapi (Headless CMS)"
    echo
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Installation cancelled"
        exit 1
    fi
    
    check_root
    update_system
    install_awscli
    setup_firewall
    install_docker
    install_docker_compose
    setup_auto_updates
    get_configuration
    create_directories
    create_env_file
    create_strapi_project
    create_docker_compose
    deploy_stack
    display_deployment_info
    show_management_menu
}

# =====================================================
# MAIN ENTRY POINT
# =====================================================

main() {
    if check_deployment_state; then
        source "$ENV_FILE" 2>/dev/null
        show_management_menu
    else
        run_installation
    fi
}

cleanup() {
    print_warning "Interrupted"
    exit 1
}

trap cleanup SIGINT SIGTERM

main "$@"
