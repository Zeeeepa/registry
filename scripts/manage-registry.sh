#!/bin/bash
# MCP Registry - Management Script
# Provides common management operations for the deployed registry
#
# Usage: ./scripts/manage-registry.sh [command] [options]

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REGISTRY_DIR="${REGISTRY_DIR:-$(pwd)}"
REGISTRY_PORT="${REGISTRY_PORT:-8080}"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo ""
}

# Show usage
show_usage() {
    cat << EOF
${BLUE}MCP Registry Management Script${NC}

${GREEN}Usage:${NC}
  $0 [command] [options]

${GREEN}Commands:${NC}
  ${YELLOW}status${NC}          Show status of all services
  ${YELLOW}start${NC}           Start the registry services
  ${YELLOW}stop${NC}            Stop the registry services
  ${YELLOW}restart${NC}         Restart the registry services
  ${YELLOW}logs${NC}            View logs (optional: -f to follow)
  ${YELLOW}health${NC}          Check health of the registry
  ${YELLOW}stats${NC}           Show server statistics
  ${YELLOW}clean${NC}           Clean up (with confirmation)
  ${YELLOW}backup${NC}          Backup the database
  ${YELLOW}restore${NC}         Restore database from backup
  ${YELLOW}test${NC}            Run basic endpoint tests
  ${YELLOW}update${NC}          Pull latest code and restart
  ${YELLOW}shell${NC}           Open a shell in the registry container
  ${YELLOW}psql${NC}            Connect to PostgreSQL database
  ${YELLOW}help${NC}            Show this help message

${GREEN}Options:${NC}
  -f, --follow        Follow logs (for logs command)
  -v, --verbose       Verbose output
  -h, --help          Show help message

${GREEN}Examples:${NC}
  $0 status                  # Check status
  $0 logs -f                 # Follow logs
  $0 restart                 # Restart services
  $0 stats                   # View statistics
  $0 psql                    # Connect to database

${GREEN}Environment Variables:${NC}
  REGISTRY_DIR        Path to registry directory (default: current directory)
  REGISTRY_PORT       Registry port (default: 8080)

EOF
}

# Check if in registry directory
check_directory() {
    if [ ! -f "$REGISTRY_DIR/docker-compose.yml" ]; then
        log_error "Not in a valid registry directory"
        log_info "Please run this script from the registry directory or set REGISTRY_DIR"
        exit 1
    fi
    cd "$REGISTRY_DIR"
}

# Status command
cmd_status() {
    print_header "Service Status"
    
    log_info "Docker Containers:"
    docker compose ps
    echo ""
    
    log_info "Container Health:"
    if docker ps --filter "name=registry" --format "{{.Status}}" | grep -q "Up"; then
        log_success "Registry container is running"
    else
        log_error "Registry container is not running"
    fi
    
    if docker ps --filter "name=postgres" --format "{{.Status}}" | grep -q "Up"; then
        log_success "PostgreSQL container is running"
    else
        log_error "PostgreSQL container is not running"
    fi
    echo ""
    
    log_info "API Status:"
    if curl -s http://localhost:$REGISTRY_PORT/v0/ping &> /dev/null; then
        log_success "API is responding on port $REGISTRY_PORT"
    else
        log_error "API is not responding on port $REGISTRY_PORT"
    fi
}

# Start command
cmd_start() {
    print_header "Starting Services"
    
    log_info "Starting Docker Compose..."
    docker compose up -d
    
    log_info "Waiting for services to be ready..."
    sleep 10
    
    if curl -s http://localhost:$REGISTRY_PORT/v0/ping &> /dev/null; then
        log_success "Services started successfully"
    else
        log_warning "Services started but API is not responding yet"
        log_info "Check logs with: $0 logs"
    fi
}

# Stop command
cmd_stop() {
    print_header "Stopping Services"
    
    log_info "Stopping Docker Compose..."
    docker compose stop
    log_success "Services stopped"
}

# Restart command
cmd_restart() {
    print_header "Restarting Services"
    
    log_info "Restarting Docker Compose..."
    docker compose restart
    
    log_info "Waiting for services to be ready..."
    sleep 10
    
    if curl -s http://localhost:$REGISTRY_PORT/v0/ping &> /dev/null; then
        log_success "Services restarted successfully"
    else
        log_warning "Services restarted but API is not responding yet"
    fi
}

# Logs command
cmd_logs() {
    print_header "Service Logs"
    
    if [ "$1" = "-f" ] || [ "$1" = "--follow" ]; then
        log_info "Following logs (Ctrl+C to exit)..."
        docker compose logs -f
    else
        log_info "Showing last 100 lines..."
        docker compose logs --tail=100
    fi
}

# Health command
cmd_health() {
    print_header "Health Check"
    
    log_info "Checking registry health..."
    
    # Ping endpoint
    if response=$(curl -s http://localhost:$REGISTRY_PORT/v0/ping); then
        if echo "$response" | grep -q "pong"; then
            log_success "Ping endpoint: OK"
        else
            log_error "Ping endpoint: FAILED"
        fi
    else
        log_error "Cannot reach ping endpoint"
    fi
    
    # Health endpoint
    if response=$(curl -s http://localhost:$REGISTRY_PORT/v0/health); then
        if echo "$response" | jq -e '.status == "ok"' &> /dev/null; then
            log_success "Health endpoint: OK"
            
            # Show details
            echo ""
            log_info "Health Details:"
            echo "$response" | jq '.'
        else
            log_error "Health endpoint: FAILED"
            echo "$response" | jq '.'
        fi
    else
        log_error "Cannot reach health endpoint"
    fi
    
    # Database check
    echo ""
    log_info "Checking database connection..."
    if docker exec postgres pg_isready -U mcpregistry &> /dev/null; then
        log_success "Database: OK"
    else
        log_error "Database: FAILED"
    fi
}

# Stats command
cmd_stats() {
    print_header "Server Statistics"
    
    # Get server count
    log_info "Fetching statistics..."
    
    if response=$(curl -s http://localhost:$REGISTRY_PORT/v0/servers?limit=1); then
        total_count=$(echo "$response" | jq -r '.metadata.count')
        
        echo ""
        log_success "Total Servers: $total_count"
        echo ""
        
        # Get more detailed stats via database
        log_info "Database Statistics:"
        docker exec postgres psql -U mcpregistry -d mcp-registry -c "
            SELECT 
                status,
                COUNT(*) as count
            FROM servers
            GROUP BY status
            ORDER BY count DESC;
        " 2>/dev/null || log_warning "Could not fetch database stats"
        
        echo ""
        log_info "Container Resource Usage:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    else
        log_error "Could not fetch statistics"
    fi
}

# Clean command
cmd_clean() {
    print_header "Clean Up"
    
    log_warning "This will:"
    echo "  • Stop all containers"
    echo "  • Remove containers"
    echo "  • Remove volumes (DATABASE WILL BE DELETED)"
    echo "  • Remove local database files"
    echo ""
    read -p "Are you sure you want to continue? (yes/NO): " -r
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Clean up cancelled"
        exit 0
    fi
    
    log_info "Stopping and removing containers..."
    docker compose down -v
    
    if [ -d ".db" ]; then
        log_info "Removing database files..."
        rm -rf .db
    fi
    
    log_success "Clean up completed"
}

# Backup command
cmd_backup() {
    print_header "Database Backup"
    
    local backup_dir="backups"
    local backup_file="$backup_dir/registry-$(date +%Y%m%d-%H%M%S).sql"
    
    mkdir -p "$backup_dir"
    
    log_info "Creating backup: $backup_file"
    docker exec postgres pg_dump -U mcpregistry -d mcp-registry > "$backup_file"
    
    log_success "Backup created: $backup_file"
    log_info "Backup size: $(du -h "$backup_file" | cut -f1)"
}

# Restore command
cmd_restore() {
    print_header "Database Restore"
    
    local backup_dir="backups"
    
    if [ ! -d "$backup_dir" ]; then
        log_error "No backups directory found"
        exit 1
    fi
    
    # List available backups
    log_info "Available backups:"
    ls -lh "$backup_dir"/*.sql 2>/dev/null || {
        log_error "No backup files found"
        exit 1
    }
    
    echo ""
    read -p "Enter backup filename (or path): " backup_file
    
    if [ ! -f "$backup_file" ]; then
        backup_file="$backup_dir/$backup_file"
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    log_warning "This will replace the current database!"
    read -p "Are you sure? (yes/NO): " -r
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    log_info "Restoring from: $backup_file"
    cat "$backup_file" | docker exec -i postgres psql -U mcpregistry -d mcp-registry
    
    log_success "Database restored successfully"
}

# Test command
cmd_test() {
    print_header "Running Endpoint Tests"
    
    if [ -f "scripts/test_endpoints.sh" ]; then
        ./scripts/test_endpoints.sh
    else
        log_info "Running basic tests..."
        
        # Test ping
        log_info "Testing /v0/ping..."
        curl -s http://localhost:$REGISTRY_PORT/v0/ping | jq '.'
        
        # Test health
        log_info "Testing /v0/health..."
        curl -s http://localhost:$REGISTRY_PORT/v0/health | jq '.'
        
        # Test servers list
        log_info "Testing /v0/servers?limit=5..."
        curl -s "http://localhost:$REGISTRY_PORT/v0/servers?limit=5" | jq '.'
        
        log_success "Basic tests completed"
    fi
}

# Update command
cmd_update() {
    print_header "Updating Registry"
    
    log_info "Pulling latest code..."
    git pull origin main
    
    log_info "Rebuilding containers..."
    docker compose up -d --build
    
    log_info "Waiting for services..."
    sleep 10
    
    if curl -s http://localhost:$REGISTRY_PORT/v0/ping &> /dev/null; then
        log_success "Update completed successfully"
    else
        log_warning "Update completed but API is not responding yet"
    fi
}

# Shell command
cmd_shell() {
    print_header "Opening Shell in Registry Container"
    
    docker exec -it registry sh
}

# PostgreSQL command
cmd_psql() {
    print_header "Connecting to PostgreSQL"
    
    log_info "Opening psql shell..."
    log_info "Database: mcp-registry"
    log_info "User: mcpregistry"
    echo ""
    
    docker exec -it postgres psql -U mcpregistry -d mcp-registry
}

# Main execution
main() {
    if [ $# -eq 0 ] || [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_usage
        exit 0
    fi
    
    check_directory
    
    local command=$1
    shift
    
    case "$command" in
        status)
            cmd_status "$@"
            ;;
        start)
            cmd_start "$@"
            ;;
        stop)
            cmd_stop "$@"
            ;;
        restart)
            cmd_restart "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        health)
            cmd_health "$@"
            ;;
        stats)
            cmd_stats "$@"
            ;;
        clean)
            cmd_clean "$@"
            ;;
        backup)
            cmd_backup "$@"
            ;;
        restore)
            cmd_restore "$@"
            ;;
        test)
            cmd_test "$@"
            ;;
        update)
            cmd_update "$@"
            ;;
        shell)
            cmd_shell "$@"
            ;;
        psql)
            cmd_psql "$@"
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"

