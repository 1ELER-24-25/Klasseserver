# Installation Guide for Klasseserver

## Prerequisites
- Ubuntu 20.04 LTS or newer
- Minimum 4GB RAM
- 20GB available storage
- Docker Engine installed
- Docker Compose installed

## Step 1: Install Docker and Docker Compose
```bash
# Update package index
sudo apt update

# Install required packages
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

## Step 2: Clone the Repository
```bash
git clone https://[repository-url]/klasseserver.git
cd klasseserver
```

## Step 3: Configure Environment Variables
1. Copy the example environment file:
```bash
cp .env.example .env
```

2. Edit the `.env` file with your preferred settings:
```bash
nano .env
```

Required variables:
- POSTGRES_DB
- POSTGRES_USER
- POSTGRES_PASSWORD
- PGADMIN_DEFAULT_EMAIL
- PGADMIN_DEFAULT_PASSWORD

## Step 4: Create Required Directories
```bash
# Create volume directories
mkdir -p volumes/postgres-data
mkdir -p volumes/pgadmin-data
mkdir -p mosquitto/config
mkdir -p mosquitto/data
mkdir -p mosquitto/log

# Set proper permissions
sudo chown -R 1001:1001 volumes/postgres-data
sudo chown -R 5050:5050 volumes/pgadmin-data
```

## Step 5: Start the Services
```bash
# Start all containers
docker-compose up -d

# Verify all containers are running
docker-compose ps
```

## Step 6: Verify Installation
1. Access the web interface:
   - Open a web browser and navigate to `http://localhost`
   - You should see the Klasseserver welcome page

2. Access pgAdmin:
   - Navigate to `http://localhost/pgadmin`
   - Log in using the credentials set in `.env`

3. Test MQTT connection:
   - MQTT broker is available on port 1883
   - WebSocket interface is available on port 9001

## Default Ports
- Web Interface: 80
- PostgreSQL: 5432
- MQTT: 1883
- MQTT WebSocket: 9001

## Security Notes
1. Change default passwords in `.env` file
2. Consider enabling SSL/TLS
3. Review and adjust `mosquitto.conf` for production use
4. Configure firewall rules as needed

## Troubleshooting
1. Check container logs:
```bash
docker-compose logs [service_name]
```

2. Verify container status:
```bash
docker-compose ps
```

3. Common issues:
   - Port conflicts: Ensure required ports are not in use
   - Permission issues: Check volume directory permissions
   - Database connection issues: Verify PostgreSQL credentials

## Maintenance
1. Update containers:
```bash
docker-compose pull
docker-compose up -d
```

2. Backup database:
```bash
docker exec klasseserver_db pg_dump -U [username] [database] > backup.sql
```

3. Monitor logs:
```bash
docker-compose logs -f
```
