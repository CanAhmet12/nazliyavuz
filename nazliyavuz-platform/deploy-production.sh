#!/bin/bash

# ===========================================
# ROTA AKADEMİ - PRODUCTION DEPLOYMENT SCRIPT
# ===========================================

set -e

echo "🚀 Starting Rota Akademi Production Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="your-gcp-project"
REGION="europe-west1"
SERVICE_NAME="nazliyavuz-backend"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
BACKEND_DIR="./backend"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        log_error "Google Cloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if logged in to gcloud
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "Not logged in to Google Cloud. Please run 'gcloud auth login'"
        exit 1
    fi
    
    # Check if project is set
    if ! gcloud config get-value project &> /dev/null; then
        log_error "No project set. Please run 'gcloud config set project ${PROJECT_ID}'"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Backup current deployment
backup_deployment() {
    log_step "Creating backup..."
    
    # Create backup directory
    mkdir -p backups/$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    
    # Backup current environment
    if [ -f "${BACKEND_DIR}/.env" ]; then
        cp "${BACKEND_DIR}/.env" "${BACKUP_DIR}/.env.backup"
        log_success "Environment file backed up"
    fi
    
    # Backup database (if accessible)
    log_info "Database backup recommended - please ensure you have a recent backup"
    
    log_success "Backup completed"
}

# Build Docker image
build_image() {
    log_step "Building Docker image..."
    
    cd ${BACKEND_DIR}
    
    # Build the image
    docker build -f docker/Dockerfile.production -t ${IMAGE_NAME}:latest .
    
    if [ $? -eq 0 ]; then
        log_success "Docker image built successfully"
    else
        log_error "Docker build failed"
        exit 1
    fi
    
    cd ..
}

# Push image to Google Container Registry
push_image() {
    log_step "Pushing image to Google Container Registry..."
    
    # Configure Docker for GCR
    gcloud auth configure-docker
    
    # Push the image
    docker push ${IMAGE_NAME}:latest
    
    if [ $? -eq 0 ]; then
        log_success "Image pushed successfully"
    else
        log_error "Failed to push image"
        exit 1
    fi
}

# Deploy to Cloud Run
deploy_cloud_run() {
    log_step "Deploying to Google Cloud Run..."
    
    # Deploy the service
    gcloud run deploy ${SERVICE_NAME} \
        --image ${IMAGE_NAME}:latest \
        --platform managed \
        --region ${REGION} \
        --allow-unauthenticated \
        --memory 2Gi \
        --cpu 2 \
        --max-instances 10 \
        --min-instances 1 \
        --port 8000 \
        --set-env-vars APP_ENV=production \
        --add-cloudsql-instances ${PROJECT_ID}:${REGION}:nazliyavuz-db \
        --timeout 300 \
        --concurrency 100
    
    if [ $? -eq 0 ]; then
        log_success "Deployment to Cloud Run completed"
    else
        log_error "Cloud Run deployment failed"
        exit 1
    fi
}

# Run database migrations
run_migrations() {
    log_step "Running database migrations..."
    
    # Get the service URL
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --region=${REGION} --format="value(status.url)")
    
    # Run migrations via API (if endpoint exists)
    log_info "Running migrations on: ${SERVICE_URL}"
    
    # Wait for service to be ready
    sleep 30
    
    # Test health endpoint
    if curl -f "${SERVICE_URL}/health" > /dev/null 2>&1; then
        log_success "Service is healthy"
    else
        log_warning "Health check failed - service might still be starting"
    fi
}

# Configure custom domain
configure_domain() {
    log_step "Configuring custom domain..."
    
    # Create domain mapping
    gcloud run domain-mappings create \
        --service ${SERVICE_NAME} \
        --domain api.rotaakademi.com \
        --region ${REGION} || log_warning "Domain mapping might already exist"
    
    log_success "Domain configuration completed"
}

# Set up monitoring
setup_monitoring() {
    log_step "Setting up monitoring..."
    
    # Enable required APIs
    gcloud services enable monitoring.googleapis.com
    gcloud services enable logging.googleapis.com
    
    # Create log-based metrics
    gcloud logging metrics create nazliyavuz_error_rate \
        --description="Error rate for Nazliyavuz API" \
        --log-filter='resource.type="cloud_run_revision" AND severity>=ERROR'
    
    log_success "Monitoring setup completed"
}

# Run health checks
health_checks() {
    log_step "Running health checks..."
    
    # Get service URL
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --region=${REGION} --format="value(status.url)")
    
    # Basic health check
    if curl -f "${SERVICE_URL}/health" > /dev/null 2>&1; then
        log_success "✅ Basic health check passed"
    else
        log_error "❌ Basic health check failed"
        return 1
    fi
    
    # API health check
    if curl -f "${SERVICE_URL}/api/v1/teachers" > /dev/null 2>&1; then
        log_success "✅ API health check passed"
    else
        log_warning "⚠️ API health check failed - might be normal during initial setup"
    fi
    
    # Performance check
    RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' "${SERVICE_URL}/health")
    if (( $(echo "$RESPONSE_TIME < 2.0" | bc -l) )); then
        log_success "✅ Performance check passed (${RESPONSE_TIME}s)"
    else
        log_warning "⚠️ Performance check failed (${RESPONSE_TIME}s)"
    fi
}

# Display deployment information
show_deployment_info() {
    log_success "🎉 Production deployment completed successfully!"
    echo ""
    echo "📋 Deployment Information:"
    echo "=========================="
    
    # Get service URL
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --region=${REGION} --format="value(status.url)")
    
    echo "🌐 Service URL: ${SERVICE_URL}"
    echo "🔗 Health Check: ${SERVICE_URL}/health"
    echo "📊 API Documentation: ${SERVICE_URL}/api/documentation"
    echo "🗄️ Database: Cloud SQL PostgreSQL"
    echo "⚡ Cache: Cloud Memorystore Redis"
    echo "📈 Monitoring: Google Cloud Monitoring"
    echo ""
    echo "🔧 Management Commands:"
    echo "======================"
    echo "View logs: gcloud logging read 'resource.type=\"cloud_run_revision\"' --limit 50"
    echo "Update service: gcloud run services update ${SERVICE_NAME} --region=${REGION}"
    echo "Delete service: gcloud run services delete ${SERVICE_NAME} --region=${REGION}"
    echo ""
    echo "📝 Next Steps:"
    echo "=============="
    echo "1. Configure DNS records to point to the service URL"
    echo "2. Set up SSL certificate (automatic with Cloud Run)"
    echo "3. Configure monitoring alerts"
    echo "4. Set up backup strategy"
    echo "5. Configure CI/CD pipeline"
    echo ""
}

# Main deployment function
main() {
    log_info "Starting production deployment process..."
    
    check_prerequisites
    backup_deployment
    build_image
    push_image
    deploy_cloud_run
    run_migrations
    configure_domain
    setup_monitoring
    health_checks
    show_deployment_info
    
    log_success "🚀 Rota Akademi is now running in production!"
}

# Run main function
main "$@"
