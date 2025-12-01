#!/bin/bash

# Server Cleanup Script for Ubuntu
# This script removes common web services and prepares for fresh deployment
# WARNING: This will stop and remove web services and databases

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Warning and confirmation
show_warning() {
    clear
    echo -e "${RED}⚠️  DANGER: SERVER CLEANUP SCRIPT ⚠️${NC}"
    echo
    echo "This script will:"
    echo "• Stop all web servers (Apache, Nginx, etc.)"
    echo "• Stop database servers (MySQL, PostgreSQL)"
    echo "• Remove Docker containers and images"
    echo "• Clean package cache and unused packages"
    echo "• Stop conflicting services on ports 80, 443, 3306"
    echo
    echo -e "${YELLOW}This will NOT:${NC}"
    echo "• Delete your files in /home"
    echo "• Remove the operating system"
    echo "• Delete SSH keys or users"
    echo
    echo -e "${RED}IMPORTANT: Backup any important data first!${NC}"
    echo
    
    read -p "Are you absolutely sure you want to continue? (type 'yes' to proceed): " confirmation
    if [[ "$confirmation" != "yes" ]]; then
        print_error "Cleanup cancelled"
        exit 1
    fi
}

# Stop web services
stop_web_services() {
    print_status "Stopping web services..."
    
    # Apache
    sudo systemctl stop apache2 2>/dev/null || true
    sudo systemctl disable apache2 2>/dev/null || true
    
    # Nginx
    sudo systemctl stop nginx 2>/dev/null || true
    sudo systemctl disable nginx 2>/dev/null || true
    
    # Other web servers
    sudo systemctl stop lighttpd 2>/dev/null || true
    sudo systemctl stop caddy 2>/dev/null || true
    
    print_success "Web services stopped"
}

# Stop database services
stop_database_services() {
    print_status "Stopping database services..."
    
    # MySQL/MariaDB
    sudo systemctl stop mysql 2>/dev/null || true
    sudo systemctl stop mariadb 2>/dev/null || true
    sudo systemctl disable mysql 2>/dev/null || true
    sudo systemctl disable mariadb 2>/dev/null || true
    
    # PostgreSQL
    sudo systemctl stop postgresql 2>/dev/null || true
    sudo systemctl disable postgresql 2>/dev/null || true
    
    # Redis
    sudo systemctl stop redis 2>/dev/null || true
    sudo systemctl stop redis-server 2>/dev/null || true
    
    print_success "Database services stopped"
}

# Clean Docker completely
clean_docker() {
    print_status "Cleaning Docker..."
    
    if command -v docker &> /dev/null; then
        # Stop all containers
        docker stop $(docker ps -aq) 2>/dev/null || true
        
        # Remove all containers
        docker rm $(docker ps -aq) 2>/dev/null || true
        
        # Remove all images
        docker rmi $(docker images -q) 2>/dev/null || true
        
        # Remove all volumes
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
        
        # Remove all networks (except defaults)
        docker network rm $(docker network ls --filter type=custom -q) 2>/dev/null || true
        
        # System cleanup
        docker system prune -af --volumes 2>/dev/null || true
        
        print_success "Docker cleaned"
    else
        print_status "Docker not installed, skipping"
    fi
}

# Remove web packages
remove_packages() {
    print_status "Removing web service packages..."
    
    # Web servers
    sudo apt-get remove --purge -y apache2* nginx* lighttpd caddy 2>/dev/null || true
    
    # Databases  
    sudo apt-get remove --purge -y mysql-server* mysql-client* mysql-common mysql-server-core-*
    sudo apt-get remove --purge -y mariadb-server* mariadb-client* mariadb-common
    sudo apt-get remove --purge -y postgresql* redis-server* 2>/dev/null || true
    
    # PHP and related
    sudo apt-get remove --purge -y php* libapache2-mod-php* 2>/dev/null || true
    
    # Clean up configuration files
    sudo apt-get autoremove -y
    sudo apt-get autoclean
    
    print_success "Packages removed"
}

# Kill processes using web ports
kill_port_processes() {
    print_status "Killing processes on web ports..."
    
    # Kill processes on common web ports
    for port in 80 443 3306 5432 6379 8080 8443 9000; do
        pid=$(sudo lsof -ti:$port 2>/dev/null || true)
        if [[ -n "$pid" ]]; then
            print_status "Killing process on port $port (PID: $pid)"
            sudo kill -9 $pid 2>/dev/null || true
        fi
    done
    
    print_success "Port processes cleared"
}

# Clean filesystem
clean_filesystem() {
    print_status "Cleaning filesystem..."
    
    # Remove common web directories
    sudo rm -rf /var/www/* 2>/dev/null || true
    sudo rm -rf /etc/apache2 2>/dev/null || true
    sudo rm -rf /etc/nginx 2>/dev/null || true
    sudo rm -rf /var/lib/mysql 2>/dev/null || true
    sudo rm -rf /var/lib/postgresql 2>/dev/null || true
    
    # Clean logs
    sudo rm -rf /var/log/apache2 2>/dev/null || true
    sudo rm -rf /var/log/nginx 2>/dev/null || true
    sudo rm -rf /var/log/mysql 2>/dev/null || true
    
    # Clean temporary files
    sudo rm -rf /tmp/* 2>/dev/null || true
    sudo rm -rf /var/tmp/* 2>/dev/null || true
    
    # Clean package cache
    sudo apt-get clean
    
    print_success "Filesystem cleaned"
}

# Update system
update_system() {
    print_status "Updating system..."
    
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get dist-upgrade -y
    sudo apt-get autoremove -y
    sudo apt-get autoclean
    
    print_success "System updated"
}

# Check for remaining conflicts
check_conflicts() {
    print_status "Checking for remaining conflicts..."
    
    # Check ports
    local conflicts=()
    
    for port in 80 443 3306; do
        if sudo netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            conflicts+=("Port $port still in use")
        fi
    done
    
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        print_warning "Potential conflicts detected:"
        for conflict in "${conflicts[@]}"; do
            echo "  - $conflict"
        done
        echo
        print_status "You may need to investigate these manually"
    else
        print_success "No conflicts detected"
    fi
}

# Show final status
show_final_status() {
    clear
    print_success "=== SERVER CLEANUP COMPLETED ==="
    echo
    print_status "System Status:"
    echo "• Web servers: Stopped and removed"
    echo "• Databases: Stopped and removed" 
    echo "• Docker: Completely cleaned"
    echo "• Ports 80, 443, 3306: Available"
    echo "• System: Updated to latest packages"
    echo
    print_status "Next Steps:"
    echo "1. Reboot the server: sudo reboot"
    echo "2. After reboot, run your Mautic+n8n deployment script"
    echo "3. The system should be clean for fresh installation"
    echo
    print_warning "Remember to restore any important data you backed up!"
}

# Main execution
main() {
    show_warning
    
    print_status "Starting server cleanup process..."
    
    stop_web_services
    stop_database_services  
    kill_port_processes
    clean_docker
    remove_packages
    clean_filesystem
    update_system
    check_conflicts
    
    show_final_status
    
    echo
    read -p "Reboot now to complete cleanup? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Rebooting in 5 seconds..."
        sleep 5
        sudo reboot
    else
        print_status "Please reboot manually when ready"
    fi
}

# Run main function
main "$@"
