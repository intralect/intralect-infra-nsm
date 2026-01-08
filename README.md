# Mautic + n8n + Strapi (Supercharged with AI) Infrastructure

A comprehensive Docker-based stack for marketing automation, workflow automation, and AI-powered content management.

## 🚀 Overview

This infrastructure combines three powerful open-source tools:
- **Mautic**: Marketing automation and CRM
- **n8n**: Workflow automation and integration platform
- **Strapi**: Headless CMS supercharged with AI capabilities

The Strapi instance has been enhanced with AI services for automated content generation, SEO optimization, and semantic search.

## ✨ Key Features

### AI-Powered Strapi
- **SEO Optimization**: AI-generated meta titles, descriptions, and Open Graph tags
- **Content Generation**: AI-assisted article excerpts and summaries
- **Image Generation**: DALL-E 3 integration for automatic cover image creation
- **Semantic Search**: pgvector-powered similarity search across articles
- **Multi-AI Support**: OpenAI (GPT-4, DALL-E 3) and Google Gemini integration

### Marketing Automation
- **Mautic**: Lead scoring, email marketing, campaign management
- **n8n**: Connect 300+ services with visual workflow builder
- **Integrated Pipeline**: Seamless data flow between CMS and marketing tools

### Production Ready
- **Dockerized**: Easy deployment with Docker Compose
- **Reverse Proxy**: Traefik for automatic SSL and domain routing
- **Security**: Regular security audits with auto-fix capabilities
- **Scalable**: PostgreSQL database with pgvector for AI embeddings

## 📋 Current Status

### ✅ Completed Features
1. **Strapi V4 Supercharged** installation with AI services
2. **Full SEO fields** added to all content types (meta_title, meta_description, canonical_url, og_image, etc.)
3. **AI API endpoints** for SEO generation, excerpt creation, and image generation
4. **Semantic search** with pgvector extension enabled
5. **Custom API routes** (`/api/ai/*`, `/api/search/*`)
6. **Security audit** system with auto-fix capabilities (v3)
7. **Docker configuration** for all services (Mautic, n8n, Strapi, PostgreSQL, Redis, Traefik)

### ⚠️ Known Issues
1. **Gemini Model Configuration**: The Gemini API returns 404 for the model name. Need to test with:
   - `gemini-1.5-flash`
   - `gemini-1.5-pro`
   - `gemini-1.5-flash-001`
2. **Admin UI Integration**: AI buttons need to be added to the Strapi content editor
3. **Public Permissions**: Strapi public role permissions need configuration for AI endpoints

### 🔧 Pending Tasks
1. Fix Gemini model configuration
2. Create Strapi admin UI extension for AI tools
3. Configure public permissions for AI endpoints
4. Data migration from old SEO fields to new ones

## 🛠️ Quick Start

### Prerequisites
- Docker and Docker Compose
- Git
- Domain names (or localhost setup)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/intralect/mautic-n8n-infra.git
   cd mautic-n8n-infra
   ```

2. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Set up AI API keys** (in `.env`)
   ```bash
   OPENAI_API_KEY=sk-your-openai-key
   GEMINI_API_KEY=your-gemini-key
   ```

4. **Start the stack**
   ```bash
   docker-compose up -d
   ```

5. **Run the V4 upgrade** (if upgrading from older version)
   ```bash
   chmod +x ../scripts/v4_fixed_upgrade.sh
   ../scripts/v4_fixed_upgrade.sh
   ```

## 🌐 Access URLs

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Mautic | https://m.yaicos.com | admin / (check .env) |
| n8n | https://n8n.yaicos.com | admin@example.com / password |
| Strapi Admin | https://cms.yaicos.com/admin | (First-time setup) |
| Strapi API | https://cms.yaicos.com/api | Public endpoints |

## 🤖 AI API Endpoints

### AI Status
```bash
GET /api/ai/status
```
Returns: `{"gemini": true, "openai": true, "semanticSearch": true}`

### Generate SEO Metadata
```bash
POST /api/ai/generate-seo
Content-Type: application/json

{
  "title": "Article Title",
  "content": "Article content here..."
}
```

### Generate Excerpt
```bash
POST /api/ai/generate-excerpt
Content-Type: application/json

{
  "content": "Full article content...",
  "maxLength": 300
}
```

### Generate Cover Image
```bash
POST /api/ai/generate-image
Content-Type: application/json

{
  "title": "Article Title",
  "content": "Article content...",
  "brand": {
    "style": "modern, professional",
    "colors": "blue and white",
    "avoid": "text, logos, faces"
  }
}
```

### Semantic Search
```bash
POST /api/search/semantic
Content-Type: application/json

{
  "query": "cybersecurity best practices",
  "collection": "guardscan_articles",
  "limit": 5
}
```

## 🔧 Development

### Project Structure
```
mautic-n8n-stack/
├── docker-compose.yml          # Main Docker Compose file
├── .env.example               # Example environment variables
├── scripts/                   # Utility scripts
│   ├── v4_fixed_upgrade.sh    # Strapi V4 upgrade script
│   └── security_audit_v3.sh   # Security audit with auto-fix
├── strapi/                    # Strapi project
│   ├── src/
│   │   ├── services/          # AI services (gemini.js, openai.js)
│   │   └── api/               # Custom API routes
│   └── config/                # Strapi configuration
└── README.md                  # This file
```

### Adding New AI Features

1. **Create a new service** in `strapi/src/services/`
2. **Add API route** in `strapi/src/api/`
3. **Test the endpoint** with curl or Postman
4. **Add to admin UI** (optional)

### Security Audit
Run the security audit script to check for vulnerabilities:
```bash
./scripts/security_audit_v3.sh
```

Apply automatic fixes:
```bash
./scripts/security_audit_v3.sh --fix
```

## 📊 Database Schema

### Strapi Content Types
- **guardscan-article**: Articles for guardscan.io
- **yaicos-article**: Articles for yaicos.com
- **amabex-article**: Articles for ambaex.com
- **author**: Article authors

### AI Embeddings
- **pgvector extension** enabled for semantic search
- **Article embeddings** stored in PostgreSQL
- **Similarity search** via cosine distance

## 🔐 Security

- All `.env` files are excluded from Git
- Docker socket permissions are secured
- UFW firewall configuration included
- Fail2ban for intrusion prevention
- Regular security updates with unattended-upgrades

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run security audit: `./scripts/security_audit_v3.sh`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- [Strapi](https://strapi.io/) for the amazing headless CMS
- [OpenAI](https://openai.com/) for GPT-4 and DALL-E 3
- [Google Gemini](https://deepmind.google/technologies/gemini/) for AI models
- [Mautic](https://www.mautic.org/) for marketing automation
- [n8n](https://n8n.io/) for workflow automation

## 📞 Support

For issues and feature requests, please open an issue on GitHub.

---

**Last Updated**: December 2024  
**Version**: V4 Supercharged  
**Status**: Active Development
