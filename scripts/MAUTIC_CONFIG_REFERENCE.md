# 🔒 PRODUCTION MAUTIC CONFIGURATION REFERENCE
## DO NOT MODIFY - This configuration is production-tested

**Date:** January 6, 2026
**Source:** /root/scripts/mautic-n8n-stack/docker-compose.yml

---

## ⚠️ CRITICAL: These settings took significant effort to configure correctly

### Mautic Web Service
```yaml
mautic_web:
  image: mautic/mautic:5-apache          # ← EXACT VERSION
  container_name: mautic-web
  restart: unless-stopped

  depends_on:
    mysql:
      condition: service_healthy         # ← MUST wait for MySQL
    rabbitmq:
      condition: service_healthy         # ← MUST wait for RabbitMQ

  environment:
    - MAUTIC_DB_HOST=mysql               # ← Internal hostname
    - MAUTIC_DB_USER=mautic
    - MAUTIC_DB_PASSWORD=${MAUTIC_DB_PASSWORD}
    - MAUTIC_DB_NAME=mautic
    - MAUTIC_MESSENGER_TRANSPORT_DSN=amqp://mautic:${RABBITMQ_PASSWORD}@rabbitmq:5672/%2f/messages
    - DOCKER_MAUTIC_RUN_MIGRATIONS=true  # ← Auto migrations

  volumes:                                # ← PRESERVE ALL VOLUMES
    - mautic_data_config:/var/www/html/config
    - mautic_data_logs:/var/www/html/var/logs
    - mautic_data_media_files:/var/www/html/media/files
    - mautic_data_media_images:/var/www/html/media/images
    - mautic_data_plugins:/var/www/html/plugins
    - mautic_data_vendor:/var/www/html/vendor
```

### Mautic Cron Service
```yaml
mautic_cron:
  image: mautic/mautic:5-apache          # ← SAME IMAGE as web
  container_name: mautic-cron
  restart: unless-stopped

  depends_on:
    - mautic_web                         # ← Wait for web service

  environment:                            # ← SAME DB config as web
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
```

### MySQL Configuration
```yaml
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

  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
    interval: 30s
    timeout: 10s
    retries: 5
```

### RabbitMQ Configuration
```yaml
rabbitmq:
  image: rabbitmq:3.12-management-alpine
  container_name: mautic-rabbitmq
  restart: unless-stopped

  environment:
    RABBITMQ_DEFAULT_USER: mautic
    RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD}

  volumes:
    - rabbitmq_data:/var/lib/rabbitmq

  healthcheck:
    test: ["CMD", "rabbitmq-diagnostics", "ping"]
    interval: 30s
    timeout: 10s
    retries: 5
```

### Environment Variables (from .env)
```bash
MAUTIC_URL=m.yaicos.com
MYSQL_ROOT_PASSWORD=K2oy8MD3clMhRNjAgleF72Z2QlRzk0Ik
MAUTIC_DB_PASSWORD=V0pJcUk8E03zgxXlgyrx9xrpoq9zMC3Z
RABBITMQ_PASSWORD=3RBC3qfu6SEDlKk9SQOG4ZXU
```

---

## ✅ What V5 Will Preserve

1. **Exact same Mautic image version** (`mautic/mautic:5-apache`)
2. **All environment variables** (database, messaging)
3. **All Docker volumes** (configuration, media, plugins, vendor)
4. **Cron job command** (exact same tasks and timing)
5. **MySQL configuration** (authentication, buffer pool)
6. **RabbitMQ setup** (user, password, queue)
7. **Health checks** (dependency waiting)
8. **Network** (mautic_network bridge)

## 🆕 What V5 Will Add (Without Touching Mautic)

1. **Strapi in production mode** (NODE_ENV=production)
2. **Monitoring stack** (Prometheus, Grafana)
3. **Automated backups** (including Mautic data)
4. **Swap space** (4GB)
5. **Log rotation**
6. **Enhanced AI services** (for Strapi only)
7. **Individual service updates** (update n8n without touching Mautic)

---

**IMPORTANT:** Any V5 migration script MUST:
- ✅ Use EXACT same Mautic configuration
- ✅ Preserve ALL Mautic volumes
- ✅ Keep same environment variables
- ✅ Not modify Mautic containers during migration
- ✅ Backup Mautic data before any changes

---

*Last Updated: January 6, 2026*
*Protected Configuration - Do Not Modify*
