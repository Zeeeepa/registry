#!/bin/bash
# MCP Registry - Complete WSL2 Deployment Script
# This script automates the deployment of MCP Registry on WSL2 Ubuntu
# 
# Prerequisites: WSL2 with Ubuntu installed
# Run: ./scripts/deploy-wsl2.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY_DIR="${HOME}/registry"
REGISTRY_PORT="${REGISTRY_PORT:-8080}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

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

# Check if running on WSL2
check_wsl2() {
    print_header "Checking WSL2 Environment"
    
    if ! grep -q Microsoft /proc/version; then
        log_error "This script is designed for WSL2 Ubuntu"
        log_error "Please run this inside WSL2"
        exit 1
    fi
    
    log_success "Running on WSL2"
}

# Check if Docker is installed and running
check_docker() {
    print_header "Checking Docker Installation"
    
    if ! command -v docker &> /dev/null; then
        log_warning "Docker not found. Installing Docker..."
        install_docker
    else
        log_success "Docker is installed: $(docker --version)"
    fi
    
    # Test Docker
    if ! docker ps &> /dev/null; then
        log_error "Docker is not running or user lacks permissions"
        log_info "Attempting to start Docker service..."
        sudo systemctl start docker || true
        
        # Check if user is in docker group
        if ! groups | grep -q docker; then
            log_warning "Adding user to docker group..."
            sudo usermod -aG docker "$USER"
            log_warning "You may need to log out and back in for group changes to take effect"
            log_info "Attempting to apply group changes..."
            newgrp docker <<EOF
echo "Docker group applied"
EOF
        fi
    fi
    
    log_success "Docker is operational"
}

# Install Docker
install_docker() {
    log_info "Installing Docker..."
    
    # Update package list
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y ca-certificates curl
    
    # Download and install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    
    # Add user to docker group
    sudo usermod -aG docker "$USER"
    
    # Start Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log_success "Docker installed successfully"
}

# Install Docker Compose
install_docker_compose() {
    print_header "Checking Docker Compose"
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_warning "Docker Compose not found. Installing..."
        sudo apt-get install -y docker-compose
        log_success "Docker Compose installed"
    else
        log_success "Docker Compose is available"
    fi
}

# Install required tools
install_dependencies() {
    print_header "Installing Dependencies"
    
    sudo apt-get update
    
    local packages=("git" "make" "jq" "curl")
    local missing_packages=()
    
    for package in "${packages[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            missing_packages+=("$package")
        else
            log_success "$package is installed"
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_info "Installing missing packages: ${missing_packages[*]}"
        sudo apt-get install -y "${missing_packages[@]}"
        log_success "Dependencies installed"
    else
        log_success "All dependencies are already installed"
    fi
}

# Clone or update registry repository
setup_repository() {
    print_header "Setting Up Repository"
    
    if [ -d "$REGISTRY_DIR" ]; then
        log_warning "Registry directory already exists at $REGISTRY_DIR"
        read -p "Do you want to remove and re-clone? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing existing directory..."
            rm -rf "$REGISTRY_DIR"
        else
            log_info "Using existing directory"
            cd "$REGISTRY_DIR"
            log_info "Pulling latest changes..."
            git pull origin main || log_warning "Could not pull latest changes"
            return
        fi
    fi
    
    log_info "Cloning MCP Registry repository..."
    git clone https://github.com/modelcontextprotocol/registry "$REGISTRY_DIR"
    cd "$REGISTRY_DIR"
    log_success "Repository cloned successfully"
}

# Check if ports are available
check_ports() {
    print_header "Checking Port Availability"
    
    if lsof -Pi :$REGISTRY_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_error "Port $REGISTRY_PORT is already in use"
        log_info "Process using port $REGISTRY_PORT:"
        sudo lsof -i :$REGISTRY_PORT
        exit 1
    else
        log_success "Port $REGISTRY_PORT is available"
    fi
    
    if lsof -Pi :$POSTGRES_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_error "Port $POSTGRES_PORT is already in use"
        log_info "Process using port $POSTGRES_PORT:"
        sudo lsof -i :$POSTGRES_PORT
        exit 1
    else
        log_success "Port $POSTGRES_PORT is available"
    fi
}

# Deploy the registry
deploy_registry() {
    print_header "Deploying MCP Registry"
    
    cd "$REGISTRY_DIR"
    
    log_info "Starting Docker Compose..."
    make dev-compose &
    
    local compose_pid=$!
    
    log_info "Waiting for services to start (this may take 60-90 seconds)..."
    
    # Wait for registry to be healthy
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:$REGISTRY_PORT/v0/ping &> /dev/null; then
            log_success "Registry is responding!"
            break
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    echo ""
    
    if [ $attempt -eq $max_attempts ]; then
        log_error "Registry failed to start within expected time"
        log_info "Checking logs..."
        docker compose logs --tail=50
        exit 1
    fi
}

# Verify deployment
verify_deployment() {
    print_header "Verifying Deployment"
    
    # Test ping endpoint
    log_info "Testing /v0/ping endpoint..."
    if curl -s http://localhost:$REGISTRY_PORT/v0/ping | grep -q "pong"; then
        log_success "Ping endpoint working"
    else
        log_error "Ping endpoint failed"
        exit 1
    fi
    
    # Test health endpoint
    log_info "Testing /v0/health endpoint..."
    if curl -s http://localhost:$REGISTRY_PORT/v0/health | jq -e '.status == "ok"' &> /dev/null; then
        log_success "Health endpoint working"
    else
        log_error "Health endpoint failed"
        exit 1
    fi
    
    # Test servers endpoint
    log_info "Testing /v0/servers endpoint..."
    local server_count=$(curl -s http://localhost:$REGISTRY_PORT/v0/servers | jq -r '.metadata.count')
    if [ -n "$server_count" ] && [ "$server_count" -gt 0 ]; then
        log_success "Servers endpoint working (found $server_count servers)"
    else
        log_error "Servers endpoint failed"
        exit 1
    fi
    
    # Check Docker containers
    log_info "Checking Docker containers..."
    if docker ps | grep -q registry; then
        log_success "Registry container is running"
    else
        log_error "Registry container is not running"
        exit 1
    fi
    
    if docker ps | grep -q postgres; then
        log_success "PostgreSQL container is running"
    else
        log_error "PostgreSQL container is not running"
        exit 1
    fi
}

# Display success message
show_success_message() {
    print_header "🎉 Deployment Complete!"
    
    echo -e "${GREEN}MCP Registry has been successfully deployed!${NC}"
    echo ""
    echo -e "${BLUE}Access Information:${NC}"
    echo -e "  • API Base URL:       ${GREEN}http://localhost:$REGISTRY_PORT${NC}"
    echo -e "  • API Documentation:  ${GREEN}http://localhost:$REGISTRY_PORT/docs${NC}"
    echo -e "  • Health Check:       ${GREEN}http://localhost:$REGISTRY_PORT/v0/health${NC}"
    echo -e "  • List Servers:       ${GREEN}http://localhost:$REGISTRY_PORT/v0/servers${NC}"
    echo ""
    echo -e "${BLUE}Database Information:${NC}"
    echo -e "  • PostgreSQL Host:    ${GREEN}localhost:$POSTGRES_PORT${NC}"
    echo -e "  • Database Name:      ${GREEN}mcp-registry${NC}"
    echo -e "  • Username:           ${GREEN}mcpregistry${NC}"
    echo -e "  • Password:           ${GREEN}mcpregistry${NC}"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo -e "  • View logs:          ${YELLOW}cd $REGISTRY_DIR && docker compose logs -f${NC}"
    echo -e "  • Stop services:      ${YELLOW}cd $REGISTRY_DIR && docker compose down${NC}"
    echo -e "  • Restart services:   ${YELLOW}cd $REGISTRY_DIR && docker compose restart${NC}"
    echo -e "  • Check status:       ${YELLOW}docker ps${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "  1. Open ${GREEN}http://localhost:$REGISTRY_PORT/docs${NC} in your browser"
    echo -e "  2. Explore the API endpoints"
    echo -e "  3. Build the publisher CLI: ${YELLOW}cd $REGISTRY_DIR && make publisher${NC}"
    echo ""
    echo -e "${GREEN}Access from Windows:${NC} All services are automatically accessible from Windows via localhost!"
    echo ""
}

# Main execution
main() {
    print_header "MCP Registry WSL2 Deployment"
    
    log_info "Starting automated deployment process..."
    echo ""
    
    # Run deployment steps
    check_wsl2
    check_docker
    install_docker_compose
    install_dependencies
    check_ports
    setup_repository
    deploy_registry
    
    # Wait a bit for everything to stabilize
    sleep 5
    
    verify_deployment
    show_success_message
}

# Handle errors
trap 'log_error "Deployment failed at line $LINENO. Check the logs above for details."; exit 1' ERR

# Run main function
main "$@"

