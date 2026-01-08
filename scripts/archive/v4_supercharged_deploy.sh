#!/bin/bash

# =============================================================================
# Production Mautic + n8n + Strapi SUPERCHARGED Stack
# Version: 4.0 "AI-Powered"
# =============================================================================
#
# FEATURES:
# - Mautic (Marketing Automation)
# - n8n (Workflow Automation)
# - Strapi CMS with:
#   • Full SEO fields (meta, OG, canonical, alt text)
#   • AI Content Generation (Google Gemini)
#   • AI Image Generation (OpenAI DALL-E 3)
#   • Semantic Search (pgvector + OpenAI embeddings)
#   • 3 Blog content types + Author
#
# REQUIREMENTS:
# - Ubuntu 20.04+ or Debian 11+
# - 8GB+ RAM recommended
# - Docker & Docker Compose
# - Domain with DNS configured
#
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Global variables
SCRIPT_VERSION="4.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/mautic-n8n-stack"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/.env"
S3_CONFIG_FILE="$PROJECT_DIR/.s3-config"
STRAPI_DIR="$PROJECT_DIR/strapi"

# Print functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${PURPLE}${BOLD}[V4]${NC} $1"; }
print_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Check functions
check_root() { [[ $EUID -eq 0 ]] && print_warning "Running as root"; }
check_deployment_state() { [[ -f "$COMPOSE_FILE" ]] && docker-compose -f "$COMPOSE_FILE" ps -q &>/dev/null 2>&1; }
check_strapi_installed() { [[ -d "$STRAPI_DIR" ]] && [[ -f "$STRAPI_DIR/package.json" ]]; }
check_strapi_content_types() { [[ -d "$STRAPI_DIR/src/api/guardscan-article" ]]; }
check_s3_configured() { [[ -f "$S3_CONFIG_FILE" ]]; }
check_ai_configured() { source "$ENV_FILE" 2>/dev/null; [[ -n "$OPENAI_API_KEY" ]] || [[ -n "$GEMINI_API_KEY" ]]; }

generate_password() { openssl rand -base64 "${1:-32}" | tr -d "=+/" | cut -c1-"${1:-32}"; }
get_server_ip() { curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s icanhazip.com 2>/dev/null; }

# =============================================================================
# HEALTH CHECKS
# =============================================================================

wait_for_container() {
    local container=$1
    local max_attempts=${2:-30}
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
            [[ "$status" == "running" ]] && { print_success "$container ready"; return 0; }
        fi
        echo -n "."
        sleep 5
        ((attempt++))
    done
    print_error "$container failed"
    return 1
}

wait_for_postgres_vector() {
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for PostgreSQL with pgvector..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker exec strapi-postgres psql -U strapi -d strapi -c "SELECT 1;" &>/dev/null; then
            # Enable pgvector extension
            docker exec strapi-postgres psql -U strapi -d strapi -c "CREATE EXTENSION IF NOT EXISTS vector;" &>/dev/null
            if docker exec strapi-postgres psql -U strapi -d strapi -c "SELECT 1 FROM pg_extension WHERE extname='vector';" | grep -q "1"; then
                print_success "PostgreSQL with pgvector ready"
                return 0
            fi
        fi
        echo -n "."
        sleep 3
        ((attempt++))
    done
    print_warning "pgvector may need manual setup"
    return 1
}

wait_for_strapi() {
    local max_attempts=60
    local attempt=1
    
    print_status "Waiting for Strapi (2-5 minutes for first build)..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker ps --format '{{.Names}}' | grep -q "^strapi$"; then
            # Check logs for ready state
            if docker logs strapi 2>&1 | grep -q "To manage your project\|Welcome back\|http://localhost:1337"; then
                print_success "Strapi ready!"
                return 0
            fi
        fi
        
        if (( attempt % 6 == 0 )); then
            echo ""
            print_status "Still building... ($((attempt * 5))s)"
        else
            echo -n "."
        fi
        sleep 5
        ((attempt++))
    done
    
    echo ""
    print_warning "Strapi may still be building. Check: docker-compose logs -f strapi"
    return 1
}

wait_for_mautic() {
    local max_attempts=40
    local attempt=1
    
    print_status "Waiting for Mautic..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker ps --format '{{.Names}}' | grep -q "^mautic-web$"; then
            local response=$(docker exec mautic-web curl -s -o /dev/null -w "%{http_code}" http://localhost:80 2>/dev/null || echo "000")
            [[ "$response" =~ ^(200|302|301)$ ]] && { print_success "Mautic ready"; return 0; }
        fi
        echo -n "."
        sleep 5
        ((attempt++))
    done
    print_warning "Mautic may still be starting"
    return 1
}

# =============================================================================
# SYSTEM SETUP
# =============================================================================

update_system() {
    print_status "Updating system..."
    sudo apt-get update -qq
    sudo apt-get upgrade -y -qq
    sudo apt-get install -y -qq curl wget git unzip ca-certificates gnupg lsb-release jq openssl ufw fail2ban dnsutils
    print_success "System updated"
}

install_awscli() {
    command -v aws &>/dev/null && { print_success "AWS CLI ready"; return 0; }
    print_status "Installing AWS CLI..."
    sudo apt-get install -y -qq awscli
    print_success "AWS CLI installed"
}

setup_firewall() {
    print_status "Configuring firewall..."
    sudo ufw --force reset >/dev/null 2>&1
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw --force enable >/dev/null 2>&1
    print_success "Firewall configured"
}

install_docker() {
    command -v docker &>/dev/null && { print_success "Docker ready"; return 0; }
    print_status "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh >/dev/null 2>&1
    rm get-docker.sh
    sudo systemctl start docker
    sudo systemctl enable docker
    print_success "Docker installed"
}

install_docker_compose() {
    command -v docker-compose &>/dev/null && { print_success "Docker Compose ready"; return 0; }
    print_status "Installing Docker Compose..."
    local version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name 2>/dev/null || echo "v2.24.0")
    sudo curl -L "https://github.com/docker/compose/releases/download/${version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 2>/dev/null
    sudo chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose installed"
}

# =============================================================================
# CONFIGURATION
# =============================================================================

get_configuration() {
    print_header "V4 Configuration Setup"
    echo
    
    SERVER_IP=$(get_server_ip)
    print_status "Server IP: $SERVER_IP"
    echo
    
    # Domain configuration
    while true; do
        read -p "Main domain (e.g., yaicos.com): " MAIN_DOMAIN
        [[ -n "$MAIN_DOMAIN" ]] && break
        print_error "Required"
    done
    
    read -p "Mautic subdomain (default: m): " MAUTIC_SUBDOMAIN
    read -p "n8n subdomain (default: n8n): " N8N_SUBDOMAIN
    read -p "Strapi subdomain (default: cms): " STRAPI_SUBDOMAIN
    
    MAUTIC_SUBDOMAIN=${MAUTIC_SUBDOMAIN:-m}
    N8N_SUBDOMAIN=${N8N_SUBDOMAIN:-n8n}
    STRAPI_SUBDOMAIN=${STRAPI_SUBDOMAIN:-cms}
    
    MAUTIC_URL="${MAUTIC_SUBDOMAIN}.${MAIN_DOMAIN}"
    N8N_URL="${N8N_SUBDOMAIN}.${MAIN_DOMAIN}"
    STRAPI_URL="${STRAPI_SUBDOMAIN}.${MAIN_DOMAIN}"
    
    # Blog domains for CORS
    echo
    print_status "Blog Domains (for Strapi CORS)"
    read -p "Blog domain 1 (e.g., guardscan.io): " BLOG_DOMAIN_1
    read -p "Blog domain 2 (e.g., yaicos.com): " BLOG_DOMAIN_2
    read -p "Blog domain 3 (Enter to skip): " BLOG_DOMAIN_3
    
    BLOG_DOMAIN_1=${BLOG_DOMAIN_1:-localhost}
    BLOG_DOMAIN_2=${BLOG_DOMAIN_2:-localhost}
    BLOG_DOMAIN_3=${BLOG_DOMAIN_3:-""}
    
    # AI Configuration
    echo
    print_header "AI Superpowers Configuration"
    echo
    print_status "These are OPTIONAL - press Enter to skip any"
    echo
    
    read -p "OpenAI API Key (for DALL-E images + embeddings): " OPENAI_API_KEY
    read -p "Google Gemini API Key (for content generation): " GEMINI_API_KEY
    
    # Semantic search
    echo
    if [[ -n "$OPENAI_API_KEY" ]]; then
        ENABLE_SEMANTIC_SEARCH="true"
        print_success "Semantic search will be enabled (using OpenAI embeddings)"
    else
        print_warning "Semantic search disabled (requires OpenAI key)"
        ENABLE_SEMANTIC_SEARCH="false"
    fi
    
    # DNS reminder
    echo
    print_warning "Add these DNS A records (Cloudflare):"
    echo "  $MAUTIC_URL → $SERVER_IP"
    echo "  $N8N_URL → $SERVER_IP"
    echo "  $STRAPI_URL → $SERVER_IP"
    echo
    
    read -p "DNS records created? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && { print_error "Create DNS first"; exit 1; }
    
    # Generate credentials
    print_status "Generating secure credentials..."
    MYSQL_ROOT_PASSWORD=$(generate_password 32)
    MAUTIC_DB_PASSWORD=$(generate_password 32)
    RABBITMQ_PASSWORD=$(generate_password 24)
    N8N_ENCRYPTION_KEY=$(generate_password 64)
    POSTGRES_PASSWORD=$(generate_password 32)
    STRAPI_APP_KEYS="$(generate_password 24),$(generate_password 24)"
    STRAPI_API_TOKEN_SALT=$(generate_password 24)
    STRAPI_ADMIN_JWT_SECRET=$(generate_password 24)
    STRAPI_JWT_SECRET=$(generate_password 24)
    STRAPI_TRANSFER_TOKEN_SALT=$(generate_password 24)
    
    print_success "Configuration complete"
}

get_strapi_upgrade_config() {
    print_header "Strapi V4 Upgrade Configuration"
    source "$ENV_FILE"
    SERVER_IP=$(get_server_ip)
    
    read -p "Strapi subdomain (default: cms): " STRAPI_SUBDOMAIN
    STRAPI_SUBDOMAIN=${STRAPI_SUBDOMAIN:-cms}
    STRAPI_URL="${STRAPI_SUBDOMAIN}.${MAIN_DOMAIN}"
    
    echo
    print_status "Blog Domains (for CORS)"
    read -p "Blog domain 1: " BLOG_DOMAIN_1
    read -p "Blog domain 2: " BLOG_DOMAIN_2
    read -p "Blog domain 3 (Enter to skip): " BLOG_DOMAIN_3
    
    BLOG_DOMAIN_1=${BLOG_DOMAIN_1:-localhost}
    BLOG_DOMAIN_2=${BLOG_DOMAIN_2:-localhost}
    
    echo
    print_header "AI Configuration (Optional)"
    read -p "OpenAI API Key: " OPENAI_API_KEY
    read -p "Gemini API Key: " GEMINI_API_KEY
    
    [[ -n "$OPENAI_API_KEY" ]] && ENABLE_SEMANTIC_SEARCH="true" || ENABLE_SEMANTIC_SEARCH="false"
    
    echo
    print_warning "Add DNS: $STRAPI_URL → $SERVER_IP"
    read -p "Done? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
    
    POSTGRES_PASSWORD=$(generate_password 32)
    STRAPI_APP_KEYS="$(generate_password 24),$(generate_password 24)"
    STRAPI_API_TOKEN_SALT=$(generate_password 24)
    STRAPI_ADMIN_JWT_SECRET=$(generate_password 24)
    STRAPI_JWT_SECRET=$(generate_password 24)
    STRAPI_TRANSFER_TOKEN_SALT=$(generate_password 24)
    
    print_success "Configuration complete"
    return 0
}

# =============================================================================
# FILE CREATION
# =============================================================================

create_directories() {
    print_status "Creating directories..."
    mkdir -p "$PROJECT_DIR"/{backups,logs}
    print_success "Directories created"
}

create_env_file() {
    print_status "Creating environment file..."
    
    cat > "$ENV_FILE" << EOF
# =============================================================================
# V4 Supercharged Stack Configuration
# Generated: $(date)
# =============================================================================

# Domain Configuration
MAIN_DOMAIN=$MAIN_DOMAIN
MAUTIC_URL=$MAUTIC_URL
N8N_URL=$N8N_URL
STRAPI_URL=$STRAPI_URL
SERVER_IP=$SERVER_IP

# Blog Domains (CORS)
BLOG_DOMAIN_1=$BLOG_DOMAIN_1
BLOG_DOMAIN_2=$BLOG_DOMAIN_2
BLOG_DOMAIN_3=$BLOG_DOMAIN_3

# MySQL (Mautic)
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MAUTIC_DB_PASSWORD=$MAUTIC_DB_PASSWORD

# PostgreSQL (Strapi + pgvector)
POSTGRES_USER=strapi
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=strapi

# Strapi Core
STRAPI_APP_KEYS=$STRAPI_APP_KEYS
STRAPI_API_TOKEN_SALT=$STRAPI_API_TOKEN_SALT
STRAPI_ADMIN_JWT_SECRET=$STRAPI_ADMIN_JWT_SECRET
STRAPI_JWT_SECRET=$STRAPI_JWT_SECRET
STRAPI_TRANSFER_TOKEN_SALT=$STRAPI_TRANSFER_TOKEN_SALT

# AI Configuration
OPENAI_API_KEY=${OPENAI_API_KEY:-}
GEMINI_API_KEY=${GEMINI_API_KEY:-}
ENABLE_SEMANTIC_SEARCH=${ENABLE_SEMANTIC_SEARCH:-false}

# RabbitMQ
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD

# n8n
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
N8N_WEBHOOK_BASE_URL=https://${N8N_URL}

# Timezone
TZ=UTC
EOF
    
    chmod 600 "$ENV_FILE"
    print_success "Environment file created"
}

append_strapi_to_env() {
    print_status "Adding Strapi V4 configuration..."
    
    grep -q "STRAPI_URL" "$ENV_FILE" && { print_status "Updating existing config"; }
    
    # Remove old strapi config if exists
    sed -i '/# Strapi/,$d' "$ENV_FILE" 2>/dev/null || true
    
    cat >> "$ENV_FILE" << EOF

# Strapi V4 (Supercharged)
STRAPI_URL=$STRAPI_URL
BLOG_DOMAIN_1=$BLOG_DOMAIN_1
BLOG_DOMAIN_2=$BLOG_DOMAIN_2
BLOG_DOMAIN_3=$BLOG_DOMAIN_3
POSTGRES_USER=strapi
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=strapi
STRAPI_APP_KEYS=$STRAPI_APP_KEYS
STRAPI_API_TOKEN_SALT=$STRAPI_API_TOKEN_SALT
STRAPI_ADMIN_JWT_SECRET=$STRAPI_ADMIN_JWT_SECRET
STRAPI_JWT_SECRET=$STRAPI_JWT_SECRET
STRAPI_TRANSFER_TOKEN_SALT=$STRAPI_TRANSFER_TOKEN_SALT

# AI Configuration
OPENAI_API_KEY=${OPENAI_API_KEY:-}
GEMINI_API_KEY=${GEMINI_API_KEY:-}
ENABLE_SEMANTIC_SEARCH=${ENABLE_SEMANTIC_SEARCH:-false}
EOF
    
    print_success "Strapi V4 config added"
}

# =============================================================================
# STRAPI PROJECT CREATION (V4 SUPERCHARGED)
# =============================================================================

create_strapi_project() {
    print_status "Creating Strapi V4 Supercharged project..."
    
    rm -rf "$STRAPI_DIR"
    mkdir -p "$STRAPI_DIR"/{config,src/{api,extensions,services},public/uploads,database}
    
    # Package.json with AI plugins
    cat > "$STRAPI_DIR/package.json" << 'EOF'
{
  "name": "strapi-cms-v4-supercharged",
  "private": true,
  "version": "4.0.0",
  "description": "AI-Powered Multi-blog CMS with Semantic Search",
  "scripts": {
    "develop": "strapi develop",
    "start": "strapi start",
    "build": "strapi build",
    "strapi": "strapi"
  },
  "dependencies": {
    "@strapi/strapi": "4.25.0",
    "@strapi/plugin-users-permissions": "4.25.0",
    "@strapi/plugin-i18n": "4.25.0",
    "pg": "8.11.0",
    "better-sqlite3": "9.4.3",
    "openai": "^4.20.0",
    "@google/generative-ai": "^0.2.0",
    "pgvector": "^0.1.8",
    "uuid": "^9.0.0",
    "slugify": "^1.6.6"
  },
  "engines": {
    "node": ">=18.0.0 <=20.x.x",
    "npm": ">=6.0.0"
  }
}
EOF

    # Database config
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
    pool: {
      min: 2,
      max: 10,
    },
  },
});
EOF

    # Server config
    cat > "$STRAPI_DIR/config/server.js" << 'EOF'
module.exports = ({ env }) => ({
  host: env('HOST', '0.0.0.0'),
  port: env.int('PORT', 1337),
  app: {
    keys: env.array('APP_KEYS'),
  },
  url: env('PUBLIC_URL', ''),
});
EOF

    # Admin config
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
  watchIgnoreFiles: [
    '**/config/sync/**',
  ],
});
EOF

    # Middlewares with CORS for blog domains
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
          'img-src': ["'self'", 'data:', 'blob:', 'https:', 'http:'],
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
      origin: [
        'http://localhost:3000',
        'http://localhost:5173',
        'http://localhost:4321',
        'https://$BLOG_DOMAIN_1',
        'https://$BLOG_DOMAIN_2',
        'https://${BLOG_DOMAIN_3:-localhost}',
        'https://$STRAPI_URL',
        'https://www.$BLOG_DOMAIN_1',
        'https://www.$BLOG_DOMAIN_2'
      ],
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

    # Plugins config
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

    # API config for large payloads (images)
    cat > "$STRAPI_DIR/config/api.js" << 'EOF'
module.exports = {
  rest: {
    defaultLimit: 25,
    maxLimit: 100,
    withCount: true,
  },
};
EOF

    # Entry point
    cat > "$STRAPI_DIR/src/index.js" << 'EOF'
'use strict';

module.exports = {
  register({ strapi }) {
    // Register custom services on startup
  },
  
  async bootstrap({ strapi }) {
    // Bootstrap logic - runs on every startup
    console.log('🚀 Strapi V4 Supercharged - Starting up...');
    
    // Check AI configuration
    const openaiKey = process.env.OPENAI_API_KEY;
    const geminiKey = process.env.GEMINI_API_KEY;
    
    if (openaiKey) {
      console.log('✅ OpenAI configured (DALL-E + Embeddings)');
    }
    if (geminiKey) {
      console.log('✅ Gemini configured (Content Generation)');
    }
    if (process.env.ENABLE_SEMANTIC_SEARCH === 'true') {
      console.log('✅ Semantic Search enabled');
    }
  },
};
EOF

    # Admin UI entry
    mkdir -p "$STRAPI_DIR/src/admin"
    cat > "$STRAPI_DIR/src/admin/app.js" << 'EOF'
export default {
  config: {
    locales: ['en'],
    translations: {
      en: {
        'app.components.LeftMenu.navbrand.title': 'Strapi CMS',
        'app.components.LeftMenu.navbrand.workplace': 'AI-Powered',
      },
    },
    tutorials: false,
    notifications: { releases: false },
  },
  bootstrap() {},
};
EOF

    # .gitignore
    cat > "$STRAPI_DIR/.gitignore" << 'EOF'
node_modules/
build/
.strapi/
.cache/
dist/
*.log
.env
.env.*
!.env.example
EOF

    # .env.example for reference
    cat > "$STRAPI_DIR/.env.example" << 'EOF'
# Database
DATABASE_HOST=postgres
DATABASE_PORT=5432
DATABASE_NAME=strapi
DATABASE_USERNAME=strapi
DATABASE_PASSWORD=your_password

# Strapi
APP_KEYS=key1,key2
API_TOKEN_SALT=your_salt
ADMIN_JWT_SECRET=your_secret
JWT_SECRET=your_jwt_secret
TRANSFER_TOKEN_SALT=your_transfer_salt

# AI (Optional)
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=AIza...
ENABLE_SEMANTIC_SEARCH=true
EOF

    print_success "Strapi V4 project created"
}

# =============================================================================
# AI SERVICES
# =============================================================================

create_ai_services() {
    print_status "Creating AI service layer..."
    
    mkdir -p "$STRAPI_DIR/src/services"
    
    # OpenAI Service (DALL-E + Embeddings)
    cat > "$STRAPI_DIR/src/services/openai.js" << 'EOFJS'
'use strict';

const OpenAI = require('openai');

let openaiClient = null;

const getClient = () => {
  if (!openaiClient && process.env.OPENAI_API_KEY) {
    openaiClient = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });
  }
  return openaiClient;
};

module.exports = {
  /**
   * Generate image using DALL-E 3
   * @param {string} prompt - Image description
   * @param {object} options - size, quality, style
   * @returns {Promise<string>} - Image URL
   */
  async generateImage(prompt, options = {}) {
    const client = getClient();
    if (!client) throw new Error('OpenAI not configured');
    
    const { size = '1792x1024', quality = 'standard', style = 'vivid' } = options;
    
    try {
      const response = await client.images.generate({
        model: 'dall-e-3',
        prompt: prompt,
        n: 1,
        size: size,
        quality: quality,
        style: style,
      });
      
      return response.data[0].url;
    } catch (error) {
      console.error('DALL-E Error:', error.message);
      throw error;
    }
  },
  
  /**
   * Generate embeddings for semantic search
   * @param {string} text - Text to embed
   * @returns {Promise<number[]>} - Embedding vector (1536 dimensions)
   */
  async generateEmbedding(text) {
    const client = getClient();
    if (!client) throw new Error('OpenAI not configured');
    
    try {
      const response = await client.embeddings.create({
        model: 'text-embedding-3-small',
        input: text,
        encoding_format: 'float',
      });
      
      return response.data[0].embedding;
    } catch (error) {
      console.error('Embedding Error:', error.message);
      throw error;
    }
  },
  
  /**
   * Check if OpenAI is configured
   */
  isConfigured() {
    return !!process.env.OPENAI_API_KEY;
  },
};
EOFJS

    # Gemini Service (Content Generation)
    cat > "$STRAPI_DIR/src/services/gemini.js" << 'EOFJS'
'use strict';

const { GoogleGenerativeAI } = require('@google/generative-ai');

let geminiClient = null;
let geminiModel = null;

const getModel = () => {
  if (!geminiModel && process.env.GEMINI_API_KEY) {
    geminiClient = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    geminiModel = geminiClient.getGenerativeModel({ model: 'gemini-pro' });
  }
  return geminiModel;
};

module.exports = {
  /**
   * Generate content using Gemini
   * @param {string} prompt - Generation prompt
   * @returns {Promise<string>} - Generated text
   */
  async generateContent(prompt) {
    const model = getModel();
    if (!model) throw new Error('Gemini not configured');
    
    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      return response.text();
    } catch (error) {
      console.error('Gemini Error:', error.message);
      throw error;
    }
  },
  
  /**
   * Generate SEO metadata
   * @param {string} title - Article title
   * @param {string} content - Article content
   * @returns {Promise<object>} - { metaTitle, metaDescription }
   */
  async generateSEO(title, content) {
    const model = getModel();
    if (!model) throw new Error('Gemini not configured');
    
    const prompt = `Generate SEO metadata for this article:
Title: ${title}
Content preview: ${content.substring(0, 500)}

Return ONLY a JSON object with:
- metaTitle (max 60 chars, compelling)
- metaDescription (max 160 chars, includes keywords)

JSON:`;
    
    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();
      
      // Extract JSON from response
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
      }
      throw new Error('Invalid response format');
    } catch (error) {
      console.error('SEO Generation Error:', error.message);
      throw error;
    }
  },
  
  /**
   * Generate article excerpt
   * @param {string} content - Full content
   * @param {number} maxLength - Max chars
   * @returns {Promise<string>} - Excerpt
   */
  async generateExcerpt(content, maxLength = 300) {
    const model = getModel();
    if (!model) throw new Error('Gemini not configured');
    
    const prompt = `Summarize this article in ${maxLength} characters or less. Make it engaging and informative:

${content.substring(0, 2000)}

Summary:`;
    
    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      return response.text().substring(0, maxLength);
    } catch (error) {
      console.error('Excerpt Generation Error:', error.message);
      throw error;
    }
  },
  
  /**
   * Generate image prompt from article
   * @param {string} title - Article title
   * @param {string} content - Article content
   * @param {object} brand - Brand guidelines
   * @returns {Promise<string>} - DALL-E prompt
   */
  async generateImagePrompt(title, content, brand = {}) {
    const model = getModel();
    if (!model) throw new Error('Gemini not configured');
    
    const { style = 'modern, professional', colors = 'blue and white', avoid = 'text, logos, faces' } = brand;
    
    const prompt = `Create a DALL-E 3 image prompt for this article:
Title: ${title}
Content: ${content.substring(0, 500)}

Brand guidelines:
- Style: ${style}
- Colors: ${colors}
- Avoid: ${avoid}

Create a detailed, visual prompt that would make a great blog cover image. Focus on abstract concepts, objects, or scenes. Max 200 words.

Prompt:`;
    
    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      return response.text();
    } catch (error) {
      console.error('Image Prompt Error:', error.message);
      throw error;
    }
  },
  
  /**
   * Check if Gemini is configured
   */
  isConfigured() {
    return !!process.env.GEMINI_API_KEY;
  },
};
EOFJS

    # Semantic Search Service
    cat > "$STRAPI_DIR/src/services/semantic-search.js" << 'EOFJS'
'use strict';

const openaiService = require('./openai');

module.exports = {
  /**
   * Search articles by semantic similarity
   * @param {string} query - Search query
   * @param {string} collection - Collection name
   * @param {number} limit - Max results
   * @returns {Promise<array>} - Matching articles with scores
   */
  async search(query, collection, limit = 10) {
    if (!openaiService.isConfigured()) {
      throw new Error('Semantic search requires OpenAI API key');
    }
    
    // Generate query embedding
    const queryEmbedding = await openaiService.generateEmbedding(query);
    
    // Search in database using pgvector
    const knex = strapi.db.connection;
    
    const results = await knex.raw(`
      SELECT 
        id,
        title,
        slug,
        excerpt,
        1 - (embedding <=> ?::vector) as similarity
      FROM ${collection}
      WHERE embedding IS NOT NULL
      ORDER BY embedding <=> ?::vector
      LIMIT ?
    `, [JSON.stringify(queryEmbedding), JSON.stringify(queryEmbedding), limit]);
    
    return results.rows;
  },
  
  /**
   * Generate and store embedding for an article
   * @param {object} article - Article data
   * @param {string} collection - Collection name
   */
  async indexArticle(article, collection) {
    if (!openaiService.isConfigured()) {
      console.warn('Skipping embedding - OpenAI not configured');
      return;
    }
    
    const textToEmbed = `${article.title} ${article.excerpt || ''} ${article.content || ''}`;
    const embedding = await openaiService.generateEmbedding(textToEmbed);
    
    const knex = strapi.db.connection;
    
    await knex.raw(`
      UPDATE ${collection}
      SET embedding = ?::vector
      WHERE id = ?
    `, [JSON.stringify(embedding), article.id]);
  },
  
  /**
   * Check if semantic search is enabled
   */
  isEnabled() {
    return process.env.ENABLE_SEMANTIC_SEARCH === 'true' && openaiService.isConfigured();
  },
};
EOFJS

    print_success "AI services created"
}

# =============================================================================
# CONTENT TYPES WITH FULL SEO
# =============================================================================

create_content_types() {
    print_status "Creating blog content types with SEO fields..."
    
    # Check if already exists
    if check_strapi_content_types; then
        print_status "Content types exist. Recreate? (y/N)"
        read -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && { print_status "Skipping"; return 0; }
    fi
    
    local apis=("guardscan-article" "yaicos-article" "amabex-article" "author")
    local collections=("guardscan_articles" "yaicos_articles" "amabex_articles" "authors")
    local displays=("GuardScan Article" "Yaicos Article" "Amabex Article" "Author")
    
    for i in "${!apis[@]}"; do
        local api="${apis[$i]}"
        local collection="${collections[$i]}"
        local display="${displays[$i]}"
        local api_dir="$STRAPI_DIR/src/api/$api"
        
        mkdir -p "$api_dir"/{content-types/$api,controllers,routes,services,lifecycles}
        
        # Schema
        if [[ "$api" == "author" ]]; then
            cat > "$api_dir/content-types/$api/schema.json" << EOF
{
  "kind": "collectionType",
  "collectionName": "$collection",
  "info": {
    "singularName": "$api",
    "pluralName": "${api}s",
    "displayName": "$display",
    "description": "Blog authors"
  },
  "options": { "draftAndPublish": false },
  "attributes": {
    "name": { "type": "string", "required": true },
    "slug": { "type": "uid", "targetField": "name" },
    "bio": { "type": "text" },
    "avatar": { 
      "type": "media", 
      "multiple": false, 
      "allowedTypes": ["images"]
    },
    "email": { "type": "email" },
    "website": { "type": "string" },
    "twitter": { "type": "string" },
    "linkedin": { "type": "string" }
  }
}
EOF
        else
            local category_options=""
            case "$api" in
                "guardscan-article") category_options='"security", "news", "guides", "tutorials", "reviews"' ;;
                "yaicos-article") category_options='"technology", "business", "lifestyle", "news", "tutorials"' ;;
                "amabex-article") category_options='"products", "services", "news", "updates", "guides"' ;;
            esac
            
            cat > "$api_dir/content-types/$api/schema.json" << EOF
{
  "kind": "collectionType",
  "collectionName": "$collection",
  "info": {
    "singularName": "$api",
    "pluralName": "${api}s",
    "displayName": "$display",
    "description": "Blog articles with full SEO"
  },
  "options": { "draftAndPublish": true },
  "attributes": {
    "title": { 
      "type": "string", 
      "required": true,
      "maxLength": 100
    },
    "slug": { 
      "type": "uid", 
      "targetField": "title", 
      "required": true 
    },
    "content": { 
      "type": "richtext" 
    },
    "excerpt": { 
      "type": "text", 
      "maxLength": 300 
    },
    "featured_image": { 
      "type": "media", 
      "multiple": false, 
      "allowedTypes": ["images"]
    },
    "category": { 
      "type": "enumeration", 
      "enum": [$category_options],
      "required": true
    },
    "tags": {
      "type": "json"
    },
    "author": { 
      "type": "relation", 
      "relation": "manyToOne", 
      "target": "api::author.author"
    },
    "reading_time": {
      "type": "integer",
      "default": 5
    },
    "meta_title": { 
      "type": "string", 
      "maxLength": 60 
    },
    "meta_description": { 
      "type": "text", 
      "maxLength": 160 
    },
    "canonical_url": { 
      "type": "string"
    },
    "og_image": { 
      "type": "media", 
      "multiple": false, 
      "allowedTypes": ["images"]
    },
    "og_image_alt": { 
      "type": "string", 
      "maxLength": 125 
    },
    "og_image_width": { 
      "type": "integer", 
      "default": 1200 
    },
    "og_image_height": { 
      "type": "integer", 
      "default": 630 
    },
    "no_index": { 
      "type": "boolean", 
      "default": false 
    },
    "embedding": {
      "type": "json"
    },
    "ai_generated": {
      "type": "boolean",
      "default": false
    }
  }
}
EOF

            # Lifecycle hooks for auto-embedding
            cat > "$api_dir/content-types/$api/lifecycles.js" << EOFJS
'use strict';

module.exports = {
  async afterCreate(event) {
    const { result } = event;
    
    // Auto-generate embedding if semantic search enabled
    if (process.env.ENABLE_SEMANTIC_SEARCH === 'true') {
      try {
        const semanticSearch = require('../../../../services/semantic-search');
        await semanticSearch.indexArticle(result, '${collection}');
        console.log('✅ Embedding generated for:', result.title);
      } catch (error) {
        console.error('Embedding failed:', error.message);
      }
    }
  },
  
  async afterUpdate(event) {
    const { result } = event;
    
    // Re-generate embedding on content update
    if (process.env.ENABLE_SEMANTIC_SEARCH === 'true') {
      try {
        const semanticSearch = require('../../../../services/semantic-search');
        await semanticSearch.indexArticle(result, '${collections}');
      } catch (error) {
        console.error('Embedding update failed:', error.message);
      }
    }
  },
};
EOFJS
        fi
        
        # Controller
        cat > "$api_dir/controllers/$api.js" << EOF
'use strict';
const { createCoreController } = require('@strapi/strapi').factories;

module.exports = createCoreController('api::$api.$api', ({ strapi }) => ({
  // Custom actions can be added here
}));
EOF
        
        # Service
        cat > "$api_dir/services/$api.js" << EOF
'use strict';
const { createCoreService } = require('@strapi/strapi').factories;

module.exports = createCoreService('api::$api.$api');
EOF
        
        # Routes
        cat > "$api_dir/routes/$api.js" << EOF
'use strict';
const { createCoreRouter } = require('@strapi/strapi').factories;

module.exports = createCoreRouter('api::$api.$api');
EOF
        
        print_status "Created: $display"
    done
    
    print_success "All content types created"
}

# =============================================================================
# CUSTOM API ROUTES (AI & Search)
# =============================================================================

create_custom_routes() {
    print_status "Creating custom API routes..."
    
    mkdir -p "$STRAPI_DIR/src/api/ai/controllers"
    mkdir -p "$STRAPI_DIR/src/api/ai/routes"
    mkdir -p "$STRAPI_DIR/src/api/search/controllers"
    mkdir -p "$STRAPI_DIR/src/api/search/routes"
    
    # AI Controller
    cat > "$STRAPI_DIR/src/api/ai/controllers/ai.js" << 'EOFJS'
'use strict';

module.exports = {
  /**
   * Generate SEO metadata
   * POST /api/ai/generate-seo
   */
  async generateSeo(ctx) {
    try {
      const { title, content } = ctx.request.body;
      
      if (!title || !content) {
        return ctx.badRequest('Title and content required');
      }
      
      const gemini = require('../../../services/gemini');
      
      if (!gemini.isConfigured()) {
        return ctx.badRequest('Gemini not configured');
      }
      
      const seo = await gemini.generateSEO(title, content);
      ctx.body = seo;
    } catch (error) {
      ctx.throw(500, error.message);
    }
  },
  
  /**
   * Generate article excerpt
   * POST /api/ai/generate-excerpt
   */
  async generateExcerpt(ctx) {
    try {
      const { content, maxLength = 300 } = ctx.request.body;
      
      if (!content) {
        return ctx.badRequest('Content required');
      }
      
      const gemini = require('../../../services/gemini');
      
      if (!gemini.isConfigured()) {
        return ctx.badRequest('Gemini not configured');
      }
      
      const excerpt = await gemini.generateExcerpt(content, maxLength);
      ctx.body = { excerpt };
    } catch (error) {
      ctx.throw(500, error.message);
    }
  },
  
  /**
   * Generate cover image
   * POST /api/ai/generate-image
   */
  async generateImage(ctx) {
    try {
      const { title, content, brand } = ctx.request.body;
      
      if (!title) {
        return ctx.badRequest('Title required');
      }
      
      const gemini = require('../../../services/gemini');
      const openai = require('../../../services/openai');
      
      if (!gemini.isConfigured() || !openai.isConfigured()) {
        return ctx.badRequest('AI services not configured');
      }
      
      // Generate prompt using Gemini
      const prompt = await gemini.generateImagePrompt(title, content || '', brand || {});
      
      // Generate image using DALL-E
      const imageUrl = await openai.generateImage(prompt, {
        size: '1792x1024',
        quality: 'standard',
        style: 'vivid',
      });
      
      ctx.body = { 
        prompt,
        imageUrl,
        message: 'Download and upload to Media Library'
      };
    } catch (error) {
      ctx.throw(500, error.message);
    }
  },
  
  /**
   * Check AI status
   * GET /api/ai/status
   */
  async status(ctx) {
    const gemini = require('../../../services/gemini');
    const openai = require('../../../services/openai');
    
    ctx.body = {
      gemini: gemini.isConfigured(),
      openai: openai.isConfigured(),
      semanticSearch: process.env.ENABLE_SEMANTIC_SEARCH === 'true',
    };
  },
};
EOFJS

    # AI Routes
    cat > "$STRAPI_DIR/src/api/ai/routes/ai.js" << 'EOFJS'
module.exports = {
  routes: [
    {
      method: 'POST',
      path: '/ai/generate-seo',
      handler: 'ai.generateSeo',
      config: {
        auth: false, // Change to true for authenticated only
      },
    },
    {
      method: 'POST',
      path: '/ai/generate-excerpt',
      handler: 'ai.generateExcerpt',
      config: {
        auth: false,
      },
    },
    {
      method: 'POST',
      path: '/ai/generate-image',
      handler: 'ai.generateImage',
      config: {
        auth: false,
      },
    },
    {
      method: 'GET',
      path: '/ai/status',
      handler: 'ai.status',
      config: {
        auth: false,
      },
    },
  ],
};
EOFJS

    # Search Controller
    cat > "$STRAPI_DIR/src/api/search/controllers/search.js" << 'EOFJS'
'use strict';

module.exports = {
  /**
   * Semantic search
   * POST /api/search/semantic
   */
  async semantic(ctx) {
    try {
      const { query, collection = 'guardscan_articles', limit = 10 } = ctx.request.body;
      
      if (!query) {
        return ctx.badRequest('Query required');
      }
      
      const semanticSearch = require('../../../services/semantic-search');
      
      if (!semanticSearch.isEnabled()) {
        return ctx.badRequest('Semantic search not enabled');
      }
      
      const results = await semanticSearch.search(query, collection, limit);
      ctx.body = { results };
    } catch (error) {
      ctx.throw(500, error.message);
    }
  },
  
  /**
   * Search status
   * GET /api/search/status
   */
  async status(ctx) {
    const semanticSearch = require('../../../services/semantic-search');
    
    ctx.body = {
      enabled: semanticSearch.isEnabled(),
    };
  },
};
EOFJS

    # Search Routes
    cat > "$STRAPI_DIR/src/api/search/routes/search.js" << 'EOFJS'
module.exports = {
  routes: [
    {
      method: 'POST',
      path: '/search/semantic',
      handler: 'search.semantic',
      config: {
        auth: false,
      },
    },
    {
      method: 'GET',
      path: '/search/status',
      handler: 'search.status',
      config: {
        auth: false,
      },
    },
  ],
};
EOFJS

    print_success "Custom API routes created"
}

# =============================================================================
# DOCKER COMPOSE
# =============================================================================

create_docker_compose() {
    print_status "Creating Docker Compose..."
    
    cat > "$COMPOSE_FILE" << 'EOF'
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

services:
  # ===========================================
  # Traefik Reverse Proxy
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
  # MySQL (Mautic)
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
  # PostgreSQL with pgvector (Strapi + Semantic Search)
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
  # RabbitMQ (Mautic)
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
  # Strapi CMS (V4 Supercharged)
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
      NODE_ENV: development
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
    command: sh -c "npm install --legacy-peer-deps 2>/dev/null; npm run develop"
    labels:
      - traefik.enable=true
      - traefik.http.routers.strapi.rule=Host(`${STRAPI_URL}`)
      - traefik.http.routers.strapi.tls=true
      - traefik.http.routers.strapi.tls.certresolver=letsencrypt
      - traefik.http.services.strapi.loadbalancer.server.port=1337
    networks:
      - mautic_network

  # ===========================================
  # Mautic Web
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
  # Mautic Cron
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
EOF
    
    print_success "Docker Compose created"
}

# =============================================================================
# DEPLOYMENT
# =============================================================================

deploy_stack() {
    print_status "Deploying V4 stack..."
    cd "$PROJECT_DIR"
    
    docker-compose pull
    docker-compose up -d
    
    echo
    wait_for_container "traefik" 20
    wait_for_container "mautic-mysql" 30
    wait_for_container "strapi-postgres" 30
    wait_for_postgres_vector
    wait_for_container "mautic-rabbitmq" 30
    wait_for_mautic
    wait_for_strapi
    
    print_success "V4 Stack deployed!"
}

# =============================================================================
# MAUTIC FIX
# =============================================================================

fix_mautic_vendor() {
    print_header "Mautic Vendor Fix"
    echo
    print_warning "Fixes PHP version mismatch errors"
    print_warning "Mautic down for 2-3 minutes"
    echo
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && return
    
    cd "$PROJECT_DIR"
    
    print_status "Stopping Mautic..."
    docker-compose stop mautic_web mautic_cron
    
    print_status "Removing vendor volume..."
    local volume_name="${PROJECT_DIR##*/}_mautic_data_vendor"
    docker volume rm "$volume_name" 2>/dev/null || docker volume rm "mautic-n8n-stack_mautic_data_vendor" 2>/dev/null || true
    
    print_status "Starting Mautic..."
    docker-compose up -d mautic_web mautic_cron
    
    wait_for_mautic
    
    print_success "Mautic vendor fixed!"
    read -p "Press Enter..."
}

# =============================================================================
# UPGRADE TO V4
# =============================================================================

upgrade_to_v4() {
    print_header "Upgrade to V4 Supercharged"
    echo
    print_status "This will:"
    echo "  • Add pgvector to PostgreSQL (semantic search)"
    echo "  • Add AI services (Gemini + OpenAI)"
    echo "  • Update content types with SEO fields"
    echo "  • Add custom API routes"
    echo "  • NOT affect existing data"
    echo
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
    
    get_strapi_upgrade_config || return 1
    
    cd "$PROJECT_DIR"
    
    # Backup
    cp "$COMPOSE_FILE" "$COMPOSE_FILE.pre-v4.backup"
    cp "$ENV_FILE" "$ENV_FILE.pre-v4.backup"
    
    # Remove old services if exist
    docker-compose stop gotenberg qdrant 2>/dev/null || true
    docker-compose rm -f gotenberg qdrant 2>/dev/null || true
    
    # Update env
    append_strapi_to_env
    
    # Backup strapi folder
    [[ -d "$STRAPI_DIR" ]] && cp -r "$STRAPI_DIR" "$STRAPI_DIR.pre-v4.backup"
    
    # Create new Strapi
    create_strapi_project
    create_ai_services
    create_content_types
    create_custom_routes
    
    # Update compose
    create_docker_compose
    
    # Deploy
    print_status "Deploying V4..."
    docker-compose up -d
    
    wait_for_postgres_vector
    wait_for_strapi
    
    print_success "V4 Upgrade complete!"
    echo
    print_status "Strapi admin: https://$STRAPI_URL/admin"
    print_status "Create admin account and enable public permissions"
    
    read -p "Press Enter..."
    return 0
}

# =============================================================================
# DISPLAY INFO
# =============================================================================

display_deployment_info() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           V4 SUPERCHARGED DEPLOYMENT COMPLETE                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    echo "🌐 URLs:"
    echo "   Mautic:  https://$MAUTIC_URL"
    echo "   n8n:     https://$N8N_URL"
    echo "   Strapi:  https://$STRAPI_URL/admin"
    echo
    echo "🔐 Credentials (SAVE THESE!):"
    echo "   MySQL Root:   $MYSQL_ROOT_PASSWORD"
    echo "   Mautic DB:    $MAUTIC_DB_PASSWORD"
    echo "   PostgreSQL:   $POSTGRES_PASSWORD"
    echo "   RabbitMQ:     $RABBITMQ_PASSWORD"
    echo "   n8n Key:      $N8N_ENCRYPTION_KEY"
    echo
    echo "🤖 AI Configuration:"
    [[ -n "$OPENAI_API_KEY" ]] && echo "   OpenAI:    ✅ Configured" || echo "   OpenAI:    ❌ Not set"
    [[ -n "$GEMINI_API_KEY" ]] && echo "   Gemini:    ✅ Configured" || echo "   Gemini:    ❌ Not set"
    [[ "$ENABLE_SEMANTIC_SEARCH" == "true" ]] && echo "   Semantic:  ✅ Enabled" || echo "   Semantic:  ❌ Disabled"
    echo
    echo "📝 Content Types Created:"
    echo "   • guardscan-article (with full SEO)"
    echo "   • yaicos-article (with full SEO)"
    echo "   • amabex-article (with full SEO)"
    echo "   • author"
    echo
    echo "🚀 AI API Endpoints:"
    echo "   POST /api/ai/generate-seo"
    echo "   POST /api/ai/generate-excerpt"
    echo "   POST /api/ai/generate-image"
    echo "   GET  /api/ai/status"
    echo "   POST /api/search/semantic"
    echo
    echo "📋 Next Steps:"
    echo "   1. Create Strapi admin at https://$STRAPI_URL/admin"
    echo "   2. Settings → Users & Permissions → Public"
    echo "   3. Enable find/findOne for article types"
    echo "   4. Test AI endpoints: GET https://$STRAPI_URL/api/ai/status"
    echo
    print_warning "Passwords won't be shown again!"
    read -p "Press Enter..."
}

# =============================================================================
# MANAGEMENT MENUS
# =============================================================================

show_status() {
    clear
    print_header "Service Status"
    cd "$PROJECT_DIR"
    docker-compose ps
    echo
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(docker-compose ps -q 2>/dev/null) 2>/dev/null || true
    echo
    read -p "Press Enter..."
}

start_services() { cd "$PROJECT_DIR"; docker-compose up -d; print_success "Started"; sleep 2; }
stop_services() { cd "$PROJECT_DIR"; docker-compose down; print_success "Stopped"; sleep 2; }
restart_services() { cd "$PROJECT_DIR"; docker-compose restart; print_success "Restarted"; sleep 2; }

view_logs() {
    cd "$PROJECT_DIR"
    echo "Services: $(docker-compose ps --services | tr '\n' ' ')"
    read -p "Service (or 'all'): " svc
    [[ "$svc" == "all" ]] && docker-compose logs --tail=100 -f || docker-compose logs --tail=100 -f "$svc"
}

update_images() {
    cd "$PROJECT_DIR"
    docker-compose pull
    docker-compose up -d
    docker image prune -f
    print_success "Updated"
    read -p "Press Enter..."
}

configure_ai_keys() {
    print_header "Configure AI Keys"
    source "$ENV_FILE"
    
    echo
    echo "Current Status:"
    [[ -n "$OPENAI_API_KEY" ]] && echo "  OpenAI: ✅ Set" || echo "  OpenAI: ❌ Not set"
    [[ -n "$GEMINI_API_KEY" ]] && echo "  Gemini: ✅ Set" || echo "  Gemini: ❌ Not set"
    echo
    
    read -p "OpenAI API Key (Enter to keep): " new_openai
    read -p "Gemini API Key (Enter to keep): " new_gemini
    
    [[ -n "$new_openai" ]] && sed -i "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=$new_openai|" "$ENV_FILE"
    [[ -n "$new_gemini" ]] && sed -i "s|^GEMINI_API_KEY=.*|GEMINI_API_KEY=$new_gemini|" "$ENV_FILE"
    
    if [[ -n "$new_openai" ]] || [[ -n "$new_gemini" ]]; then
        print_status "Restarting Strapi..."
        cd "$PROJECT_DIR"
        docker-compose restart strapi
        print_success "AI keys updated"
    fi
    
    read -p "Press Enter..."
}

test_ai_endpoints() {
    source "$ENV_FILE"
    
    print_status "Testing AI endpoints..."
    echo
    
    local status=$(curl -s "https://$STRAPI_URL/api/ai/status" 2>/dev/null)
    echo "AI Status: $status"
    echo
    
    local search=$(curl -s "https://$STRAPI_URL/api/search/status" 2>/dev/null)
    echo "Search Status: $search"
    
    read -p "Press Enter..."
}

reindex_embeddings() {
    print_header "Reindex Embeddings"
    print_warning "This will regenerate embeddings for all articles"
    print_warning "Requires OpenAI API key configured"
    echo
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && return
    
    print_status "Reindexing..."
    
    # This would need a custom endpoint - placeholder for now
    print_warning "Manual reindex: Coming in future update"
    print_status "For now, update each article to trigger embedding"
    
    read -p "Press Enter..."
}

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================

configure_s3() {
    print_header "AWS S3 Configuration"
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
    read -s -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    echo
    read -p "S3 Bucket Name: " S3_BUCKET_NAME
    read -p "AWS Region (default: us-east-1): " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    
    cat > "$S3_CONFIG_FILE" << EOF
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
S3_BUCKET_NAME=$S3_BUCKET_NAME
AWS_REGION=$AWS_REGION
EOF
    chmod 600 "$S3_CONFIG_FILE"
    
    aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
    aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
    aws configure set default.region "$AWS_REGION"
    
    print_success "S3 configured"
    read -p "Press Enter..."
}

create_local_backup() {
    local ts=$(date +%Y-%m-%d_%H-%M-%S)
    local dir="$PROJECT_DIR/backups/$ts"
    mkdir -p "$dir"
    
    print_status "Creating backup..."
    cd "$PROJECT_DIR"
    source "$ENV_FILE"
    
    docker-compose exec -T mysql mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases > "$dir/mysql.sql" 2>/dev/null || true
    docker-compose exec -T postgres pg_dumpall -U strapi > "$dir/postgres.sql" 2>/dev/null || true
    
    cp "$ENV_FILE" "$dir/"
    cp "$COMPOSE_FILE" "$dir/"
    
    [[ -d "$STRAPI_DIR" ]] && tar czf "$dir/strapi.tar.gz" -C "$PROJECT_DIR" strapi --exclude='strapi/node_modules' --exclude='strapi/.cache' --exclude='strapi/build' 2>/dev/null || true
    
    cd "$PROJECT_DIR/backups"
    tar czf "backup-$ts.tar.gz" -C "$ts" .
    rm -rf "$ts"
    
    print_success "Backup: $PROJECT_DIR/backups/backup-$ts.tar.gz"
    read -p "Press Enter..."
}

create_s3_backup() {
    check_s3_configured || { print_error "S3 not configured"; read -p "Press Enter..."; return; }
    source "$S3_CONFIG_FILE"
    
    local ts=$(date +%Y-%m-%d_%H-%M-%S)
    local dir="$PROJECT_DIR/backups/temp_$ts"
    mkdir -p "$dir"
    
    print_status "Creating S3 backup..."
    cd "$PROJECT_DIR"
    source "$ENV_FILE"
    
    docker-compose exec -T mysql mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases > "$dir/mysql.sql" 2>/dev/null || true
    docker-compose exec -T postgres pg_dumpall -U strapi > "$dir/postgres.sql" 2>/dev/null || true
    cp "$ENV_FILE" "$dir/"
    cp "$COMPOSE_FILE" "$dir/"
    [[ -d "$STRAPI_DIR" ]] && tar czf "$dir/strapi.tar.gz" -C "$PROJECT_DIR" strapi --exclude='strapi/node_modules' 2>/dev/null || true
    
    cd "$PROJECT_DIR/backups"
    local name="backup-$ts.tar.gz"
    tar czf "$name" -C "temp_$ts" .
    rm -rf "temp_$ts"
    
    aws s3 cp "$name" "s3://$S3_BUCKET_NAME/$name" --storage-class STANDARD_IA && rm -f "$name"
    
    print_success "Uploaded to S3"
    read -p "Press Enter..."
}

list_s3_backups() {
    check_s3_configured || { print_error "S3 not configured"; read -p "Press Enter..."; return; }
    source "$S3_CONFIG_FILE"
    aws s3 ls "s3://$S3_BUCKET_NAME/" --human-readable | grep backup
    read -p "Press Enter..."
}

download_s3_backup() {
    check_s3_configured || { print_error "S3 not configured"; read -p "Press Enter..."; return; }
    source "$S3_CONFIG_FILE"
    
    aws s3 ls "s3://$S3_BUCKET_NAME/" | grep backup
    read -p "Filename: " fname
    aws s3 cp "s3://$S3_BUCKET_NAME/$fname" "$PROJECT_DIR/backups/$fname"
    print_success "Downloaded"
    read -p "Press Enter..."
}

restore_backup() {
    print_warning "⚠️ RESTORE OVERWRITES ALL DATA"
    ls "$PROJECT_DIR/backups/"*.tar.gz 2>/dev/null || echo "No backups"
    read -p "Full path (or 'cancel'): " path
    [[ "$path" == "cancel" || -z "$path" ]] && return
    [[ ! -f "$path" ]] && { print_error "Not found"; read -p "Press Enter..."; return; }
    
    read -p "Type YES to confirm: " confirm
    [[ "$confirm" != "YES" ]] && return
    
    cd "$PROJECT_DIR"
    docker-compose down
    
    local dir="$PROJECT_DIR/backups/restore_tmp"
    mkdir -p "$dir"
    tar xzf "$path" -C "$dir"
    
    [[ -f "$dir/.env" ]] && cp "$dir/.env" "$ENV_FILE"
    [[ -f "$dir/docker-compose.yml" ]] && cp "$dir/docker-compose.yml" "$COMPOSE_FILE"
    [[ -f "$dir/strapi.tar.gz" ]] && { rm -rf "$STRAPI_DIR"; tar xzf "$dir/strapi.tar.gz" -C "$PROJECT_DIR"; }
    
    docker-compose up -d mysql postgres
    sleep 20
    
    source "$ENV_FILE"
    [[ -f "$dir/mysql.sql" ]] && docker-compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" < "$dir/mysql.sql"
    [[ -f "$dir/postgres.sql" ]] && docker-compose exec -T postgres psql -U strapi < "$dir/postgres.sql"
    
    rm -rf "$dir"
    docker-compose up -d
    
    print_success "Restored"
    read -p "Press Enter..."
}

backup_menu() {
    while true; do
        clear
        print_header "Backup Management"
        check_s3_configured && echo "S3: ✅ Configured" || echo "S3: ❌ Not configured"
        echo
        echo "1. Local Backup"
        echo "2. S3 Backup"
        echo "3. Download from S3"
        echo "4. List S3 Backups"
        echo "5. Restore Backup"
        echo "6. Configure S3"
        echo "7. Back"
        read -p "Choice: " c
        case $c in
            1) create_local_backup ;;
            2) create_s3_backup ;;
            3) download_s3_backup ;;
            4) list_s3_backups ;;
            5) restore_backup ;;
            6) configure_s3 ;;
            7) return ;;
        esac
    done
}

# =============================================================================
# STRAPI MENU
# =============================================================================

strapi_menu() {
    while true; do
        clear
        print_header "Strapi V4 Supercharged"
        source "$ENV_FILE" 2>/dev/null
        [[ -n "$STRAPI_URL" ]] && echo "URL: https://$STRAPI_URL/admin"
        check_strapi_content_types && echo "Content Types: ✅" || echo "Content Types: ❌"
        check_ai_configured && echo "AI: ✅" || echo "AI: ❌"
        echo
        echo "1. View Logs"
        echo "2. Restart"
        echo "3. Rebuild (npm install)"
        echo "4. Create/Update Content Types"
        echo "5. Configure AI Keys"
        echo "6. Test AI Endpoints"
        echo "7. Reindex Embeddings"
        echo "8. API Permissions Help"
        echo "9. Back"
        read -p "Choice: " c
        case $c in
            1) cd "$PROJECT_DIR"; docker-compose logs --tail=100 -f strapi ;;
            2) cd "$PROJECT_DIR"; docker-compose restart strapi; print_success "Restarted"; sleep 2 ;;
            3)
                cd "$PROJECT_DIR"
                print_status "Rebuilding..."
                docker-compose exec strapi sh -c "rm -rf node_modules .cache build && npm install --legacy-peer-deps"
                docker-compose restart strapi
                print_success "Rebuilt"
                read -p "Press Enter..."
                ;;
            4)
                source "$ENV_FILE"
                create_content_types
                create_ai_services
                create_custom_routes
                cd "$PROJECT_DIR"
                docker-compose restart strapi
                print_success "Updated. Strapi restarting..."
                read -p "Press Enter..."
                ;;
            5) configure_ai_keys ;;
            6) test_ai_endpoints ;;
            7) reindex_embeddings ;;
            8)
                clear
                print_header "Strapi API Permissions"
                source "$ENV_FILE"
                echo
                echo "To enable public API access:"
                echo
                echo "1. Go to: https://$STRAPI_URL/admin"
                echo "2. Settings → Users & Permissions → Roles → Public"
                echo "3. Enable for each article type:"
                echo "   • find"
                echo "   • findOne"
                echo "4. Enable for Author:"
                echo "   • find"
                echo "   • findOne"
                echo "5. Enable for Upload:"
                echo "   • find"
                echo "   • findOne"
                echo "6. Enable custom routes (AI & Search):"
                echo "   • ai: generateSeo, generateExcerpt, generateImage, status"
                echo "   • search: semantic, status"
                echo "7. Click SAVE"
                echo
                read -p "Press Enter..."
                ;;
            9) return ;;
        esac
    done
}

# =============================================================================
# MAUTIC MENU
# =============================================================================

mautic_menu() {
    while true; do
        clear
        print_header "Mautic Management"
        source "$ENV_FILE" 2>/dev/null
        [[ -n "$MAUTIC_URL" ]] && echo "URL: https://$MAUTIC_URL"
        echo
        echo "1. View Logs"
        echo "2. Restart"
        echo "3. Fix Vendor (PHP error)"
        echo "4. Clear Cache"
        echo "5. Back"
        read -p "Choice: " c
        case $c in
            1) cd "$PROJECT_DIR"; docker-compose logs --tail=100 -f mautic_web ;;
            2) cd "$PROJECT_DIR"; docker-compose restart mautic_web mautic_cron; print_success "Restarted"; sleep 2 ;;
            3) fix_mautic_vendor ;;
            4)
                cd "$PROJECT_DIR"
                print_status "Clearing cache..."
                docker-compose exec mautic_web php /var/www/html/bin/console cache:clear 2>/dev/null || true
                print_success "Cache cleared"
                read -p "Press Enter..."
                ;;
            5) return ;;
        esac
    done
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_management_menu() {
    while true; do
        clear
        echo -e "${PURPLE}${BOLD}V4 Supercharged Stack${NC} v$SCRIPT_VERSION"
        cd "$PROJECT_DIR" 2>/dev/null
        local containers=$(docker-compose ps -q 2>/dev/null | wc -l)
        echo "Containers: $containers"
        check_strapi_installed && echo "Strapi: ✅" || echo "Strapi: ❌"
        check_ai_configured && echo "AI: ✅" || echo "AI: ❌"
        echo
        echo "1.  Status"
        echo "2.  Start All"
        echo "3.  Stop All"
        echo "4.  Restart All"
        echo "5.  View Logs"
        echo "6.  Backup →"
        echo "7.  Update Images"
        echo "8.  Show Credentials"
        echo "9.  Strapi →"
        echo "10. Mautic →"
        echo "11. Upgrade to V4"
        echo "12. Exit"
        read -p "Choice: " c
        case $c in
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
                print_header "Credentials"
                echo
                echo "🌐 URLs:"
                echo "   Mautic:  https://$MAUTIC_URL"
                echo "   n8n:     https://$N8N_URL"
                [[ -n "$STRAPI_URL" ]] && echo "   Strapi:  https://$STRAPI_URL/admin"
                echo
                echo "🔐 Passwords:"
                echo "   MySQL Root:   $MYSQL_ROOT_PASSWORD"
                echo "   Mautic DB:    $MAUTIC_DB_PASSWORD"
                [[ -n "$POSTGRES_PASSWORD" ]] && echo "   PostgreSQL:   $POSTGRES_PASSWORD"
                echo "   RabbitMQ:     $RABBITMQ_PASSWORD"
                echo "   n8n Key:      $N8N_ENCRYPTION_KEY"
                echo
                echo "🤖 AI Keys:"
                [[ -n "$OPENAI_API_KEY" ]] && echo "   OpenAI:  ${OPENAI_API_KEY:0:10}..." || echo "   OpenAI:  Not set"
                [[ -n "$GEMINI_API_KEY" ]] && echo "   Gemini:  ${GEMINI_API_KEY:0:10}..." || echo "   Gemini:  Not set"
                echo
                read -p "Press Enter..."
                ;;
            9) strapi_menu ;;
            10) mautic_menu ;;
            11)
                if false; then
                    print_warning "Already V4 Supercharged"
                    read -p "Press Enter..."
                else
                    upgrade_to_v4
                fi
                ;;
            12) print_success "Goodbye!"; exit 0 ;;
        esac
    done
}

# =============================================================================
# INSTALLATION
# =============================================================================

run_installation() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║     V4 SUPERCHARGED - AI-Powered Marketing Stack              ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    echo "This will install:"
    echo "  • Traefik (SSL/Reverse Proxy)"
    echo "  • MySQL + PostgreSQL with pgvector"
    echo "  • RabbitMQ"
    echo "  • Mautic (Marketing Automation)"
    echo "  • n8n (Workflow Automation)"
    echo "  • Strapi CMS Supercharged:"
    echo "    - Full SEO fields"
    echo "    - AI Content Generation (Gemini)"
    echo "    - AI Image Generation (DALL-E 3)"
    echo "    - Semantic Search (pgvector)"
    echo "    - 3 Blog types + Author"
    echo
    read -p "Continue? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    
    check_root
    update_system
    install_awscli
    setup_firewall
    install_docker
    install_docker_compose
    get_configuration
    create_directories
    create_env_file
    create_strapi_project
    create_ai_services
    create_content_types
    create_custom_routes
    create_docker_compose
    deploy_stack
    display_deployment_info
    show_management_menu
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    if check_deployment_state; then
        source "$ENV_FILE" 2>/dev/null
        show_management_menu
    else
        run_installation
    fi
}

trap 'echo ""; print_warning "Interrupted"; exit 1' SIGINT SIGTERM
main "$@"
