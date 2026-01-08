#!/bin/bash

# =============================================================================
# Security Audit Script for Docker Stacks
# Version: 1.0
# Compatible with: V3/V4 Mautic + n8n + Strapi Stack
# =============================================================================
#
# USAGE:
#   ./security_audit.sh              # Run audit only
#   ./security_audit.sh --fix        # Run audit and auto-fix issues
#   ./security_audit.sh --json       # Output JSON report
#   ./security_audit.sh --help       # Show help
#
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

# Script config
SCRIPT_VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/mautic-n8n-stack"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/.env"
REPORT_FILE="$SCRIPT_DIR/security_audit_$(date +%Y%m%d_%H%M%S).txt"
JSON_FILE="$SCRIPT_DIR/security_audit_$(date +%Y%m%d_%H%M%S).json"

# Counters
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

# Flags
AUTO_FIX=false
JSON_OUTPUT=false
VERBOSE=false

# Arrays for JSON
declare -a RESULTS=()
declare -a FIXES_AVAILABLE=()

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

print_banner() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              SECURITY AUDIT SCRIPT v$SCRIPT_VERSION                     ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${CYAN}${BOLD}[$1]${NC}"
    echo "─────────────────────────────────────────"
}

print_pass() {
    echo -e "${GREEN}✅ PASS${NC}  $1"
    ((PASS_COUNT++))
    ((TOTAL_COUNT++))
    RESULTS+=("{\"check\":\"$1\",\"status\":\"pass\",\"category\":\"$CURRENT_CATEGORY\"}")
}

print_fail() {
    echo -e "${RED}❌ FAIL${NC}  $1"
    ((FAIL_COUNT++))
    ((TOTAL_COUNT++))
    RESULTS+=("{\"check\":\"$1\",\"status\":\"fail\",\"category\":\"$CURRENT_CATEGORY\",\"fix\":\"$2\"}")
    [[ -n "$2" ]] && FIXES_AVAILABLE+=("$2")
}

print_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}  $1"
    ((WARN_COUNT++))
    ((TOTAL_COUNT++))
    RESULTS+=("{\"check\":\"$1\",\"status\":\"warn\",\"category\":\"$CURRENT_CATEGORY\",\"fix\":\"$2\"}")
    [[ -n "$2" ]] && FIXES_AVAILABLE+=("$2")
}

print_info() {
    echo -e "${BLUE}ℹ️  INFO${NC}  $1"
}

print_skip() {
    echo -e "${PURPLE}⏭️  SKIP${NC}  $1"
}

check_root() {
    [[ $EUID -eq 0 ]] && return 0 || return 1
}

get_server_ip() {
    curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s icanhazip.com 2>/dev/null || echo "unknown"
}

show_help() {
    echo "Security Audit Script v$SCRIPT_VERSION"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --fix       Auto-fix common security issues"
    echo "  --json      Output results as JSON"
    echo "  --verbose   Show detailed output"
    echo "  --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Run audit"
    echo "  $0 --fix        # Run audit and fix issues"
    echo "  $0 --json       # Output JSON report"
    exit 0
}

# =============================================================================
# SERVER HARDENING CHECKS
# =============================================================================

check_server_hardening() {
    CURRENT_CATEGORY="Server Hardening"
    print_section "SERVER HARDENING"
    
    # SSH Key-only authentication
    if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
        print_pass "SSH password authentication disabled"
    elif grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
        print_fail "SSH password authentication enabled" "Disable password auth in /etc/ssh/sshd_config"
    else
        print_warn "SSH password authentication status unclear" "Check /etc/ssh/sshd_config"
    fi
    
    # SSH Root login
    if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
        print_pass "SSH root login disabled"
    elif grep -q "^PermitRootLogin prohibit-password" /etc/ssh/sshd_config 2>/dev/null; then
        print_pass "SSH root login key-only"
    elif grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        print_warn "SSH root login with password allowed" "Set PermitRootLogin to 'no' or 'prohibit-password'"
    else
        print_info "SSH root login using default settings"
    fi
    
    # Firewall (UFW)
    if command -v ufw &>/dev/null; then
        if ufw status | grep -q "Status: active"; then
            print_pass "UFW firewall active"
            
            # Check open ports
            local open_ports=$(ufw status | grep -c "ALLOW")
            if [[ $open_ports -le 5 ]]; then
                print_pass "Minimal ports open ($open_ports rules)"
            else
                print_warn "$open_ports firewall rules - review if all needed"
            fi
            
            # Check specific dangerous ports
            if ufw status | grep -q "3306.*ALLOW.*Anywhere"; then
                print_fail "MySQL port 3306 exposed to internet" "ufw delete allow 3306"
            fi
            if ufw status | grep -q "5432.*ALLOW.*Anywhere"; then
                print_fail "PostgreSQL port 5432 exposed to internet" "ufw delete allow 5432"
            fi
            if ufw status | grep -q "15672.*ALLOW.*Anywhere"; then
                print_fail "RabbitMQ management port exposed" "ufw delete allow 15672"
            fi
        else
            print_fail "UFW firewall not active" "ufw enable"
        fi
    else
        print_fail "UFW firewall not installed" "apt install ufw && ufw enable"
    fi
    
    # Fail2ban
    if command -v fail2ban-client &>/dev/null; then
        if systemctl is-active --quiet fail2ban 2>/dev/null; then
            print_pass "Fail2ban active"
            
            # Check if SSH jail is enabled
            if fail2ban-client status sshd &>/dev/null; then
                print_pass "Fail2ban SSH jail enabled"
            else
                print_warn "Fail2ban SSH jail not configured" "Configure sshd jail"
            fi
        else
            print_fail "Fail2ban installed but not running" "systemctl start fail2ban && systemctl enable fail2ban"
        fi
    else
        print_fail "Fail2ban not installed" "apt install fail2ban"
    fi
    
    # Unattended upgrades
    if dpkg -l | grep -q unattended-upgrades; then
        if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
            if grep -q 'APT::Periodic::Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null; then
                print_pass "Unattended security upgrades enabled"
            else
                print_warn "Unattended upgrades installed but not enabled" "dpkg-reconfigure unattended-upgrades"
            fi
        else
            print_warn "Unattended upgrades not configured" "dpkg-reconfigure unattended-upgrades"
        fi
    else
        print_warn "Unattended upgrades not installed" "apt install unattended-upgrades"
    fi
    
    # Pending security updates
    if command -v apt &>/dev/null; then
        local security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
        if [[ $security_updates -eq 0 ]]; then
            print_pass "No pending security updates"
        else
            print_warn "$security_updates pending security updates" "apt update && apt upgrade -y"
        fi
    fi
    
    # System restart required
    if [[ -f /var/run/reboot-required ]]; then
        print_warn "System restart required" "reboot"
    else
        print_pass "No restart required"
    fi
}

# =============================================================================
# DOCKER SECURITY CHECKS
# =============================================================================

check_docker_security() {
    CURRENT_CATEGORY="Docker Security"
    print_section "DOCKER SECURITY"
    
    # Check if Docker is running
    if ! systemctl is-active --quiet docker 2>/dev/null; then
        print_fail "Docker not running"
        return
    fi
    
    print_pass "Docker service running"
    
    # Docker socket permissions
    local socket_perms=$(stat -c %a /var/run/docker.sock 2>/dev/null)
    if [[ "$socket_perms" == "660" ]] || [[ "$socket_perms" == "600" ]]; then
        print_pass "Docker socket permissions secure ($socket_perms)"
    else
        print_warn "Docker socket permissions: $socket_perms (recommended: 660)" "chmod 660 /var/run/docker.sock"
    fi
    
    # Check for containers running as root
    if [[ -f "$COMPOSE_FILE" ]]; then
        local root_containers=0
        for container in $(docker-compose -f "$COMPOSE_FILE" ps -q 2>/dev/null); do
            local user=$(docker inspect --format '{{.Config.User}}' "$container" 2>/dev/null)
            if [[ -z "$user" ]] || [[ "$user" == "root" ]] || [[ "$user" == "0" ]]; then
                ((root_containers++))
            fi
        done
        
        if [[ $root_containers -eq 0 ]]; then
            print_pass "No containers running as root"
        else
            print_info "$root_containers containers running as root (some may require it)"
        fi
    fi
    
    # Check for --privileged containers
    local privileged=$(docker ps --format '{{.Names}}' | while read name; do
        docker inspect "$name" --format '{{.HostConfig.Privileged}}' 2>/dev/null | grep -c "true"
    done | awk '{s+=$1} END {print s}')
    
    if [[ "$privileged" -eq 0 ]] || [[ -z "$privileged" ]]; then
        print_pass "No privileged containers"
    else
        print_fail "$privileged privileged containers found" "Remove --privileged flag unless absolutely necessary"
    fi
    
    # Memory limits
    if [[ -f "$COMPOSE_FILE" ]]; then
        if grep -q "mem_limit\|memory:" "$COMPOSE_FILE" 2>/dev/null; then
            print_pass "Memory limits configured"
        else
            print_warn "No memory limits set for containers" "Add mem_limit to docker-compose.yml"
        fi
    fi
    
    # Docker images using :latest
    local latest_count=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -c ":latest" || echo "0")
    if [[ $latest_count -le 2 ]]; then
        print_pass "Minimal use of :latest tags ($latest_count)"
    else
        print_warn "$latest_count images using :latest tag" "Use specific version tags for production"
    fi
    
    # Unused Docker images
    local dangling=$(docker images -f "dangling=true" -q | wc -l)
    if [[ $dangling -eq 0 ]]; then
        print_pass "No dangling images"
    else
        print_info "$dangling dangling images (run: docker image prune)"
    fi
    
    # Docker network isolation
    if docker network ls | grep -q "mautic_network\|bridge"; then
        print_pass "Custom Docker network in use"
    fi
}

# =============================================================================
# DATABASE SECURITY CHECKS
# =============================================================================

check_database_security() {
    CURRENT_CATEGORY="Database Security"
    print_section "DATABASE SECURITY"
    
    # Check MySQL port exposure
    if ss -tlnp | grep -q ":3306.*LISTEN"; then
        local mysql_bind=$(ss -tlnp | grep ":3306" | head -1)
        if echo "$mysql_bind" | grep -q "127.0.0.1:3306\|0.0.0.0:3306"; then
            if docker ps --format '{{.Names}}' | grep -q "mysql"; then
                print_pass "MySQL running in Docker (isolated)"
            else
                print_fail "MySQL exposed on host" "Bind MySQL to 127.0.0.1 only"
            fi
        fi
    else
        print_pass "MySQL not exposed on host network"
    fi
    
    # Check PostgreSQL port exposure
    if ss -tlnp | grep -q ":5432.*LISTEN"; then
        if docker ps --format '{{.Names}}' | grep -q "postgres"; then
            print_pass "PostgreSQL running in Docker (isolated)"
        else
            print_warn "PostgreSQL exposed on host"
        fi
    else
        print_pass "PostgreSQL not exposed on host network"
    fi
    
    # Check RabbitMQ management port
    if ss -tlnp | grep -q ":15672.*LISTEN"; then
        print_warn "RabbitMQ management UI accessible" "Consider disabling or restricting access"
    else
        print_pass "RabbitMQ management UI not exposed"
    fi
    
    # Check password strength in .env
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE" 2>/dev/null
        
        # MySQL root password
        if [[ -n "$MYSQL_ROOT_PASSWORD" ]]; then
            local mysql_len=${#MYSQL_ROOT_PASSWORD}
            if [[ $mysql_len -ge 32 ]]; then
                print_pass "MySQL root password strong ($mysql_len chars)"
            elif [[ $mysql_len -ge 16 ]]; then
                print_warn "MySQL root password could be stronger ($mysql_len chars)"
            else
                print_fail "MySQL root password too weak ($mysql_len chars)" "Use 32+ character password"
            fi
        fi
        
        # PostgreSQL password
        if [[ -n "$POSTGRES_PASSWORD" ]]; then
            local pg_len=${#POSTGRES_PASSWORD}
            if [[ $pg_len -ge 32 ]]; then
                print_pass "PostgreSQL password strong ($pg_len chars)"
            elif [[ $pg_len -ge 16 ]]; then
                print_warn "PostgreSQL password could be stronger ($pg_len chars)"
            else
                print_fail "PostgreSQL password too weak ($pg_len chars)" "Use 32+ character password"
            fi
        fi
    else
        print_skip "Environment file not found"
    fi
    
    # Check for recent backups
    if [[ -d "$PROJECT_DIR/backups" ]]; then
        local recent_backup=$(find "$PROJECT_DIR/backups" -name "*.tar.gz" -mtime -7 | head -1)
        if [[ -n "$recent_backup" ]]; then
            print_pass "Recent backup exists (within 7 days)"
        else
            print_warn "No recent backups found" "Create backup: ./v4_supercharged_deploy.sh → Backup"
        fi
    else
        print_warn "No backup directory found"
    fi
}

# =============================================================================
# SSL/TLS CHECKS
# =============================================================================

check_ssl_tls() {
    CURRENT_CATEGORY="SSL/TLS"
    print_section "SSL/TLS SECURITY"
    
    # Load domains from env
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE" 2>/dev/null
    fi
    
    local domains=("${MAUTIC_URL:-}" "${N8N_URL:-}" "${STRAPI_URL:-}")
    
    for domain in "${domains[@]}"; do
        [[ -z "$domain" ]] && continue
        
        # Check if domain resolves
        if ! host "$domain" &>/dev/null; then
            print_skip "$domain - DNS not resolving"
            continue
        fi
        
        # Check HTTPS
        local https_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$domain" 2>/dev/null)
        if [[ "$https_status" =~ ^(200|301|302|303|307|308)$ ]]; then
            print_pass "$domain - HTTPS working"
        else
            print_fail "$domain - HTTPS not working (status: $https_status)"
            continue
        fi
        
        # Check HTTP redirect
        local http_redirect=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 10 "http://$domain" 2>/dev/null)
        if [[ "$http_redirect" == https://* ]]; then
            print_pass "$domain - HTTP redirects to HTTPS"
        else
            print_warn "$domain - HTTP not redirecting to HTTPS"
        fi
        
        # Check certificate expiry
        local cert_expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        if [[ -n "$cert_expiry" ]]; then
            local expiry_epoch=$(date -d "$cert_expiry" +%s 2>/dev/null)
            local now_epoch=$(date +%s)
            local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
            
            if [[ $days_left -gt 30 ]]; then
                print_pass "$domain - Certificate valid ($days_left days)"
            elif [[ $days_left -gt 7 ]]; then
                print_warn "$domain - Certificate expiring soon ($days_left days)"
            else
                print_fail "$domain - Certificate expiring in $days_left days!" "Renew certificate"
            fi
        fi
        
        # Check TLS version
        local tls12=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" -tls1_2 2>/dev/null | grep -c "Protocol.*TLSv1.2")
        local tls13=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" -tls1_3 2>/dev/null | grep -c "Protocol.*TLSv1.3")
        
        if [[ $tls13 -gt 0 ]]; then
            print_pass "$domain - TLS 1.3 supported"
        elif [[ $tls12 -gt 0 ]]; then
            print_pass "$domain - TLS 1.2 supported"
        fi
    done
    
    # Check for insecure TLS versions
    if [[ -f "$COMPOSE_FILE" ]]; then
        if grep -q "minVersion.*1.0\|minVersion.*1.1" "$COMPOSE_FILE" 2>/dev/null; then
            print_fail "Insecure TLS versions allowed in config" "Set minimum TLS to 1.2"
        fi
    fi
}

# =============================================================================
# API SECURITY CHECKS
# =============================================================================

check_api_security() {
    CURRENT_CATEGORY="API Security"
    print_section "API SECURITY (Strapi)"
    
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE" 2>/dev/null
    fi
    
    local strapi_url="${STRAPI_URL:-}"
    
    if [[ -z "$strapi_url" ]]; then
        print_skip "Strapi URL not configured"
        return
    fi
    
    # Check if Strapi is accessible
    local strapi_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$strapi_url" 2>/dev/null)
    if [[ "$strapi_status" != "200" ]] && [[ "$strapi_status" != "404" ]]; then
        print_skip "Strapi not accessible (status: $strapi_status)"
        return
    fi
    
    # Check CORS configuration
    if [[ -f "$PROJECT_DIR/strapi/config/middlewares.js" ]]; then
        if grep -q "origin.*\*" "$PROJECT_DIR/strapi/config/middlewares.js" 2>/dev/null; then
            print_fail "CORS allows all origins (*)" "Specify exact domains in middlewares.js"
        elif grep -q "origin:" "$PROJECT_DIR/strapi/config/middlewares.js" 2>/dev/null; then
            print_pass "CORS configured with specific origins"
        else
            print_warn "CORS configuration not found"
        fi
    fi
    
    # Check admin panel path
    local admin_check=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$strapi_url/admin" 2>/dev/null)
    if [[ "$admin_check" == "200" ]] || [[ "$admin_check" == "301" ]] || [[ "$admin_check" == "302" ]]; then
        print_info "Admin panel at default /admin path (consider changing for security)"
    fi
    
    # Check public API exposure
    local public_api=$(curl -s --max-time 10 "https://$strapi_url/api/guardscan-articles" 2>/dev/null)
    if echo "$public_api" | grep -q "data"; then
        print_info "Public API accessible (expected for blog)"
    elif echo "$public_api" | grep -q "Forbidden\|Unauthorized"; then
        print_pass "API requires authentication"
    fi
    
    # Check rate limiting in middlewares
    if [[ -f "$PROJECT_DIR/strapi/config/middlewares.js" ]]; then
        if grep -q "rateLimit\|rate-limit" "$PROJECT_DIR/strapi/config/middlewares.js" 2>/dev/null; then
            print_pass "Rate limiting configured"
        else
            print_warn "No rate limiting configured" "Add rate limiting middleware"
        fi
    fi
    
    # Check for exposed API keys in env
    if [[ -f "$ENV_FILE" ]]; then
        local env_perms=$(stat -c %a "$ENV_FILE" 2>/dev/null)
        if [[ "$env_perms" == "600" ]]; then
            print_pass "Environment file permissions secure (600)"
        else
            print_fail "Environment file permissions too open ($env_perms)" "chmod 600 $ENV_FILE"
        fi
    fi
}

# =============================================================================
# APPLICATION SECURITY CHECKS
# =============================================================================

check_application_security() {
    CURRENT_CATEGORY="Application Security"
    print_section "APPLICATION SECURITY"
    
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE" 2>/dev/null
    fi
    
    # Traefik dashboard
    local traefik_dash=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://$(get_server_ip):8080" 2>/dev/null)
    if [[ "$traefik_dash" == "200" ]]; then
        print_warn "Traefik dashboard publicly accessible on :8080" "Restrict or disable dashboard"
    else
        print_pass "Traefik dashboard not publicly accessible"
    fi
    
    # Check Mautic
    if [[ -n "${MAUTIC_URL:-}" ]]; then
        local mautic_login=$(curl -s --max-time 10 "https://$MAUTIC_URL/s/login" 2>/dev/null)
        if echo "$mautic_login" | grep -q "login\|mautic"; then
            print_pass "Mautic login page accessible"
        fi
    fi
    
    # Check n8n
    if [[ -n "${N8N_URL:-}" ]]; then
        local n8n_check=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$N8N_URL" 2>/dev/null)
        if [[ "$n8n_check" == "200" ]]; then
            print_pass "n8n accessible"
        fi
        
        # Check if n8n webhooks are protected
        if [[ -f "$COMPOSE_FILE" ]]; then
            if grep -q "N8N_BASIC_AUTH_ACTIVE.*true" "$COMPOSE_FILE" 2>/dev/null || grep -q "N8N_BASIC_AUTH_ACTIVE.*true" "$ENV_FILE" 2>/dev/null; then
                print_pass "n8n basic auth enabled"
            else
                print_info "n8n basic auth not enabled (uses built-in auth)"
            fi
        fi
    fi
    
    # Docker compose file permissions
    if [[ -f "$COMPOSE_FILE" ]]; then
        local compose_perms=$(stat -c %a "$COMPOSE_FILE" 2>/dev/null)
        if [[ "$compose_perms" == "600" ]] || [[ "$compose_perms" == "644" ]]; then
            print_pass "Docker compose file permissions OK ($compose_perms)"
        else
            print_warn "Docker compose file permissions: $compose_perms"
        fi
    fi
    
    # Check for hardcoded secrets in compose
    if [[ -f "$COMPOSE_FILE" ]]; then
        if grep -E "password:|PASSWORD=|secret:|SECRET=" "$COMPOSE_FILE" 2>/dev/null | grep -v '\${' | grep -q .; then
            print_fail "Hardcoded secrets in docker-compose.yml" "Use environment variables"
        else
            print_pass "No hardcoded secrets in docker-compose.yml"
        fi
    fi
}

# =============================================================================
# LOGGING & MONITORING CHECKS
# =============================================================================

check_logging_monitoring() {
    CURRENT_CATEGORY="Logging & Monitoring"
    print_section "LOGGING & MONITORING"
    
    # Check disk space
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    if [[ $disk_usage -lt 80 ]]; then
        print_pass "Disk usage OK ($disk_usage%)"
    elif [[ $disk_usage -lt 90 ]]; then
        print_warn "Disk usage high ($disk_usage%)" "Clean up disk space"
    else
        print_fail "Disk usage critical ($disk_usage%)" "Immediate cleanup required"
    fi
    
    # Check memory
    local mem_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
    if [[ $mem_usage -lt 80 ]]; then
        print_pass "Memory usage OK ($mem_usage%)"
    elif [[ $mem_usage -lt 90 ]]; then
        print_warn "Memory usage high ($mem_usage%)"
    else
        print_fail "Memory usage critical ($mem_usage%)"
    fi
    
    # Check swap
    local swap_total=$(free | awk '/Swap:/ {print $2}')
    if [[ $swap_total -gt 0 ]]; then
        print_pass "Swap configured"
    else
        print_info "No swap configured (optional for 8GB+ RAM)"
    fi
    
    # Check Docker logs size
    local docker_logs_size=$(du -sh /var/lib/docker/containers 2>/dev/null | cut -f1)
    if [[ -n "$docker_logs_size" ]]; then
        print_info "Docker logs size: $docker_logs_size"
    fi
    
    # Check log rotation
    if [[ -f /etc/docker/daemon.json ]]; then
        if grep -q "log-driver\|max-size" /etc/docker/daemon.json 2>/dev/null; then
            print_pass "Docker log rotation configured"
        else
            print_warn "Docker log rotation not configured" "Configure log rotation in /etc/docker/daemon.json"
        fi
    else
        print_warn "No Docker daemon.json config" "Configure log rotation"
    fi
    
    # Check system logs
    if systemctl is-active --quiet rsyslog 2>/dev/null || systemctl is-active --quiet systemd-journald 2>/dev/null; then
        print_pass "System logging active"
    else
        print_warn "System logging may not be active"
    fi
}

# =============================================================================
# AUTO-FIX FUNCTIONS
# =============================================================================

apply_fixes() {
    echo ""
    print_section "APPLYING FIXES"
    
    # Install fail2ban if missing
    if ! command -v fail2ban-client &>/dev/null; then
        print_info "Installing fail2ban..."
        apt-get update -qq && apt-get install -y -qq fail2ban
        systemctl enable fail2ban
        systemctl start fail2ban
        print_pass "Fail2ban installed and started"
    fi
    
    # Enable UFW if not active
    if command -v ufw &>/dev/null; then
        if ! ufw status | grep -q "Status: active"; then
            print_info "Enabling UFW firewall..."
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow 22/tcp
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw --force enable
            print_pass "UFW enabled with default rules"
        fi
    fi
    
    # Fix environment file permissions
    if [[ -f "$ENV_FILE" ]]; then
        local env_perms=$(stat -c %a "$ENV_FILE" 2>/dev/null)
        if [[ "$env_perms" != "600" ]]; then
            chmod 600 "$ENV_FILE"
            print_pass "Fixed .env file permissions"
        fi
    fi
    
    # Install unattended-upgrades
    if ! dpkg -l | grep -q unattended-upgrades; then
        print_info "Installing unattended-upgrades..."
        apt-get update -qq && apt-get install -y -qq unattended-upgrades
        echo 'APT::Periodic::Update-Package-Lists "1";' > /etc/apt/apt.conf.d/20auto-upgrades
        echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
        print_pass "Unattended upgrades installed and enabled"
    fi
    
    # Configure Docker log rotation
    if [[ ! -f /etc/docker/daemon.json ]]; then
        cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
        systemctl restart docker
        print_pass "Docker log rotation configured"
    fi
    
    print_info "Fixes applied. Re-run audit to verify."
}

# =============================================================================
# REPORT GENERATION
# =============================================================================

generate_summary() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                        SUMMARY                                 ${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}Passed:${NC}   $PASS_COUNT"
    echo -e "  ${YELLOW}Warnings:${NC} $WARN_COUNT"
    echo -e "  ${RED}Failed:${NC}   $FAIL_COUNT"
    echo -e "  ${BLUE}Total:${NC}    $TOTAL_COUNT"
    echo ""
    
    if [[ $FAIL_COUNT -eq 0 ]] && [[ $WARN_COUNT -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✅ ALL CHECKS PASSED - System is production ready!${NC}"
    elif [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "${YELLOW}${BOLD}⚠️  $WARN_COUNT warnings - Review recommended${NC}"
    else
        echo -e "${RED}${BOLD}❌ $FAIL_COUNT critical issues - Fix before production!${NC}"
    fi
    
    echo ""
    
    if [[ ${#FIXES_AVAILABLE[@]} -gt 0 ]] && [[ "$AUTO_FIX" == "false" ]]; then
        echo -e "${CYAN}${BOLD}Auto-fix available for ${#FIXES_AVAILABLE[@]} issues.${NC}"
        echo -e "Run: ${BOLD}$0 --fix${NC}"
        echo ""
    fi
}

generate_json_report() {
    local results_json=$(printf '%s\n' "${RESULTS[@]}" | paste -sd ',' -)
    
    cat > "$JSON_FILE" << EOF
{
  "audit_version": "$SCRIPT_VERSION",
  "timestamp": "$(date -Iseconds)",
  "server_ip": "$(get_server_ip)",
  "summary": {
    "passed": $PASS_COUNT,
    "warnings": $WARN_COUNT,
    "failed": $FAIL_COUNT,
    "total": $TOTAL_COUNT
  },
  "results": [$results_json]
}
EOF
    
    echo ""
    print_info "JSON report saved: $JSON_FILE"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fix)
                AUTO_FIX=true
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                ;;
        esac
    done
    
    # Check if running as root
    if ! check_root; then
        echo -e "${YELLOW}Warning: Running without root. Some checks may be limited.${NC}"
        echo ""
    fi
    
    print_banner
    
    echo -e "${BLUE}Server:${NC} $(get_server_ip)"
    echo -e "${BLUE}Date:${NC}   $(date)"
    echo -e "${BLUE}Stack:${NC}  V4 Supercharged"
    
    # Run all checks
    check_server_hardening
    check_docker_security
    check_database_security
    check_ssl_tls
    check_api_security
    check_application_security
    check_logging_monitoring
    
    # Apply fixes if requested
    if [[ "$AUTO_FIX" == "true" ]]; then
        apply_fixes
    fi
    
    # Generate summary
    generate_summary
    
    # Generate JSON if requested
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        generate_json_report
    fi
    
    # Exit code based on results
    if [[ $FAIL_COUNT -gt 0 ]]; then
        exit 2
    elif [[ $WARN_COUNT -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main
main "$@"
