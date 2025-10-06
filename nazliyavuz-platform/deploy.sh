#!/bin/bash

# Nazliyavuz Platform Deployment Script
# This script handles the complete deployment process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-production}
BACKUP_DIR="./backups"
LOG_FILE="./deploy.log"

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root"
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed"
    fi
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        error "Git is not installed"
    fi
    
    success "Prerequisites check passed"
}

# Create backup
create_backup() {
    log "Creating backup..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
    BACKUP_PATH="$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
    
    # Backup database
    if docker-compose ps postgres | grep -q "Up"; then
        log "Backing up database..."
        docker-compose exec -T postgres pg_dump -U nazliyavuz_user nazliyavuz_platform > "$BACKUP_PATH/database.sql"
        success "Database backup created"
    else
        warning "Database container is not running, skipping database backup"
    fi
    
    # Backup uploads and storage
    if [ -d "./backend/storage/app/public" ]; then
        log "Backing up storage..."
        cp -r ./backend/storage/app/public "$BACKUP_PATH/storage"
        success "Storage backup created"
    fi
    
    # Backup configuration files
    log "Backing up configuration files..."
    cp -r ./backend/.env "$BACKUP_PATH/" 2>/dev/null || warning ".env file not found"
    cp -r ./nginx "$BACKUP_PATH/" 2>/dev/null || warning "nginx config not found"
    cp -r ./redis "$BACKUP_PATH/" 2>/dev/null || warning "redis config not found"
    
    success "Backup completed: $BACKUP_PATH"
}

# Pull latest code
pull_code() {
    log "Pulling latest code..."
    
    # Stash any local changes
    git stash push -m "Auto-stash before deployment $(date)"
    
    # Pull latest changes
    git pull origin main
    
    success "Code updated"
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    # Backend dependencies
    if [ -f "./backend/composer.json" ]; then
        log "Installing PHP dependencies..."
        docker-compose exec app composer install --no-dev --optimize-autoloader
        success "PHP dependencies installed"
    fi
    
    # Frontend dependencies
    if [ -f "./frontend/package.json" ]; then
        log "Installing Node.js dependencies..."
        cd frontend
        npm ci --production
        success "Node.js dependencies installed"
        cd ..
    fi
}

# Build application
build_application() {
    log "Building application..."
    
    # Build Docker images
    log "Building Docker images..."
    docker-compose build --no-cache
    
    # Build frontend
    if [ -f "./frontend/package.json" ]; then
        log "Building frontend..."
        cd frontend
        npm run build
        success "Frontend built"
        cd ..
    fi
    
    success "Application built"
}

# Run database migrations
run_migrations() {
    log "Running database migrations..."
    
    # Wait for database to be ready
    log "Waiting for database to be ready..."
    docker-compose exec -T app php artisan migrate --force
    
    success "Database migrations completed"
}

# Clear caches
clear_caches() {
    log "Clearing caches..."
    
    docker-compose exec -T app php artisan config:clear
    docker-compose exec -T app php artisan cache:clear
    docker-compose exec -T app php artisan route:clear
    docker-compose exec -T app php artisan view:clear
    
    success "Caches cleared"
}

# Optimize application
optimize_application() {
    log "Optimizing application..."
    
    docker-compose exec -T app php artisan config:cache
    docker-compose exec -T app php artisan route:cache
    docker-compose exec -T app php artisan view:cache
    docker-compose exec -T app php artisan event:cache
    
    success "Application optimized"
}

# Start services
start_services() {
    log "Starting services..."
    
    # Stop existing services
    docker-compose down
    
    # Start services
    docker-compose up -d
    
    # Wait for services to be healthy
    log "Waiting for services to be healthy..."
    sleep 30
    
    # Check health
    if docker-compose exec -T app php artisan health:check; then
        success "All services are healthy"
    else
        error "Some services are unhealthy"
    fi
}

# Run tests
run_tests() {
    log "Running tests..."
    
    # Backend tests
    if [ -f "./backend/phpunit.xml" ]; then
        log "Running backend tests..."
        docker-compose exec -T app php artisan test
        success "Backend tests passed"
    fi
    
    # Frontend tests
    if [ -f "./frontend/package.json" ]; then
        log "Running frontend tests..."
        cd frontend
        npm test -- --coverage --watchAll=false
        success "Frontend tests passed"
        cd ..
    fi
}

# Update file permissions
update_permissions() {
    log "Updating file permissions..."
    
    # Set proper permissions for Laravel
    docker-compose exec -T app chown -R www-data:www-data /var/www
    docker-compose exec -T app chmod -R 755 /var/www/storage
    docker-compose exec -T app chmod -R 755 /var/www/bootstrap/cache
    
    success "File permissions updated"
}

# Restart queue workers
restart_queues() {
    log "Restarting queue workers..."
    
    docker-compose restart queue
    
    success "Queue workers restarted"
}

# Main deployment function
deploy() {
    log "Starting deployment for environment: $ENVIRONMENT"
    
    check_root
    check_prerequisites
    create_backup
    pull_code
    install_dependencies
    build_application
    run_migrations
    clear_caches
    optimize_application
    update_permissions
    start_services
    restart_queues
    
    # Run tests only in staging environment
    if [ "$ENVIRONMENT" = "staging" ]; then
        run_tests
    fi
    
    success "Deployment completed successfully!"
    
    # Show service status
    log "Service status:"
    docker-compose ps
}

# Rollback function
rollback() {
    log "Starting rollback..."
    
    # Find latest backup
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR" | head -n1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        error "No backup found"
    fi
    
    BACKUP_PATH="$BACKUP_DIR/$LATEST_BACKUP"
    log "Rolling back to: $BACKUP_PATH"
    
    # Stop services
    docker-compose down
    
    # Restore database
    if [ -f "$BACKUP_PATH/database.sql" ]; then
        log "Restoring database..."
        docker-compose up -d postgres
        sleep 10
        docker-compose exec -T postgres psql -U nazliyavuz_user -d nazliyavuz_platform < "$BACKUP_PATH/database.sql"
        success "Database restored"
    fi
    
    # Restore storage
    if [ -d "$BACKUP_PATH/storage" ]; then
        log "Restoring storage..."
        rm -rf ./backend/storage/app/public
        cp -r "$BACKUP_PATH/storage" ./backend/storage/app/public
        success "Storage restored"
    fi
    
    # Restore configuration
    if [ -f "$BACKUP_PATH/.env" ]; then
        log "Restoring configuration..."
        cp "$BACKUP_PATH/.env" ./backend/.env
        success "Configuration restored"
    fi
    
    # Start services
    docker-compose up -d
    
    success "Rollback completed"
}

# Show usage
usage() {
    echo "Usage: $0 [ENVIRONMENT] [COMMAND]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  production  Deploy to production (default)"
    echo "  staging     Deploy to staging"
    echo ""
    echo "COMMAND:"
    echo "  deploy      Run full deployment (default)"
    echo "  rollback    Rollback to previous version"
    echo "  status      Show service status"
    echo "  logs        Show service logs"
    echo "  health      Check application health"
    echo ""
    echo "Examples:"
    echo "  $0                    # Deploy to production"
    echo "  $0 staging           # Deploy to staging"
    echo "  $0 production rollback # Rollback production"
}

# Handle command line arguments
case "${2:-deploy}" in
    deploy)
        deploy
        ;;
    rollback)
        rollback
        ;;
    status)
        docker-compose ps
        ;;
    logs)
        docker-compose logs -f
        ;;
    health)
        docker-compose exec -T app php artisan health:check
        ;;
    *)
        usage
        exit 1
        ;;
esac