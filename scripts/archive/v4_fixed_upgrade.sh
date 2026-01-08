#!/bin/bash

# =============================================================================
# V4 Fixed Upgrade Script
# Safe upgrade to V4 Supercharged without destroying existing data
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/mautic-n8n-stack"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/.env"
STRAPI_DIR="$PROJECT_DIR/strapi"
BACKUP_DIR="$PROJECT_DIR/backups/2025-12-02_12-23-08"
STRAPI_BACKUP_DIR="$PROJECT_DIR/strapi.pre-v4.backup"

# Print functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${PURPLE}${BOLD}[V4 FIXED]${NC} $1"; }
print_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Check functions
check_strapi_content_types() { [[ -d "$STRAPI_DIR/src/api/guardscan-article" ]]; }
check_ai_services() { [[ -f "$STRAPI_DIR/src/services/openai.js" ]]; }
check_custom_routes() { [[ -d "$STRAPI_DIR/src/api/ai" ]]; }

generate_password() { openssl rand -base64 "${1:-32}" | tr -d "=+/" | cut -c1-"${1:-32}"; }

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

# =============================================================================
# MAIN UPGRADE FUNCTION
# =============================================================================

upgrade_to_v4_fixed() {
    print_header "Starting V4 Fixed Upgrade"
    echo
    
    # Step 1: Check prerequisites
    print_step "1. Checking prerequisites..."
    if [[ ! -d "$PROJECT_DIR" ]]; then
        print_error "Project directory not found: $PROJECT_DIR"
        return 1
    fi
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        print_error "Docker compose file not found: $COMPOSE_FILE"
        return 1
    fi
    
    if [[ ! -d "$STRAPI_DIR" ]]; then
        print_error "Strapi directory not found: $STRAPI_DIR"
        return 1
    fi
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_error "Backup directory not found: $BACKUP_DIR"
        return 1
    fi
    
    if [[ ! -d "$STRAPI_BACKUP_DIR" ]]; then
        print_error "Strapi backup directory not found: $STRAPI_BACKUP_DIR"
        return 1
    fi
    
    source "$ENV_FILE" 2>/dev/null || {
        print_error "Could not load environment file"
        return 1
    }
    
    # Step 2: Backup current state
    print_step "2. Backing up current state..."
    local ts=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$PROJECT_DIR/backups/pre_upgrade_$ts"
    mkdir -p "$backup_dir"
    
    # Backup database
    print_status "Backing up PostgreSQL database..."
    docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_dump -U strapi strapi > "$backup_dir/postgres.sql" 2>/dev/null || {
        print_warning "Could not backup PostgreSQL, continuing..."
    }
    
    # Backup Strapi project
    print_status "Backing up Strapi project..."
    tar czf "$backup_dir/strapi.tar.gz" -C "$PROJECT_DIR" strapi --exclude='strapi/node_modules' --exclude='strapi/.cache' --exclude='strapi/build' 2>/dev/null || {
        print_warning "Could not backup Strapi project, continuing..."
    }
    
    print_success "Backup created at $backup_dir"
    
    # Step 3: Stop Strapi container
    print_step "3. Stopping Strapi container..."
    cd "$PROJECT_DIR"
    docker-compose stop strapi 2>/dev/null || true
    sleep 5
    
    # Step 4: Restore content types from backup if missing
    print_step "4. Restoring content types from backup..."
    if ! check_strapi_content_types; then
        print_status "Content types missing, restoring from backup..."
        cp -r "$STRAPI_BACKUP_DIR/src/api/"* "$STRAPI_DIR/src/api/"
        print_success "Content types restored"
    else
        print_status "Content types already exist, skipping restore"
    fi
    
    # Step 5: Update package.json with AI dependencies
    print_step "5. Updating package.json with AI dependencies..."
    local package_file="$STRAPI_DIR/package.json"
    if [[ -f "$package_file" ]]; then
        # Check if AI dependencies are already present
        if ! grep -q '"openai"' "$package_file"; then
            print_status "Adding AI dependencies to package.json..."
            # Use jq to add dependencies if available, else use sed
            if command -v jq >/dev/null 2>&1; then
                jq '.dependencies += {
                    "openai": "^4.20.0",
                    "@google/generative-ai": "^0.2.0",
                    "pgvector": "^0.1.8",
                    "uuid": "^9.0.0",
                    "slugify": "^1.6.6"
                }' "$package_file" > "$package_file.tmp" && mv "$package_file.tmp" "$package_file"
            else
                print_warning "jq not available, using sed to update package.json"
                # This is a fragile fallback, but better than nothing
                sed -i '/"dependencies"/,/}/ s/"}/"openai": "^4.20.0", "@google/generative-ai": "^0.2.0", "pgvector": "^0.1.8", "uuid": "^9.0.0", "slugify": "^1.6.6", "}/' "$package_file" 2>/dev/null || {
                    print_warning "Could not update package.json with sed, you may need to manually add dependencies"
                }
            fi
            print_success "Package.json updated"
        else
            print_status "AI dependencies already present in package.json"
        fi
    else
        print_error "package.json not found"
        return 1
    fi
    
    # Step 6: Create AI services
    print_step "6. Creating AI services..."
    if ! check_ai_services; then
        print_status "Creating AI service files..."
        mkdir -p "$STRAPI_DIR/src/services"
        
        # OpenAI Service
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
  
  isConfigured() {
    return !!process.env.OPENAI_API_KEY;
  },
};
EOFJS

        # Gemini Service
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
  async search(query, collection, limit = 10) {
    if (!openaiService.isConfigured()) {
      throw new Error('Semantic search requires OpenAI API key');
    }
    
    const queryEmbedding = await openaiService.generateEmbedding(query);
    
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
  
  isEnabled() {
    return process.env.ENABLE_SEMANTIC_SEARCH === 'true' && openaiService.isConfigured();
  },
};
EOFJS

        print_success "AI services created"
    else
        print_status "AI services already exist"
    fi
    
    # Step 7: Create custom API routes
    print_step "7. Creating custom API routes..."
    if ! check_custom_routes; then
        print_status "Creating custom API routes..."
        
        # AI routes
        mkdir -p "$STRAPI_DIR/src/api/ai/controllers"
        mkdir -p "$STRAPI_DIR/src/api/ai/routes"
        mkdir -p "$STRAPI_DIR/src/api/search/controllers"
        mkdir -p "$STRAPI_DIR/src/api/search/routes"
        
        # AI Controller
        cat > "$STRAPI_DIR/src/api/ai/controllers/ai.js" << 'EOFJS'
'use strict';

module.exports = {
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
      
      const prompt = await gemini.generateImagePrompt(title, content || '', brand || {});
      
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
        auth: false,
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
    else
        print_status "Custom API routes already exist"
    fi
    
    # Step 8: Update content type schemas with full SEO fields
    print_step "8. Updating content type schemas with full SEO fields..."
    
    # List of article content types
    local article_types=("guardscan-article" "yaicos-article" "amabex-article")
    
    for article_type in "${article_types[@]}"; do
        local schema_file="$STRAPI_DIR/src/api/$article_type/content-types/$article_type/schema.json"
        
        if [[ -f "$schema_file" ]]; then
            print_status "Updating $article_type schema..."
            
            # Use jq to update the schema if available
            if command -v jq >/dev/null 2>&1; then
                # Check if meta_title already exists (new schema)
                if ! jq '.attributes | has("meta_title")' "$schema_file" 2>/dev/null | grep -q true; then
                    print_status "Adding full SEO fields to $article_type..."
                    
                    # First, rename seo_title to meta_title and seo_description to meta_description if they exist
                    if jq '.attributes | has("seo_title")' "$schema_file" 2>/dev/null | grep -q true; then
                        jq '.attributes |= with_entries(if .key == "seo_title" then .key = "meta_title" else . end)' "$schema_file" > "$schema_file.tmp" && mv "$schema_file.tmp" "$schema_file"
                        jq '.attributes |= with_entries(if .key == "seo_description" then .key = "meta_description" else . end)' "$schema_file" > "$schema_file.tmp" && mv "$schema_file.tmp" "$schema_file"
                    fi
                    
                    # Add new SEO and AI fields
                    jq '.attributes += {
                        "meta_title": { "type": "string", "maxLength": 60 },
                        "meta_description": { "type": "text", "maxLength": 160 },
                        "canonical_url": { "type": "string" },
                        "og_image": { "type": "media", "multiple": false, "allowedTypes": ["images"] },
                        "og_image_alt": { "type": "string", "maxLength": 125 },
                        "og_image_width": { "type": "integer", "default": 1200 },
                        "og_image_height": { "type": "integer", "default": 630 },
                        "no_index": { "type": "boolean", "default": false },
                        "embedding": { "type": "json" },
                        "ai_generated": { "type": "boolean", "default": false }
                    }' "$schema_file" > "$schema_file.tmp" && mv "$schema_file.tmp" "$schema_file"
                    
                    print_success "Updated $article_type schema"
                else
                    print_status "$article_type already has new schema fields"
                fi
            else
                print_warning "jq not available, cannot update schema for $article_type automatically"
                print_warning "Please manually update $schema_file with the new SEO fields"
            fi
        else
            print_warning "Schema file not found: $schema_file"
        fi
    done
    
    # Step 9: Update environment variables for AI
    print_step "9. Updating environment variables for AI..."
    if ! grep -q "^OPENAI_API_KEY=" "$ENV_FILE"; then
        print_status "Adding AI environment variables..."
        echo "" >> "$ENV_FILE"
        echo "# AI Configuration" >> "$ENV_FILE"
        echo "OPENAI_API_KEY=" >> "$ENV_FILE"
        echo "GEMINI_API_KEY=" >> "$ENV_FILE"
        echo "ENABLE_SEMANTIC_SEARCH=false" >> "$ENV_FILE"
        print_success "AI environment variables added"
    fi
    
    # Step 10: Install dependencies and restart
    print_step "10. Installing dependencies and restarting Strapi..."
    
    print_status "Installing dependencies (this may take a few minutes)..."
    docker-compose run --rm strapi npm install --legacy-peer-deps 2>/dev/null || {
        print_warning "npm install failed, trying inside container..."
        docker-compose exec strapi npm install --legacy-peer-deps 2>/dev/null || true
    }
    
    print_status "Starting Strapi..."
    docker-compose up -d strapi
    
    # Wait for Strapi to start
    wait_for_strapi || {
        print_warning "Strapi taking longer than expected to start"
    }
    
    # Step 11: Enable pgvector extension
    print_step "11. Enabling pgvector extension..."
    docker-compose exec -T postgres psql -U strapi -d strapi -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || {
        print_warning "Failed to enable pgvector extension"
    }
    
    print_header "V4 Fixed Upgrade Complete!"
    echo
    echo "Next steps:"
    echo "1. Configure AI keys in $ENV_FILE"
    echo "2. Restart Strapi: docker-compose restart strapi"
    echo "3. Set up public permissions in Strapi admin"
    echo "4. Test AI endpoints: curl https://$STRAPI_URL/api/ai/status"
    echo
    print_success "Your Strapi is now supercharged with AI and full SEO!"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    print_header "V4 Fixed Upgrade Script"
    echo
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root"
    fi
    
    # Check if docker is available
    if ! command -v docker &>/dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose &>/dev/null; then
        print_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    # Run the upgrade
    upgrade_to_v4_fixed
    
    if [[ $? -eq 0 ]]; then
        print_success "Upgrade completed successfully!"
    else
        print_error "Upgrade failed"
        exit 1
    fi
}

trap 'echo ""; print_warning "Interrupted"; exit 1' SIGINT SIGTERM
main "$@"
