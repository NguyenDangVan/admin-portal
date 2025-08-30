#!/bin/bash

# Restaurant Analytics Portal Deployment Script
# Usage: ./scripts/deploy.sh [environment] [version]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-staging}
VERSION=${2:-latest}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Configuration
DOCKER_IMAGE="${DOCKER_USERNAME:-restaurant-analytics}/restaurant-analytics-portal"
DOCKER_TAG="${VERSION}"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.${ENVIRONMENT}.yml"

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running or not accessible"
        exit 1
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker-compose >/dev/null 2>&1; then
        error "Docker Compose is not installed"
        exit 1
    fi
    
    # Check if required environment variables are set
    if [ -z "$DOCKER_USERNAME" ]; then
        warning "DOCKER_USERNAME not set, using default"
    fi
    
    success "Prerequisites check passed"
}

# Backup current deployment
backup_deployment() {
    log "Creating backup of current deployment..."
    
    BACKUP_DIR="$PROJECT_ROOT/backups/$(date +'%Y%m%d_%H%M%S')"
    mkdir -p "$BACKUP_DIR"
    
    # Backup environment file
    if [ -f "$PROJECT_ROOT/.env" ]; then
        cp "$PROJECT_ROOT/.env" "$BACKUP_DIR/"
    fi
    
    # Backup docker-compose file
    if [ -f "$COMPOSE_FILE" ]; then
        cp "$COMPOSE_FILE" "$BACKUP_DIR/"
    fi
    
    # Backup database (if running)
    if docker ps | grep -q "restaurant_analytics_db"; then
        log "Creating database backup..."
        docker exec restaurant_analytics_db pg_dump -U postgres restaurant_analytics_${ENVIRONMENT} > "$BACKUP_DIR/database_backup.sql" 2>/dev/null || warning "Database backup failed"
    fi
    
    success "Backup created in $BACKUP_DIR"
}

# Pull latest Docker image
pull_image() {
    log "Pulling latest Docker image: $DOCKER_IMAGE:$DOCKER_TAG"
    
    if ! docker pull "$DOCKER_IMAGE:$DOCKER_TAG"; then
        error "Failed to pull Docker image"
        exit 1
    fi
    
    success "Docker image pulled successfully"
}

# Update environment configuration
update_config() {
    log "Updating environment configuration..."
    
    # Create environment-specific docker-compose file if it doesn't exist
    if [ ! -f "$COMPOSE_FILE" ]; then
        log "Creating $COMPOSE_FILE from template..."
        cp "$PROJECT_ROOT/docker-compose.yml" "$COMPOSE_FILE"
        
        # Update environment-specific settings
        if [ "$ENVIRONMENT" = "production" ]; then
            # Production settings
            sed -i.bak 's/RAILS_ENV=development/RAILS_ENV=production/g' "$COMPOSE_FILE"
            sed -i.bak 's/restaurant_analytics_development/restaurant_analytics_production/g' "$COMPOSE_FILE"
        fi
    fi
    
    success "Configuration updated"
}

# Deploy application
deploy_application() {
    log "Deploying application to $ENVIRONMENT environment..."
    
    cd "$PROJECT_ROOT"
    
    # Stop existing services
    log "Stopping existing services..."
    docker-compose -f "$COMPOSE_FILE" down --remove-orphans
    
    # Start services with new image
    log "Starting services with new image..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services to be healthy
    log "Waiting for services to be healthy..."
    wait_for_health_checks
    
    success "Application deployed successfully"
}

# Wait for health checks
wait_for_health_checks() {
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "Health check attempt $attempt/$max_attempts..."
        
        # Check API health
        if curl -f "http://localhost:3000/health" >/dev/null 2>&1; then
            success "API is healthy"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            error "API health check failed after $max_attempts attempts"
            exit 1
        fi
        
        sleep 10
        attempt=$((attempt + 1))
    done
}

# Run database migrations
run_migrations() {
    log "Running database migrations..."
    
    if docker exec restaurant_analytics_api bundle exec rails db:migrate; then
        success "Database migrations completed"
    else
        error "Database migrations failed"
        exit 1
    fi
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Check if all services are running
    local services=("restaurant_analytics_db" "restaurant_analytics_redis" "restaurant_analytics_api" "restaurant_analytics_sidekiq")
    
    for service in "${services[@]}"; do
        if docker ps | grep -q "$service"; then
            success "$service is running"
        else
            error "$service is not running"
            exit 1
        fi
    done
    
    # Check API endpoints
    local endpoints=("/health" "/api/v1/restaurants" "/sidekiq")
    
    for endpoint in "${endpoints[@]}"; do
        if curl -f "http://localhost:3000$endpoint" >/dev/null 2>&1; then
            success "Endpoint $endpoint is accessible"
        else
            warning "Endpoint $endpoint is not accessible"
        fi
    done
    
    success "Deployment verification completed"
}

# Run post-deployment tasks
post_deployment() {
    log "Running post-deployment tasks..."
    
    # Clear cache
    log "Clearing application cache..."
    docker exec restaurant_analytics_api bundle exec rails runner "CacheService.instance.clear_all" 2>/dev/null || warning "Cache clearing failed"
    
    # Restart Sidekiq to ensure clean state
    log "Restarting Sidekiq..."
    docker-compose -f "$COMPOSE_FILE" restart sidekiq
    
    # Generate performance report
    log "Generating performance report..."
    docker exec restaurant_analytics_api bundle exec rails runner "PerformanceMonitor.instance.performance_report" 2>/dev/null || warning "Performance report generation failed"
    
    success "Post-deployment tasks completed"
}

# Rollback function
rollback() {
    error "Deployment failed, rolling back..."
    
    # Stop new services
    docker-compose -f "$COMPOSE_FILE" down --remove-orphans
    
    # Restore from backup if available
    if [ -d "$BACKUP_DIR" ]; then
        log "Restoring from backup..."
        # Add restore logic here
    fi
    
    error "Rollback completed"
    exit 1
}

# Main deployment function
main() {
    log "Starting deployment to $ENVIRONMENT environment (version: $VERSION)"
    
    # Set trap for rollback on failure
    trap rollback ERR
    
    check_prerequisites
    backup_deployment
    pull_image
    update_config
    deploy_application
    run_migrations
    verify_deployment
    post_deployment
    
    success "Deployment to $ENVIRONMENT completed successfully!"
    
    # Remove trap
    trap - ERR
}

# Show usage if no arguments provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [environment] [version]"
    echo "  environment: staging|production (default: staging)"
    echo "  version: Docker image tag (default: latest)"
    echo ""
    echo "Examples:"
    echo "  $0 staging"
    echo "  $0 production v1.2.3"
    exit 1
fi

# Run main function
main "$@"
