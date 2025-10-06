# Nazliyavuz Platform - Production Deployment Guide

## Overview
Bu dokümantasyon, Nazliyavuz Platform'un production ortamında güvenli ve ölçeklenebilir bir şekilde deploy edilmesi için gereken adımları içerir.

## Sistem Gereksinimleri

### Minimum Gereksinimler
- **CPU**: 4 cores
- **RAM**: 8GB
- **Disk**: 100GB SSD
- **Network**: 1Gbps

### Önerilen Gereksinimler
- **CPU**: 8 cores
- **RAM**: 16GB
- **Disk**: 500GB SSD
- **Network**: 10Gbps

### Yazılım Gereksinimleri
- Docker 20.10+
- Docker Compose 2.0+
- Git 2.30+
- Nginx (reverse proxy için)

## Production Ortamı Kurulumu

### 1. Sunucu Hazırlığı

```bash
# Sistem güncellemesi
sudo apt update && sudo apt upgrade -y

# Gerekli paketlerin kurulumu
sudo apt install -y curl wget git nginx ufw fail2ban

# Docker kurulumu
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Docker Compose kurulumu
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2. Güvenlik Yapılandırması

```bash
# Firewall yapılandırması
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

# Fail2ban yapılandırması
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 3. SSL Sertifikası

```bash
# Certbot kurulumu
sudo apt install -y certbot python3-certbot-nginx

# Let's Encrypt sertifikası
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### 4. Nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/nazliyavuz
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # SSL yapılandırması
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

    # API endpoints
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Login endpoint
    location /api/auth/login {
        limit_req zone=login burst=5 nodelay;
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static files
    location /storage/ {
        alias /var/www/nazliyavuz-platform/backend/storage/app/public/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Health check
    location /health {
        proxy_pass http://localhost:8000;
        access_log off;
    }
}
```

## Deployment Süreci

### 1. Kod Çekme ve Hazırlık

```bash
# Proje dizini
cd /var/www
sudo git clone https://github.com/yourusername/nazliyavuz-platform.git
sudo chown -R www-data:www-data nazliyavuz-platform
cd nazliyavuz-platform

# Environment dosyası
sudo cp .env.example .env
sudo nano .env
```

### 2. Production Environment Yapılandırması

```env
# .env
APP_NAME="Nazliyavuz Platform"
APP_ENV=production
APP_KEY=base64:your-generated-key
APP_DEBUG=false
APP_URL=https://yourdomain.com

# Database
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=nazliyavuz_platform
DB_USERNAME=nazliyavuz_user
DB_PASSWORD=your-secure-password

# Redis
REDIS_HOST=redis
REDIS_PASSWORD=your-redis-password
REDIS_PORT=6379

# Cache
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Mail
MAIL_MAILER=smtp
MAIL_HOST=your-smtp-host
MAIL_PORT=587
MAIL_USERNAME=your-email
MAIL_PASSWORD=your-password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@yourdomain.com

# Pusher (Real-time)
PUSHER_APP_ID=your-pusher-app-id
PUSHER_APP_KEY=your-pusher-key
PUSHER_APP_SECRET=your-pusher-secret
PUSHER_APP_CLUSTER=eu

# Monitoring
SENTRY_LARAVEL_DSN=your-sentry-dsn
```

### 3. Docker Compose Production

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  app:
    build:
      context: ./backend
      dockerfile: Dockerfile.prod
    container_name: nazliyavuz_app
    restart: unless-stopped
    working_dir: /var/www
    volumes:
      - ./backend:/var/www
      - ./backend/storage:/var/www/storage
    networks:
      - nazliyavuz_network
    depends_on:
      - postgres
      - redis
    environment:
      - APP_ENV=production
    command: php-fpm

  nginx:
    build:
      context: ./nginx
      dockerfile: Dockerfile
    container_name: nazliyavuz_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./backend:/var/www
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - /etc/letsencrypt:/etc/letsencrypt
    depends_on:
      - app
    networks:
      - nazliyavuz_network

  postgres:
    image: postgres:15-alpine
    container_name: nazliyavuz_postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: nazliyavuz_platform
      POSTGRES_USER: nazliyavuz_user
      POSTGRES_PASSWORD: your-secure-password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - nazliyavuz_network

  redis:
    image: redis:7-alpine
    container_name: nazliyavuz_redis
    restart: unless-stopped
    command: redis-server --requirepass your-redis-password
    volumes:
      - redis_data:/data
    networks:
      - nazliyavuz_network

  queue:
    build:
      context: ./backend
      dockerfile: Dockerfile.prod
    container_name: nazliyavuz_queue
    restart: unless-stopped
    working_dir: /var/www
    volumes:
      - ./backend:/var/www
    depends_on:
      - postgres
      - redis
    command: php artisan queue:work --verbose --tries=3 --timeout=90
    networks:
      - nazliyavuz_network

  scheduler:
    build:
      context: ./backend
      dockerfile: Dockerfile.prod
    container_name: nazliyavuz_scheduler
    restart: unless-stopped
    working_dir: /var/www
    volumes:
      - ./backend:/var/www
    depends_on:
      - postgres
      - redis
    command: php artisan schedule:work
    networks:
      - nazliyavuz_network

  prometheus:
    image: prom/prometheus:latest
    container_name: nazliyavuz_prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    networks:
      - nazliyavuz_network

  grafana:
    image: grafana/grafana:latest
    container_name: nazliyavuz_grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=your-grafana-password
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - nazliyavuz_network

volumes:
  postgres_data:
  redis_data:
  prometheus_data:
  grafana_data:

networks:
  nazliyavuz_network:
    driver: bridge
```

### 4. Deployment Script Kullanımı

```bash
# Deployment script'ini çalıştırma
./deploy.sh production

# Staging ortamına deploy
./deploy.sh staging

# Rollback
./deploy.sh production rollback

# Service durumu kontrolü
./deploy.sh production status

# Logları görüntüleme
./deploy.sh production logs

# Health check
./deploy.sh production health
```

## Monitoring ve Logging

### 1. Prometheus Yapılandırması

```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'laravel-app'
    static_configs:
      - targets: ['app:8000']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis:6379']

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:80']
```

### 2. Log Rotation

```bash
# /etc/logrotate.d/nazliyavuz
/var/www/nazliyavuz-platform/storage/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        docker-compose -f /var/www/nazliyavuz-platform/docker-compose.prod.yml restart app
    endscript
}
```

### 3. Backup Stratejisi

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/var/backups/nazliyavuz"
DATE=$(date +%Y%m%d_%H%M%S)

# Database backup
docker-compose exec -T postgres pg_dump -U nazliyavuz_user nazliyavuz_platform > "$BACKUP_DIR/db_$DATE.sql"

# Storage backup
tar -czf "$BACKUP_DIR/storage_$DATE.tar.gz" storage/

# Keep only last 30 days
find "$BACKUP_DIR" -name "*.sql" -mtime +30 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete
```

## Performance Optimizasyonu

### 1. PHP-FPM Yapılandırması

```ini
; /usr/local/etc/php-fpm.d/www.conf
[www]
user = www-data
group = www-data
listen = 127.0.0.1:9000
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 1000
```

### 2. PostgreSQL Optimizasyonu

```sql
-- postgres/postgresql.conf
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
```

### 3. Redis Optimizasyonu

```conf
# redis/redis.conf
maxmemory 512mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
```

## Güvenlik Kontrolleri

### 1. Regular Security Updates

```bash
#!/bin/bash
# security-update.sh

# System updates
sudo apt update && sudo apt upgrade -y

# Docker image updates
docker-compose pull
docker-compose up -d

# Dependency updates
cd backend && composer update --no-dev
cd ../frontend && npm update
```

### 2. Security Monitoring

```bash
# Fail2ban status
sudo fail2ban-client status

# Check for failed login attempts
sudo grep "Failed password" /var/log/auth.log | tail -20

# Monitor system resources
htop
iostat 1
```

## Troubleshooting

### 1. Common Issues

**Database Connection Issues:**
```bash
# Check database status
docker-compose exec postgres pg_isready

# Check logs
docker-compose logs postgres
```

**Redis Connection Issues:**
```bash
# Test Redis connection
docker-compose exec redis redis-cli ping

# Check Redis memory
docker-compose exec redis redis-cli info memory
```

**Application Issues:**
```bash
# Check application logs
docker-compose logs app

# Check queue status
docker-compose exec app php artisan queue:monitor

# Clear caches
docker-compose exec app php artisan cache:clear
```

### 2. Performance Issues

**High Memory Usage:**
```bash
# Check memory usage
docker stats

# Restart services
docker-compose restart app queue
```

**Slow Database Queries:**
```bash
# Enable query logging
docker-compose exec postgres psql -U nazliyavuz_user -d nazliyavuz_platform -c "SET log_statement = 'all';"

# Check slow queries
docker-compose exec postgres psql -U nazliyavuz_user -d nazliyavuz_platform -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
```

## Maintenance

### 1. Daily Tasks

```bash
#!/bin/bash
# daily-maintenance.sh

# Check service health
./deploy.sh production health

# Monitor disk space
df -h

# Check log files
docker-compose logs --tail=100 app
```

### 2. Weekly Tasks

```bash
#!/bin/bash
# weekly-maintenance.sh

# Database maintenance
docker-compose exec postgres psql -U nazliyavuz_user -d nazliyavuz_platform -c "VACUUM ANALYZE;"

# Clear old logs
find /var/www/nazliyavuz-platform/storage/logs -name "*.log" -mtime +7 -delete

# Update dependencies
cd backend && composer update --no-dev
cd ../frontend && npm update
```

### 3. Monthly Tasks

```bash
#!/bin/bash
# monthly-maintenance.sh

# Full system backup
./backup.sh

# Security updates
./security-update.sh

# Performance analysis
docker-compose exec app php artisan performance:analyze
```

## Disaster Recovery

### 1. Backup Restoration

```bash
# Restore database
docker-compose exec -T postgres psql -U nazliyavuz_user -d nazliyavuz_platform < backup.sql

# Restore storage
tar -xzf storage_backup.tar.gz

# Restart services
docker-compose restart
```

### 2. Failover Procedures

```bash
# Switch to backup server
# Update DNS records
# Restore from backup
# Verify functionality
```

Bu deployment guide'ı takip ederek, Nazliyavuz Platform'u production ortamında güvenli ve ölçeklenebilir bir şekilde çalıştırabilirsiniz.
