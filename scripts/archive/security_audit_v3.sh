#!/usr/bin/env bash

# =============================================================================
# Security Audit Script v2.1 with Auto-Fix
# Features:
# - Industry standard security checks
# - Auto-fix capability (--fix flag)
# - JSON/CSV reports
# - Exit codes: 0=pass, 1=warn, 2=fail
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# CONFIGURATION
# =============================================================================
readonly SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
readonly SCRIPT_VERSION="2.1"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configurable paths
readonly PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"
readonly DOCKER_COMPOSE_FILE="${DOCKER_COMPOSE_FILE:-$PROJECT_DIR/docker-compose.yml}"
readonly ENV_FILE="${ENV_FILE:-$PROJECT_DIR/.env}"
readonly OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/reports}"
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"

# =============================================================================
# LOGGING
# =============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "ERROR") echo -e "${RED}[$timestamp] [ERROR] $message${NC}" >&2 ;;
        "WARN")  echo -e "${YELLOW}[$timestamp] [WARN]  $message${NC}" ;;
        "INFO")  [[ "$LOG_LEVEL" =~ ^(INFO|DEBUG)$ ]] && echo -e "${BLUE}[$timestamp] [INFO]  $message${NC}" ;;
        "DEBUG") [[ "$LOG_LEVEL" == "DEBUG" ]] && echo -e "[$timestamp] [DEBUG] $message" ;;
        "SUCCESS") echo -e "${GREEN}[$timestamp] [✓] $message${NC}" ;;
        "FIX") echo -e "${CYAN}[$timestamp] [🔧] $message${NC}" ;;
        *) echo "[$timestamp] [$level] $message" ;;
    esac
}

# =============================================================================
# AUDIT RESULTS & FIX TRACKING
# =============================================================================
declare -A AUDIT_RESULTS
declare -a FAILED_CHECKS=()
declare -a WARNING_CHECKS=()
declare -a PASSED_CHECKS=()
declare -a FIXES_APPLIED=()

record_result() {
    local check_id="$1"
    local status="$2"
    local message="$3"
    local remediation="${4:-}"
    local severity="${5:-MEDIUM}"
    local auto_fix_cmd="${6:-}"
    
    AUDIT_RESULTS["${check_id}_status"]="$status"
    AUDIT_RESULTS["${check_id}_message"]="$message"
    AUDIT_RESULTS["${check_id}_remediation"]="$remediation"
    AUDIT_RESULTS["${check_id}_severity"]="$severity"
    AUDIT_RESULTS["${check_id}_auto_fix"]="$auto_fix_cmd"
    AUDIT_RESULTS["${check_id}_timestamp"]=$(date -Iseconds)
    
    case "$status" in
        "PASS") 
            PASSED_CHECKS+=("$check_id")
            log "SUCCESS" "$message"
            ;;
        "FAIL") 
            FAILED_CHECKS+=("$check_id")
            log "ERROR" "$message"
            [[ -n "$remediation" ]] && log "INFO" "  Remediation: $remediation"
            [[ -n "$auto_fix_cmd" ]] && log "INFO" "  Auto-fix available with --fix flag"
            ;;
        "WARN") 
            WARNING_CHECKS+=("$check_id")
            log "WARN" "$message"
            [[ -n "$remediation" ]] && log "INFO" "  Suggestion: $remediation"
            [[ -n "$auto_fix_cmd" ]] && log "INFO" "  Auto-fix available with --fix flag"
            ;;
    esac
}

# =============================================================================
# SECURITY CHECKS WITH AUTO-FIX COMMANDS
# =============================================================================

check_ssh_hardening() {
    local sshd_config="/etc/ssh/sshd_config"
    
    if [[ ! -r "$sshd_config" ]]; then
        record_result "ssh_001" "WARN" "SSH config not found or not readable"
        return
    fi
    
    # Password authentication
    if grep -q "^PasswordAuthentication no" "$sshd_config" 2>/dev/null; then
        record_result "ssh_001a" "PASS" "SSH password authentication disabled"
    else
        record_result "ssh_001a" "FAIL" "SSH password authentication may be enabled" \
            "Set 'PasswordAuthentication no' in $sshd_config" \
            "HIGH" "sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' '$sshd_config' && systemctl restart ssh"
    fi
    
    # Root login
    if grep -q "^PermitRootLogin no" "$sshd_config" 2>/dev/null; then
        record_result "ssh_001b" "PASS" "SSH root login disabled"
    else
        record_result "ssh_001b" "FAIL" "SSH root login may be allowed" \
            "Set 'PermitRootLogin no' in $sshd_config" \
            "HIGH" "sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' '$sshd_config' && systemctl restart ssh"
    fi
}

check_firewall() {
    # Check UFW
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            record_result "fw_001" "PASS" "UFW firewall is active"
        else
            record_result "fw_001" "FAIL" "UFW is installed but not active" \
                "Run: ufw enable" \
                "HIGH" "ufw default deny incoming && ufw default allow outgoing && ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 443/tcp && ufw --force enable"
        fi
        
        # Check for dangerous open ports
        if ufw status | grep -q "3306.*ALLOW.*Anywhere"; then
            record_result "fw_002" "FAIL" "MySQL port 3306 exposed to internet" \
                "Remove: ufw delete allow 3306" \
                "CRITICAL" "ufw delete allow 3306"
        fi
        
        if ufw status | grep -q "5432.*ALLOW.*Anywhere"; then
            record_result "fw_003" "FAIL" "PostgreSQL port 5432 exposed to internet" \
                "Remove: ufw delete allow 5432" \
                "CRITICAL" "ufw delete allow 5432"
        fi
        
    else
        record_result "fw_001" "FAIL" "UFW firewall not installed" \
            "Install with: apt install ufw" \
            "HIGH" "apt-get update && apt-get install -y ufw"
    fi
}

check_fail2ban() {
    if command -v fail2ban-client >/dev/null 2>&1; then
        if systemctl is-active --quiet fail2ban; then
            record_result "fail2ban_001" "PASS" "Fail2ban active"
        else
            record_result "fail2ban_001" "FAIL" "Fail2ban installed but not running" \
                "Start: systemctl start fail2ban" \
                "MEDIUM" "systemctl start fail2ban && systemctl enable fail2ban"
        fi
    else
        record_result "fail2ban_001" "FAIL" "Fail2ban not installed" \
            "Install: apt install fail2ban" \
            "MEDIUM" "apt-get update && apt-get install -y fail2ban"
    fi
}

check_unattended_upgrades() {
    if dpkg -l | grep -q unattended-upgrades; then
        if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
            if grep -q 'APT::Periodic::Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null; then
                record_result "updates_001" "PASS" "Unattended security upgrades enabled"
            else
                record_result "updates_001" "WARN" "Unattended upgrades installed but not enabled" \
                    "Enable: dpkg-reconfigure unattended-upgrades" \
                    "MEDIUM" "echo 'APT::Periodic::Update-Package-Lists \"1\";' > /etc/apt/apt.conf.d/20auto-upgrades && echo 'APT::Periodic::Unattended-Upgrade \"1\";' >> /etc/apt/apt.conf.d/20auto-upgrades"
            fi
        else
            record_result "updates_001" "WARN" "Unattended upgrades not configured" \
                "Configure: dpkg-reconfigure unattended-upgrades" \
                "MEDIUM" "echo 'APT::Periodic::Update-Package-Lists \"1\";' > /etc/apt/apt.conf.d/20auto-upgrades && echo 'APT::Periodic::Unattended-Upgrade \"1\";' >> /etc/apt/apt.conf.d/20auto-upgrades"
        fi
    else
        record_result "updates_001" "WARN" "Unattended upgrades not installed" \
            "Install: apt install unattended-upgrades" \
            "MEDIUM" "apt-get update && apt-get install -y unattended-upgrades"
    fi
}

check_docker_security() {
    # Docker socket permissions
    local docker_sock="/var/run/docker.sock"
    if [[ -e "$docker_sock" ]]; then
        local perms=$(stat -c "%a" "$docker_sock" 2>/dev/null || echo "unknown")
        
        if [[ "$perms" == "660" ]] || [[ "$perms" == "600" ]]; then
            record_result "docker_001" "PASS" "Docker socket permissions secure ($perms)"
        else
            record_result "docker_001" "WARN" "Docker socket permissions: $perms" \
                "Set to 660: chmod 660 /var/run/docker.sock" \
                "MEDIUM" "chmod 660 /var/run/docker.sock"
        fi
    fi
    
    # Check for privileged containers
    local privileged_count=0
    if command -v docker >/dev/null 2>&1; then
        privileged_count=$(docker ps --quiet | xargs docker inspect --format '{{.HostConfig.Privileged}}' 2>/dev/null | grep -c true)
    fi
    
    if [[ $privileged_count -eq 0 ]]; then
        record_result "docker_002" "PASS" "No privileged containers"
    else
        record_result "docker_002" "WARN" "$privileged_count privileged container(s)" \
            "Avoid --privileged flag unless absolutely necessary"
    fi
}

check_docker_log_rotation() {
    if [[ ! -f /etc/docker/daemon.json ]]; then
        record_result "docker_003" "WARN" "Docker log rotation not configured" \
            "Create /etc/docker/daemon.json with log rotation settings" \
            "MEDIUM" "echo '{\"log-driver\": \"json-file\", \"log-opts\": {\"max-size\": \"10m\", \"max-file\": \"3\"}}' > /etc/docker/daemon.json && systemctl restart docker"
    else
        if grep -q "max-size" /etc/docker/daemon.json 2>/dev/null; then
            record_result "docker_003" "PASS" "Docker log rotation configured"
        else
            record_result "docker_003" "WARN" "Docker daemon.json exists but no log rotation" \
                "Add log rotation to /etc/docker/daemon.json" \
                "MEDIUM" "cp /etc/docker/daemon.json /etc/docker/daemon.json.backup && echo '{\"log-driver\": \"json-file\", \"log-opts\": {\"max-size\": \"10m\", \"max-file\": \"3\"}}' > /etc/docker/daemon.json && systemctl restart docker"
        fi
    fi
}

check_env_file_permissions() {
    if [[ -f "$ENV_FILE" ]]; then
        local env_perms=$(stat -c "%a" "$ENV_FILE" 2>/dev/null || echo "unknown")
        
        if [[ "$env_perms" == "600" ]]; then
            record_result "env_001" "PASS" "Environment file permissions secure (600)"
        else
            record_result "env_001" "FAIL" "Environment file permissions: $env_perms" \
                "Set to 600: chmod 600 $ENV_FILE" \
                "HIGH" "chmod 600 '$ENV_FILE'"
        fi
        
        # Check for hardcoded passwords
        if grep -q "PASSWORD=.*['\"]" "$ENV_FILE" 2>/dev/null; then
            record_result "env_002" "WARN" "Possible hardcoded password in $ENV_FILE" \
                "Use environment variables or Docker secrets"
        fi
    fi
}

check_ssl_certificates() {
    # Simple SSL check for local services
    local services=("nginx" "traefik" "caddy")
    local ssl_service_found=false
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            ssl_service_found=true
            break
        fi
    done
    
    if [[ "$ssl_service_found" == true ]]; then
        record_result "ssl_001" "INFO" "SSL/TLS service detected"
    else
        record_result "ssl_001" "WARN" "No SSL/TLS service detected" \
            "Configure SSL for production"
    fi
}

check_system_updates() {
    if command -v apt-get >/dev/null 2>&1; then
        # Check for security updates
        apt-get update >/dev/null 2>&1
        local security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
        
        if [[ $security_updates -eq 0 ]]; then
            record_result "updates_002" "PASS" "No pending security updates"
        else
            record_result "updates_002" "WARN" "$security_updates pending security updates" \
                "Run: apt update && apt upgrade -y" \
                "MEDIUM" "apt-get update && apt-get upgrade -y"
        fi
    fi
}

check_system_health() {
    # Disk space
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    
    if [[ $disk_usage -lt 80 ]]; then
        record_result "health_001" "PASS" "Disk usage OK ($disk_usage%)"
    elif [[ $disk_usage -lt 90 ]]; then
        record_result "health_001" "WARN" "Disk usage high ($disk_usage%)" \
            "Clean up disk space"
    else
        record_result "health_001" "FAIL" "Disk usage critical ($disk_usage%)" \
            "Immediate cleanup required"
    fi
    
    # Memory
    local mem_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
    
    if [[ $mem_usage -lt 80 ]]; then
        record_result "health_002" "PASS" "Memory usage OK ($mem_usage%)"
    elif [[ $mem_usage -lt 90 ]]; then
        record_result "health_002" "WARN" "Memory usage high ($mem_usage%)"
    else
        record_result "health_002" "FAIL" "Memory usage critical ($mem_usage%)"
    fi
}

# =============================================================================
# AUTO-FIX FUNCTIONS
# =============================================================================

apply_fixes() {
    local fix_count=0
    
    log "INFO" "Applying automatic fixes..."
    
    for check_id in "${!AUDIT_RESULTS[@]}"; do
        if [[ "$check_id" =~ _status$ ]]; then
            local id="${check_id%_status}"
            local status="${AUDIT_RESULTS[${id}_status]}"
            local auto_fix_cmd="${AUDIT_RESULTS[${id}_auto_fix]}"
            
            if [[ "$status" == "FAIL" || "$status" == "WARN" ]] && [[ -n "$auto_fix_cmd" ]]; then
                log "FIX" "Applying fix for: ${AUDIT_RESULTS[${id}_message]}"
                
                # Execute the fix command
                if eval "$auto_fix_cmd" 2>/dev/null; then
                    log "SUCCESS" "  ✓ Fix applied successfully"
                    FIXES_APPLIED+=("$id")
                    ((fix_count++))
                else
                    log "ERROR" "  ✗ Failed to apply fix"
                fi
            fi
        fi
    done
    
    log "INFO" "Applied $fix_count automatic fixes"
    
    if [[ $fix_count -gt 0 ]]; then
        log "INFO" "Re-running audit to verify fixes..."
        # Reset counters and re-run checks
        FAILED_CHECKS=()
        WARNING_CHECKS=()
        PASSED_CHECKS=()
        
        run_security_checks
    fi
}

run_security_checks() {
    log "INFO" "Running security checks..."
    
    # Server Hardening
    check_ssh_hardening
    check_firewall
    check_fail2ban
    check_unattended_upgrades
    check_system_updates
    check_system_health
    
    # Docker Security
    check_docker_security
    check_docker_log_rotation
    
    # Application Security
    check_env_file_permissions
    check_ssl_certificates
}

# =============================================================================
# REPORTING
# =============================================================================

generate_summary() {
    local total_checks=$((${#PASSED_CHECKS[@]} + ${#FAILED_CHECKS[@]} + ${#WARNING_CHECKS[@]}))
    
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                   SECURITY AUDIT SUMMARY                       ${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "  ${GREEN}✅ PASSED:${NC}   ${#PASSED_CHECKS[@]}"
    echo -e "  ${YELLOW}⚠️  WARNINGS:${NC} ${#WARNING_CHECKS[@]}"
    echo -e "  ${RED}❌ FAILED:${NC}   ${#FAILED_CHECKS[@]}"
    echo -e "  ${BLUE}📊 TOTAL:${NC}    $total_checks"
    
    if [[ ${#FIXES_APPLIED[@]} -gt 0 ]]; then
        echo -e "  ${CYAN}🔧 FIXES APPLIED:${NC} ${#FIXES_APPLIED[@]}"
    fi
    
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    
    # Show critical issues
    if [[ ${#FAILED_CHECKS[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}${BOLD}CRITICAL ISSUES FOUND:${NC}"
        for check_id in "${FAILED_CHECKS[@]}"; do
            echo -e "  ❌ ${AUDIT_RESULTS[${check_id}_message]}"
            [[ -n "${AUDIT_RESULTS[${check_id}_remediation]}" ]] && \
                echo -e "     💡 ${AUDIT_RESULTS[${check_id}_remediation]}"
        done
    fi
    
    # Show warnings
    if [[ ${#WARNING_CHECKS[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}${BOLD}WARNINGS:${NC}"
        for check_id in "${WARNING_CHECKS[@]}"; do
            echo -e "  ⚠️  ${AUDIT_RESULTS[${check_id}_message]}"
        done
    fi
    
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

show_help() {
    cat << EOF
Security Audit Script v$SCRIPT_VERSION with Auto-Fix

Usage: $SCRIPT_NAME [OPTIONS]

Options:
  --fix                  Apply automatic fixes for common issues
  --json                 Generate JSON report
  --csv                  Generate CSV report
  --verbose              Verbose output
  --quiet                Minimal output
  --help                 Show this help

Environment Variables:
  PROJECT_DIR            Project directory (default: current)
  ENV_FILE               Path to .env file (default: .env in project dir)
  OUTPUT_DIR             Output directory for reports (default: ./reports)

What it checks:
  ✅ Server Hardening    SSH, firewall, fail2ban, updates
  ✅ Docker Security     Socket permissions, log rotation
  ✅ Application Security Environment files, SSL
  ✅ System Health       Disk space, memory usage

Auto-fix capabilities (with --fix):
  🔧 Install fail2ban
  🔧 Enable UFW firewall
  🔧 Fix .env file permissions
  🔧 Install unattended-upgrades
  🔧 Configure Docker log rotation
  🔧 Fix SSH hardening

Exit Codes:
  0 - All checks passed
  1 - Warnings found (review recommended)
  2 - Critical failures (fix required)

Examples:
  $SCRIPT_NAME              # Run audit only
  $SCRIPT_NAME --fix        # Run audit and auto-fix issues
  $SCRIPT_NAME --json       # Generate JSON report
EOF
}

main() {
    # Parse arguments
    local AUTO_FIX=false
    local GENERATE_JSON=false
    local GENERATE_CSV=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fix)
                AUTO_FIX=true
                shift
                ;;
            --json)
                GENERATE_JSON=true
                shift
                ;;
            --csv)
                GENERATE_CSV=true
                shift
                ;;
            --verbose)
                LOG_LEVEL="DEBUG"
                shift
                ;;
            --quiet)
                LOG_LEVEL="ERROR"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Banner
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              SECURITY AUDIT SCRIPT v$SCRIPT_VERSION                     ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${BLUE}Date:${NC}   $(date)"
    echo -e "${BLUE}Host:${NC}   $(hostname)"
    echo ""
    
    # Run security checks
    run_security_checks
    
    # Apply fixes if requested
    if [[ "$AUTO_FIX" == "true" ]]; then
        apply_fixes
    fi
    
    # Generate summary
    generate_summary
    
    # Generate reports if requested
    if [[ "$GENERATE_JSON" == "true" ]]; then
        log "INFO" "JSON report generation not implemented in this version"
    fi
    
    if [[ "$GENERATE_CSV" == "true" ]]; then
        log "INFO" "CSV report generation not implemented in this version"
    fi
    
    # Exit with appropriate code
    if [[ ${#FAILED_CHECKS[@]} -gt 0 ]]; then
        log "ERROR" "❌ CRITICAL: ${#FAILED_CHECKS[@]} issues need immediate attention"
        exit 2
    elif [[ ${#WARNING_CHECKS[@]} -gt 0 ]]; then
        log "WARN" "⚠️  WARNING: ${#WARNING_CHECKS[@]} issues to review"
        exit 1
    else
        log "SUCCESS" "✅ SUCCESS: All security checks passed!"
        exit 0
    fi
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi