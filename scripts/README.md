# MCP Registry Scripts

This directory contains utility scripts for deploying, managing, and testing the MCP Registry.

## 📋 Available Scripts

### Deployment Scripts

#### `deploy-wsl2.sh`
**Complete automated deployment for WSL2 Ubuntu environments**

Automates the entire deployment process including:
- WSL2 environment validation
- Docker and Docker Compose installation
- Dependency installation (git, make, jq, curl)
- Repository cloning
- Port availability checking
- Service deployment
- Health verification

**Usage:**
```bash
./scripts/deploy-wsl2.sh
```

**Prerequisites:**
- WSL2 with Ubuntu installed
- Internet connection

**What it does:**
1. ✅ Validates WSL2 environment
2. ✅ Installs Docker if not present
3. ✅ Installs required dependencies
4. ✅ Checks port availability (8080, 5432)
5. ✅ Clones registry repository
6. ✅ Deploys services with Docker Compose
7. ✅ Verifies deployment health
8. ✅ Displays access information

**Time to deploy:** ~5-10 minutes (depending on downloads)

---

### Management Scripts

#### `manage-registry.sh`
**All-in-one management tool for deployed registry**

Provides common operations for managing a deployed registry instance.

**Usage:**
```bash
./scripts/manage-registry.sh [command] [options]
```

**Available Commands:**

| Command | Description |
|---------|-------------|
| `status` | Show status of all services |
| `start` | Start the registry services |
| `stop` | Stop the registry services |
| `restart` | Restart the registry services |
| `logs` | View logs (use `-f` to follow) |
| `health` | Check health of the registry |
| `stats` | Show server statistics and metrics |
| `clean` | Clean up containers and volumes |
| `backup` | Backup the database |
| `restore` | Restore database from backup |
| `test` | Run basic endpoint tests |
| `update` | Pull latest code and restart |
| `shell` | Open shell in registry container |
| `psql` | Connect to PostgreSQL database |
| `help` | Show help message |

**Examples:**
```bash
# Check status
./scripts/manage-registry.sh status

# Follow logs
./scripts/manage-registry.sh logs -f

# View statistics
./scripts/manage-registry.sh stats

# Backup database
./scripts/manage-registry.sh backup

# Restart services
./scripts/manage-registry.sh restart

# Connect to database
./scripts/manage-registry.sh psql
```

---

### Testing Scripts

#### `test_endpoints.sh`
**Test all registry API endpoints**

Comprehensive endpoint testing script for validating registry functionality.

**Usage:**
```bash
./scripts/test_endpoints.sh [options]
```

**Options:**
- `-h, --host`: Base URL (default: http://localhost:8080)
- `-e, --endpoint`: Specific endpoint to test (health, servers, ping, all)
- `-l, --limit`: Limit parameter for servers endpoint
- `--help`: Show help message

**Examples:**
```bash
# Test all endpoints
./scripts/test_endpoints.sh

# Test specific endpoint
./scripts/test_endpoints.sh -e health

# Test with custom host
./scripts/test_endpoints.sh -h http://registry.example.com

# Test servers with limit
./scripts/test_endpoints.sh -e servers -l 10
```

---

#### `test_publish.sh`
**Test the publish endpoint with authentication**

Test server publishing functionality including authentication flow.

**Usage:**
```bash
BEARER_TOKEN=<your_token> ./scripts/test_publish.sh
```

**Prerequisites:**
- Registry must be running
- Valid bearer token (from authentication flow)

---

## 🚀 Quick Start Workflows

### Initial Deployment on WSL2

```bash
# 1. Clone the repository
git clone https://github.com/modelcontextprotocol/registry
cd registry

# 2. Run deployment script
./scripts/deploy-wsl2.sh

# 3. Access the registry
# Open http://localhost:8080/docs in your browser
```

### Daily Operations

```bash
# Check if services are running
./scripts/manage-registry.sh status

# View recent logs
./scripts/manage-registry.sh logs

# Check health
./scripts/manage-registry.sh health

# View statistics
./scripts/manage-registry.sh stats
```

### Troubleshooting

```bash
# View logs
./scripts/manage-registry.sh logs -f

# Restart services
./scripts/manage-registry.sh restart

# Run endpoint tests
./scripts/manage-registry.sh test

# Check container status
docker ps
```

### Backup and Restore

```bash
# Create backup
./scripts/manage-registry.sh backup

# List backups
ls -lh backups/

# Restore from backup
./scripts/manage-registry.sh restore
```

### Updates

```bash
# Pull latest code and restart
./scripts/manage-registry.sh update
```

---

## 🔧 Configuration

### Environment Variables

All scripts respect these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `REGISTRY_DIR` | Path to registry directory | Current directory |
| `REGISTRY_PORT` | Registry API port | 8080 |
| `POSTGRES_PORT` | PostgreSQL port | 5432 |

**Example:**
```bash
REGISTRY_PORT=9090 ./scripts/deploy-wsl2.sh
```

---

## 📝 Script Details

### `deploy-wsl2.sh` Features

**Safety Checks:**
- ✅ Validates WSL2 environment
- ✅ Checks port availability
- ✅ Verifies Docker installation
- ✅ Confirms successful deployment

**Smart Installation:**
- Only installs missing dependencies
- Reuses existing installations
- Handles user permissions automatically
- Provides clear progress feedback

**Error Handling:**
- Stops on first error
- Provides helpful error messages
- Shows relevant logs on failure
- Easy to debug

### `manage-registry.sh` Features

**Service Management:**
- Start/stop/restart services
- View real-time logs
- Check service health
- Monitor resource usage

**Database Operations:**
- Backup/restore functionality
- Direct PostgreSQL access
- Statistics and metrics
- Query interface

**Maintenance:**
- Update to latest code
- Clean up old data
- Container shell access
- Automated testing

---

## 🛠️ Making Scripts Executable

If you get permission errors, make scripts executable:

```bash
chmod +x scripts/*.sh
```

---

## 🐛 Troubleshooting

### "Permission denied" when running scripts

```bash
chmod +x scripts/*.sh
```

### "Docker: permission denied"

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### "Port already in use"

```bash
# Check what's using the port
sudo lsof -i :8080

# Kill the process
sudo kill -9 <PID>

# Or use a different port
REGISTRY_PORT=9090 ./scripts/deploy-wsl2.sh
```

### "Not in a valid registry directory"

```bash
# Navigate to registry directory first
cd ~/registry

# Or set REGISTRY_DIR
REGISTRY_DIR=~/registry ./scripts/manage-registry.sh status
```

### Services won't start

```bash
# Check Docker status
sudo systemctl status docker

# Start Docker
sudo systemctl start docker

# View detailed logs
docker compose logs
```

---

## 📚 Additional Resources

- [Main README](../README.md) - Project overview
- [Documentation](../docs/) - Full documentation
- [Docker Compose Configuration](../docker-compose.yml)
- [Environment Variables](.env.example)

---

## 🤝 Contributing

When adding new scripts:

1. Follow the existing naming convention (`noun-verb.sh`)
2. Include comprehensive help/usage information
3. Use the standard color codes for output
4. Add error handling with meaningful messages
5. Update this README with script documentation
6. Make the script executable (`chmod +x`)

---

## 📧 Support

If you encounter issues with these scripts:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review script output for error messages
3. Check Docker logs: `docker compose logs`
4. Open an issue on GitHub with details

---

## 📄 License

These scripts are part of the MCP Registry project and follow the same license.

