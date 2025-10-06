# 🚀 ROTA AKADEMİ - PRODUCTION DEPLOYMENT GUIDE

## ⚠️ **KRİTİK UYARILAR**
- Bu deployment **PRODUCTION** ortamı için hazırlanmıştır
- **MUTLAKA BACKUP** alın
- **STAGING** ortamında test edin
- **ROLLBACK PLANI** hazırlayın

## 📋 **DEPLOYMENT CHECKLIST**

### **1. ÖN HAZIRLIK**
- [ ] Backup alındı
- [ ] Staging test edildi
- [ ] Environment variables hazırlandı
- [ ] SSL sertifikaları hazır
- [ ] Domain DNS ayarları yapıldı

### **2. PRODUCTION ENVIRONMENT CONFIG**

#### **A) .env.production Dosyası**
```bash
# Application Configuration
APP_NAME="Rota Akademi"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://api.rotaakademi.com

# Database (Cloud SQL PostgreSQL)
DB_CONNECTION=pgsql
DB_HOST=/cloudsql/your-project:europe-west1:nazliyavuz-db
DB_DATABASE=nazliyavuz_production
DB_USERNAME=nazliyavuz_user
DB_PASSWORD=secure_production_password_2025

# Redis (Cloud Memorystore)
REDIS_HOST=10.0.0.3
REDIS_PASSWORD=redis_production_password

# Mail (Production SMTP)
MAIL_FROM_ADDRESS=noreply@rotaakademi.com
MAIL_FROM_NAME="Rota Akademi"

# Security
SESSION_ENCRYPT=true
SESSION_DOMAIN=.rotaakademi.com
CORS_ALLOWED_ORIGINS=https://rotaakademi.com,https://app.rotaakademi.com
```

#### **B) Google Cloud Run Configuration**
```yaml
# cloud-run-config.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: nazliyavuz-backend
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/execution-environment: gen2
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/cpu-throttling: "false"
        autoscaling.knative.dev/maxScale: "10"
        autoscaling.knative.dev/minScale: "1"
    spec:
      containerConcurrency: 100
      timeoutSeconds: 300
      containers:
      - image: gcr.io/your-project/nazliyavuz-backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: APP_ENV
          value: "production"
        - name: DB_HOST
          value: "/cloudsql/your-project:europe-west1:nazliyavuz-db"
        resources:
          limits:
            cpu: "2"
            memory: "2Gi"
          requests:
            cpu: "1"
            memory: "1Gi"
```

## 🛠️ **DEPLOYMENT STEPS**

### **Step 1: Pre-Deployment Setup**
```bash
# 1. Backup al
php artisan backup:run

# 2. Maintenance mode aktif et
php artisan down --message="Production deployment yapılıyor"

# 3. Cache temizle
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear
```

### **Step 2: Docker Build (Production)**
```bash
# Production Dockerfile
FROM php:8.3-fpm-alpine

# Install dependencies
RUN apk add --no-cache \
    nginx \
    postgresql-client \
    redis \
    supervisor \
    && docker-php-ext-install pdo pdo_pgsql opcache

# Copy application
COPY . /var/www/html
WORKDIR /var/www/html

# Install Composer dependencies
RUN composer install --optimize-autoloader --no-dev

# Set permissions
RUN chown -R www-data:www-data /var/www/html/storage
RUN chmod -R 755 /var/www/html/storage

# Copy production configs
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/php.ini /usr/local/etc/php/php.ini
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose port
EXPOSE 8000

# Start services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
```

### **Step 3: Google Cloud Build**
```bash
# Build image
gcloud builds submit --tag gcr.io/your-project/nazliyavuz-backend:latest ./backend

# Test locally
docker run --rm -p 8000:8000 gcr.io/your-project/nazliyavuz-backend:latest
```

### **Step 4: Cloud Run Deploy**
```bash
# Deploy to Cloud Run
gcloud run deploy nazliyavuz-backend \
  --image gcr.io/your-project/nazliyavuz-backend:latest \
  --platform managed \
  --region europe-west1 \
  --allow-unauthenticated \
  --memory 2Gi \
  --cpu 2 \
  --max-instances 10 \
  --min-instances 1 \
  --port 8000 \
  --set-env-vars APP_ENV=production \
  --add-cloudsql-instances your-project:europe-west1:nazliyavuz-db
```

### **Step 5: Database Migration**
```bash
# Connect to Cloud Run and run migrations
gcloud run services proxy nazliyavuz-backend --port=8080

# In another terminal
curl -X POST https://your-cloud-run-url/api/v1/migrate
```

### **Step 6: Health Checks**
```bash
# API Health Check
curl -f https://your-cloud-run-url/health

# Database Health Check
curl -f https://your-cloud-run-url/health/detailed

# Performance Check
curl -f https://your-cloud-run-url/api/v1/teachers
```

## 🔧 **POST-DEPLOYMENT TASKS**

### **1. Domain Configuration**
```bash
# Custom domain setup
gcloud run domain-mappings create \
  --service nazliyavuz-backend \
  --domain api.rotaakademi.com \
  --region europe-west1
```

### **2. SSL Certificate**
```bash
# SSL certificate (automatic with Cloud Run)
# No additional configuration needed
```

### **3. Monitoring Setup**
```bash
# Enable Cloud Monitoring
gcloud services enable monitoring.googleapis.com

# Set up alerts
gcloud alpha monitoring policies create --policy-from-file=monitoring-policy.yaml
```

## 📊 **MONITORING & ALERTS**

### **Key Metrics to Monitor:**
- Response time < 200ms
- Error rate < 1%
- CPU usage < 80%
- Memory usage < 80%
- Database connections < 80%

### **Alert Configuration:**
```yaml
# monitoring-policy.yaml
displayName: "Nazliyavuz Backend Alerts"
conditions:
- displayName: "High Error Rate"
  conditionThreshold:
    filter: 'resource.type="cloud_run_revision"'
    comparison: COMPARISON_GREATER_THAN
    thresholdValue: 0.05
    duration: 300s
```

## 🚨 **ROLLBACK PLAN**

### **If Issues Occur:**
```bash
# 1. Maintenance mode
gcloud run services update nazliyavuz-backend --region europe-west1 --set-env-vars MAINTENANCE_MODE=true

# 2. Rollback to previous version
gcloud run services update-traffic nazliyavuz-backend --to-revisions=REVISION_NAME=100

# 3. Database rollback (if needed)
gcloud sql instances patch nazliyavuz-db --backup-start-time=HH:MM
```

## ✅ **SUCCESS CRITERIA**

- [ ] API responds in < 200ms
- [ ] All endpoints return 200/201
- [ ] Database connections stable
- [ ] SSL certificate valid
- [ ] Monitoring alerts configured
- [ ] Backup strategy implemented

## 📞 **EMERGENCY CONTACTS**

- **DevOps Engineer:** [Contact Info]
- **Backend Developer:** [Contact Info]
- **Project Manager:** [Contact Info]

---

**⚠️ Bu deployment'ı production'da çalıştırmadan önce staging environment'ta test edin!**
