#!/bin/bash

# =============================================================================
# V5 Production Stack Manager
# Unified interface for all V5 operations
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Print functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${PURPLE}${BOLD}$1${NC}"; }

# =============================================================================
# MENU FUNCTIONS
# =============================================================================

show_header() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                                                                    ║${NC}"
    echo -e "${PURPLE}║         ${BOLD}V5 Production Stack Manager${NC}${PURPLE}                            ║${NC}"
    echo -e "${PURPLE}║                                                                    ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

show_main_menu() {
    show_header

    # Detect current state (check V5 first, it's permanent)
    if [[ -d "/root/scripts/mautic-n8n-stack-v5" ]]; then
        echo -e "${GREEN}Status: V5 Production Stack Active ✅${NC}"
        V5_DEPLOYED=true

        # Show quick stats
        cd /root/scripts/mautic-n8n-stack-v5 2>/dev/null
        local running=$(docker-compose ps -q 2>/dev/null | wc -l)
        local healthy=$(docker ps --filter "health=healthy" | grep -c "healthy" 2>/dev/null || echo "0")
        echo -e "${BLUE}Running: $running containers | Healthy: $healthy${NC}"

    elif [[ -d "/root/scripts/mautic-n8n-stack" ]]; then
        echo -e "${YELLOW}Status: V4 Stack Running (Ready to migrate to V5)${NC}"
        V5_DEPLOYED=false
    else
        echo -e "${RED}Status: No stack detected (Fresh installation)${NC}"
        V5_DEPLOYED=false
    fi

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " MAIN MENU"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    if [[ "$V5_DEPLOYED" == "false" ]]; then
        echo "  ${YELLOW}${BOLD}⚠️  V5 NOT YET DEPLOYED${NC}"
        echo
        echo "  ${BOLD}1)${NC} 🚀 Migrate to V5 Production Stack  ${GREEN}← Start here!${NC}"
        echo "  ${BOLD}2)${NC} 📖 Read Documentation First"
        echo
        echo "  ${BOLD}q)${NC} Exit"
    else
        echo "  ${GREEN}${BOLD}✅ V5 PRODUCTION MODE${NC} - All operations available"
        echo
        echo "  ${CYAN}┌─ DEPLOYMENT & UPDATES${NC}"
        echo "  │ 1) 🔄 Update n8n to latest/specific version"
        echo "  │ 2) 🔄 Update Strapi dependencies"
        echo "  │ 3) 🔄 Update all services (pull latest images)"
        echo
        echo "  ${CYAN}┌─ BACKUP & RECOVERY${NC}"
        echo "  │ 4) 💾 Create backup now"
        echo "  │ 5) 📥 Download backup to desktop"
        echo "  │ 6) 📋 List all backups"
        echo "  │ 7) 🔙 Restore from backup"
        echo
        echo "  ${CYAN}┌─ MONITORING & ALERTS${NC}"
        echo "  │ 8) 📊 Check VPS resources (CPU/RAM/Disk)"
        echo "  │ 9) ⚙️  Setup email alerts"
        echo "  │ 10) 📈 Open Grafana dashboard info"
        echo
        echo "  ${CYAN}┌─ SERVICE MANAGEMENT${NC}"
        echo "  │ 11) 🔍 View service status"
        echo "  │ 12) 📜 View logs (all or specific service)"
        echo "  │ 13) 🔄 Restart services"
        echo
        echo "  ${CYAN}┌─ HELP${NC}"
        echo "  │ 14) 📖 View documentation"
        echo "  │ 15) ℹ️  Show service URLs & credentials"
        echo
        echo "  ${BOLD}q)${NC} Exit"
    fi

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    read -p "Select option: " choice
    echo

    return 0
}

# =============================================================================
# MIGRATION
# =============================================================================

migrate_to_v5() {
    show_header
    print_header "V5 Production Migration"
    echo

    if [[ -f "$SCRIPT_DIR/migrate_v4_to_v5.sh" ]]; then
        "$SCRIPT_DIR/migrate_v4_to_v5.sh"
    else
        print_error "Migration script not found!"
        read -p "Press Enter to continue..."
    fi
}

# =============================================================================
# UPDATES
# =============================================================================

update_n8n() {
    show_header
    print_header "Update n8n"
    echo

    echo "Current n8n version:"
    docker exec n8n n8n --version 2>/dev/null || echo "Cannot determine version"
    echo

    read -p "Enter target version (e.g., 2.0, latest): " version

    if [[ -f "$SCRIPT_DIR/update_n8n.sh" ]]; then
        "$SCRIPT_DIR/update_n8n.sh" "$version"
    else
        print_error "Update script not found!"
    fi

    read -p "Press Enter to continue..."
}

update_strapi() {
    show_header
    print_header "Update Strapi Dependencies"
    echo

    PROJECT_DIR="/root/scripts/mautic-n8n-stack-v5"

    if [[ ! -d "$PROJECT_DIR" ]]; then
        print_error "V5 not deployed yet"
        read -p "Press Enter to continue..."
        return
    fi

    print_status "Updating Strapi dependencies..."
    cd "$PROJECT_DIR"

    docker-compose exec strapi npm update --production
    docker-compose restart strapi

    print_success "Strapi dependencies updated!"
    read -p "Press Enter to continue..."
}

update_all_services() {
    show_header
    print_header "Update All Services"
    echo

    PROJECT_DIR="/root/scripts/mautic-n8n-stack-v5"

    if [[ ! -d "$PROJECT_DIR" ]]; then
        print_error "V5 not deployed yet"
        read -p "Press Enter to continue..."
        return
    fi

    print_warning "This will update all Docker images. Continue? (y/N)"
    read -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi

    cd "$PROJECT_DIR"

    print_status "Pulling latest images..."
    docker-compose pull

    print_status "Recreating containers..."
    docker-compose up -d

    print_status "Cleaning up old images..."
    docker image prune -f

    print_success "All services updated!"
    read -p "Press Enter to continue..."
}

# =============================================================================
# BACKUP
# =============================================================================

create_backup() {
    show_header

    if [[ -f "$SCRIPT_DIR/backup_now.sh" ]]; then
        "$SCRIPT_DIR/backup_now.sh"
    else
        print_error "Backup script not found!"
    fi

    read -p "Press Enter to continue..."
}

download_backup() {
    show_header

    if [[ -f "$SCRIPT_DIR/download_backup.sh" ]]; then
        "$SCRIPT_DIR/download_backup.sh"
    else
        print_error "Download script not found!"
    fi

    read -p "Press Enter to continue..."
}

list_backups() {
    show_header
    print_header "Available Backups"
    echo

    if [[ -d "/root/scripts/mautic-n8n-stack-v5/backups" ]]; then
        PROJECT_DIR="/root/scripts/mautic-n8n-stack-v5"
    elif [[ -d "/root/scripts/mautic-n8n-stack/backups" ]]; then
        PROJECT_DIR="/root/scripts/mautic-n8n-stack"
    else
        print_error "No backup directory found"
        read -p "Press Enter to continue..."
        return
    fi

    echo "Local Backups:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ls -lh "$PROJECT_DIR/backups/"*.tar.gz 2>/dev/null | awk '{print $9, "("$5")", $6, $7, $8}' | nl || echo "No backups found"
    echo

    read -p "Press Enter to continue..."
}

restore_backup() {
    show_header
    print_header "Restore from Backup"
    echo

    print_warning "⚠️  THIS WILL OVERWRITE CURRENT DATA!"
    echo
    print_error "This feature is for emergency use only."
    echo "Please refer to the migration guide for restore procedures."
    echo

    read -p "Press Enter to continue..."
}

# =============================================================================
# MONITORING
# =============================================================================

check_resources() {
    show_header

    if [[ -f "/root/scripts/check_resources_now.sh" ]]; then
        /root/scripts/check_resources_now.sh
    else
        print_header "VPS Resources"
        echo
        echo "CPU Usage:"
        top -bn1 | grep "Cpu(s)"
        echo
        echo "Memory:"
        free -h
        echo
        echo "Disk:"
        df -h /
        echo
        echo "Docker Containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Size}}"
    fi

    echo
    read -p "Press Enter to continue..."
}

setup_alerts() {
    show_header

    if [[ -f "$SCRIPT_DIR/setup_resource_alerts.sh" ]]; then
        "$SCRIPT_DIR/setup_resource_alerts.sh"
    else
        print_error "Alert setup script not found!"
    fi

    read -p "Press Enter to continue..."
}

open_grafana() {
    show_header
    print_header "Grafana Dashboard"
    echo

    if [[ -d "/root/scripts/mautic-n8n-stack-v5" ]]; then
        cd /root/scripts/mautic-n8n-stack-v5
        source .env 2>/dev/null

        SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

        echo "Grafana Dashboard URL:"
        echo "  https://monitor.${MAIN_DOMAIN:-yaicos.com}"
        echo
        echo "Login Credentials:"
        echo "  Username: admin"
        echo "  Password: ${GRAFANA_ADMIN_PASSWORD:-check .env file}"
        echo
    else
        print_error "V5 not deployed yet. Grafana not available."
    fi

    read -p "Press Enter to continue..."
}

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

view_status() {
    show_header
    print_header "Service Status"
    echo

    if [[ -d "/root/scripts/mautic-n8n-stack-v5" ]]; then
        PROJECT_DIR="/root/scripts/mautic-n8n-stack-v5"
    elif [[ -d "/root/scripts/mautic-n8n-stack" ]]; then
        PROJECT_DIR="/root/scripts/mautic-n8n-stack"
    else
        print_error "No project directory found"
        read -p "Press Enter to continue..."
        return
    fi

    cd "$PROJECT_DIR"
    docker-compose ps

    echo
    echo "Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

    echo
    read -p "Press Enter to continue..."
}

view_logs() {
    show_header
    print_header "View Logs"
    echo

    if [[ -d "/root/scripts/mautic-n8n-stack-v5" ]]; then
        PROJECT_DIR="/root/scripts/mautic-n8n-stack-v5"
    elif [[ -d "/root/scripts/mautic-n8n-stack" ]]; then
        PROJECT_DIR="/root/scripts/mautic-n8n-stack"
    else
        print_error "No project directory found"
        read -p "Press Enter to continue..."
        return
    fi

    cd "$PROJECT_DIR"

    echo "Available services:"
    docker-compose ps --services | nl
    echo

    read -p "Enter service name (or 'all'): " service

    if [[ "$service" == "all" ]]; then
        docker-compose logs --tail=50 -f
    else
        docker-compose logs --tail=100 -f "$service"
    fi
}

restart_services() {
    show_header
    print_header "Restart Services"
    echo

    if [[ -d "/root/scripts/mautic-n8n-stack-v5" ]]; then
        PROJECT_DIR="/root/scripts/mautic-n8n-stack-v5"
    elif [[ -d "/root/scripts/mautic-n8n-stack" ]]; then
        PROJECT_DIR="/root/scripts/mautic-n8n-stack"
    else
        print_error "No project directory found"
        read -p "Press Enter to continue..."
        return
    fi

    cd "$PROJECT_DIR"

    echo "Options:"
    echo "  1) Restart single service"
    echo "  2) Restart all services"
    echo
    read -p "Select: " restart_choice

    case $restart_choice in
        1)
            echo
            docker-compose ps --services | nl
            echo
            read -p "Enter service name: " service
            docker-compose restart "$service"
            print_success "$service restarted"
            ;;
        2)
            docker-compose restart
            print_success "All services restarted"
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac

    echo
    read -p "Press Enter to continue..."
}

# =============================================================================
# DOCUMENTATION
# =============================================================================

view_documentation() {
    show_header
    print_header "Documentation"
    echo

    echo "Available Documentation:"
    echo "  1) Quick Start Guide"
    echo "  2) Full Migration Guide"
    echo "  3) Mautic Config Reference"
    echo "  4) README"
    echo "  5) Production Deployment Plan"
    echo
    read -p "Select document (1-5): " doc_choice

    case $doc_choice in
        1) less "$SCRIPT_DIR/QUICK_START.md" ;;
        2) less "$SCRIPT_DIR/V5_MIGRATION_GUIDE.md" ;;
        3) less "$SCRIPT_DIR/MAUTIC_CONFIG_REFERENCE.md" ;;
        4) less "$SCRIPT_DIR/README.md" ;;
        5) less "$SCRIPT_DIR/PRODUCTION_DEPLOYMENT_PLAN.md" ;;
        *) print_error "Invalid choice" ;;
    esac
}

show_service_info() {
    show_header
    print_header "Service URLs & Credentials"
    echo

    if [[ -d "/root/scripts/mautic-n8n-stack-v5" ]]; then
        cd /root/scripts/mautic-n8n-stack-v5
        source .env 2>/dev/null

        SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

        echo "🌐 Service URLs:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Mautic:     https://${MAUTIC_URL}"
        echo "  n8n:        https://${N8N_URL}"
        echo "  Strapi:     https://${STRAPI_URL}/admin"
        echo "  Grafana:    https://monitor.${MAIN_DOMAIN}"
        echo "  Traefik:    http://${SERVER_IP}:8080"
        echo
        echo "🔑 Credentials:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Grafana Admin:"
        echo "    Username: admin"
        echo "    Password: ${GRAFANA_ADMIN_PASSWORD}"
        echo
        echo "  Database Passwords (stored in .env):"
        echo "    MySQL Root:  ${MYSQL_ROOT_PASSWORD:0:20}..."
        echo "    PostgreSQL:  ${POSTGRES_PASSWORD:0:20}..."
        echo
        echo "💡 Tip: Full credentials in /root/scripts/mautic-n8n-stack-v5/.env"
        echo
    else
        print_error "V5 not deployed yet"
    fi

    echo
    read -p "Press Enter to continue..."
}

# =============================================================================
# MAIN LOOP
# =============================================================================

main() {
    while true; do
        show_main_menu

        case $choice in
            # V4 Menu (not deployed)
            1)
                if [[ "$V5_DEPLOYED" == "false" ]]; then
                    migrate_to_v5
                else
                    update_n8n
                fi
                ;;
            2)
                if [[ "$V5_DEPLOYED" == "false" ]]; then
                    view_documentation
                else
                    update_strapi
                fi
                ;;

            # V5 Menu (deployed)
            3) [[ "$V5_DEPLOYED" == "true" ]] && update_all_services ;;
            4) [[ "$V5_DEPLOYED" == "true" ]] && create_backup ;;
            5) [[ "$V5_DEPLOYED" == "true" ]] && download_backup ;;
            6) [[ "$V5_DEPLOYED" == "true" ]] && list_backups ;;
            7) [[ "$V5_DEPLOYED" == "true" ]] && restore_backup ;;
            8) [[ "$V5_DEPLOYED" == "true" ]] && check_resources ;;
            9) [[ "$V5_DEPLOYED" == "true" ]] && setup_alerts ;;
            10) [[ "$V5_DEPLOYED" == "true" ]] && open_grafana ;;
            11) [[ "$V5_DEPLOYED" == "true" ]] && view_status ;;
            12) [[ "$V5_DEPLOYED" == "true" ]] && view_logs ;;
            13) [[ "$V5_DEPLOYED" == "true" ]] && restart_services ;;
            14) [[ "$V5_DEPLOYED" == "true" ]] && view_documentation ;;
            15) [[ "$V5_DEPLOYED" == "true" ]] && show_service_info ;;

            q|Q)
                clear
                print_success "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

main "$@"
