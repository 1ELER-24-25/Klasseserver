#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored text
print_color() {
    color=$1
    message=$2
    echo -e "${color}${message}${NC}"
}

# Function to confirm action
confirm() {
    read -p "Are you sure? This will delete all data! (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        return 1
    fi
    return 0
}

# Clean restart (removes all data)
clean_restart() {
    print_color $YELLOW "Stopping all containers..."
    docker-compose down

    print_color $YELLOW "Removing all volume data..."
    sudo rm -rf volumes/postgres-data/*
    sudo rm -rf volumes/pgadmin-data/*
    sudo rm -rf mosquitto/data/*
    sudo rm -rf mosquitto/log/*

    print_color $YELLOW "Recreating volume directories..."
    mkdir -p volumes/postgres-data
    mkdir -p volumes/pgadmin-data
    mkdir -p mosquitto/config
    mkdir -p mosquitto/data
    mkdir -p mosquitto/log

    print_color $YELLOW "Setting correct permissions..."
    sudo chown -R 1001:1001 volumes/postgres-data
    sudo chown -R 5050:5050 volumes/pgadmin-data
    sudo chmod -R 777 mosquitto/config
    sudo chmod -R 777 mosquitto/data
    sudo chmod -R 777 mosquitto/log

    print_color $YELLOW "Starting containers..."
    docker-compose up -d

    print_color $GREEN "Clean restart completed!"
}

# View logs
view_logs() {
    case $1 in
        "postgres")
            docker-compose logs -f postgres
            ;;
        "pgadmin")
            docker-compose logs -f pgadmin
            ;;
        "nginx")
            docker-compose logs -f nginx
            ;;
        "mqtt")
            docker-compose logs -f mosquitto
            ;;
        *)
            docker-compose logs -f
            ;;
    esac
}

# Check container status
check_status() {
    print_color $GREEN "Container Status:"
    docker-compose ps
}

# Check database size
check_db_size() {
    print_color $GREEN "Database Sizes:"
    docker exec klasseserver_db psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "\l+"
}

# Backup database
backup_db() {
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="backup_${timestamp}.sql"
    print_color $YELLOW "Creating backup: $backup_file"
    docker exec klasseserver_db pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} > "backups/${backup_file}"
    print_color $GREEN "Backup completed!"
}

# Restore database
restore_db() {
    if [ -z "$1" ]; then
        print_color $RED "Please specify backup file to restore"
        return 1
    fi
    print_color $YELLOW "Restoring from: $1"
    docker exec -i klasseserver_db psql -U ${POSTGRES_USER} ${POSTGRES_DB} < "$1"
    print_color $GREEN "Restore completed!"
}

# Quick restart (keeps data)
quick_restart() {
    print_color $YELLOW "Restarting containers..."
    docker-compose restart
    print_color $GREEN "Restart completed!"
}

# Show help
show_help() {
    echo "Usage: ./commands.sh [command]"
    echo
    echo "Commands:"
    echo "  clean      - Complete reset (removes all data)"
    echo "  restart    - Quick restart (keeps data)"
    echo "  logs       - View all logs"
    echo "  logs:db    - View database logs"
    echo "  logs:web   - View nginx logs"
    echo "  logs:mqtt  - View MQTT broker logs"
    echo "  status     - Check container status"
    echo "  backup     - Create database backup"
    echo "  restore    - Restore database from backup"
    echo "  dbsize     - Show database sizes"
    echo "  help       - Show this help message"
}

# Function to generate servers.json
generate_pgadmin_config() {
    print_color $YELLOW "Generating pgAdmin configuration..."
    cat > pgadmin/servers.json << EOF
{
    "Servers": {
        "1": {
            "Name": "Klasseserver DB",
            "Group": "Servers",
            "Host": "postgres",
            "Port": 5432,
            "MaintenanceDB": "${POSTGRES_DB}",
            "Username": "${POSTGRES_USER}",
            "Password": "${POSTGRES_PASSWORD}",
            "SSLMode": "prefer",
            "Comment": "Klasseserver PostgreSQL database"
        }
    }
}
EOF
    print_color $GREEN "pgAdmin configuration generated!"
}

# Main command handler
case $1 in
    "clean")
        if confirm; then
            clean_restart
        fi
        ;;
    "restart")
        quick_restart
        ;;
    "logs")
        view_logs
        ;;
    "logs:db")
        view_logs "postgres"
        ;;
    "logs:web")
        view_logs "nginx"
        ;;
    "logs:mqtt")
        view_logs "mqtt"
        ;;
    "status")
        check_status
        ;;
    "backup")
        backup_db
        ;;
    "restore")
        restore_db $2
        ;;
    "dbsize")
        check_db_size
        ;;
    "help"|*)
        show_help
        ;;
esac
