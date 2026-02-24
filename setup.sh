#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error()   { echo -e "${RED}✗ $1${NC}"; }

ask_yes_no() {
    local prompt="$1"
    local answer
    while true; do
        read -r -p "$prompt [Y/n]: " answer < /dev/tty
        case "${answer,,}" in
            ""|y|yes) return 0 ;;
            n|no)     return 1 ;;
            *)        printf "%b\n" "Please answer Y or N." ;;
        esac
    done
}

check_command() {
    command -v "$1" &>/dev/null
}

check_uv() {
    command -v uv &>/dev/null \
        || [ -x "$HOME/.local/bin/uv" ] \
        || [ -x "$HOME/.cargo/bin/uv" ]
}

uv_version() {
    if command -v uv &>/dev/null; then
        uv --version 2>/dev/null | cut -d' ' -f2
    elif [ -x "$HOME/.local/bin/uv" ]; then
        "$HOME/.local/bin/uv" --version 2>/dev/null | cut -d' ' -f2
    elif [ -x "$HOME/.cargo/bin/uv" ]; then
        "$HOME/.cargo/bin/uv" --version 2>/dev/null | cut -d' ' -f2
    fi
}

is_service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

is_git_configured() {
    check_command git || return 1
    [[ -n "$(git config --global user.name 2>/dev/null)" && \
       -n "$(git config --global user.email 2>/dev/null)" ]]
}

is_ufw_active() {
    check_command ufw && is_service_active ufw
}

# -----------------------------------------------------------------------------
# System Analysis
# -----------------------------------------------------------------------------

analyze_system() {
    print_header "System Analysis"
    echo -e "Scanning installed components...\n"

    if is_git_configured; then
        echo -e "  ${GREEN}✓${NC} Git: configured ($(git config --global user.name) <$(git config --global user.email)>)"
    elif check_command git; then
        echo -e "  ${YELLOW}~${NC} Git: installed but not configured"
    else
        echo -e "  ${RED}✗${NC} Git: not installed"
    fi

    if check_command docker; then
        echo -e "  ${GREEN}✓${NC} Docker: $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
    else
        echo -e "  ${RED}✗${NC} Docker: not installed"
    fi

    if check_command python3; then
        echo -e "  ${GREEN}✓${NC} Python: $(python3 --version 2>/dev/null | cut -d' ' -f2)"
    else
        echo -e "  ${RED}✗${NC} Python3: not installed"
    fi

    if check_uv; then
        echo -e "  ${GREEN}✓${NC} uv: $(uv_version)"
    else
        echo -e "  ${RED}✗${NC} uv: not installed"
    fi

    if check_command nginx && is_service_active nginx; then
        echo -e "  ${GREEN}✓${NC} Nginx: running"
    elif check_command nginx; then
        echo -e "  ${YELLOW}~${NC} Nginx: installed but not running"
    else
        echo -e "  ${RED}✗${NC} Nginx: not installed"
    fi

    if check_command certbot; then
        echo -e "  ${GREEN}✓${NC} Certbot: installed"
    else
        echo -e "  ${RED}✗${NC} Certbot: not installed"
    fi

    if is_ufw_active; then
        echo -e "  ${GREEN}✓${NC} Firewall (UFW): active"
    elif check_command ufw; then
        echo -e "  ${YELLOW}~${NC} Firewall (UFW): installed but not active"
    else
        echo -e "  ${RED}✗${NC} Firewall (UFW): not installed"
    fi

    if check_command fail2ban-client && is_service_active fail2ban; then
        echo -e "  ${GREEN}✓${NC} Fail2ban: running"
    elif check_command fail2ban-client; then
        echo -e "  ${YELLOW}~${NC} Fail2ban: installed but not running"
    else
        echo -e "  ${RED}✗${NC} Fail2ban: not installed"
    fi

    if [ -f ~/.ssh/id_ed25519 ]; then
        echo -e "  ${GREEN}✓${NC} SSH key: exists (~/.ssh/id_ed25519)"
    else
        echo -e "  ${RED}✗${NC} SSH key: not found"
    fi

    echo ""
}

# -----------------------------------------------------------------------------
# System Update
# -----------------------------------------------------------------------------

update_system() {
    print_header "System Update"
    if ask_yes_no "Do you want to update system packages?"; then
        sudo apt update && sudo apt upgrade -y
        print_success "System updated"
    else
        print_warning "Skipped system update"
    fi
}

# -----------------------------------------------------------------------------
# Essential Tools
# -----------------------------------------------------------------------------

install_essentials() {
    check_command curl && check_command vim && check_command htop \
        && check_command wget && check_command unzip && return

    print_header "Essential Tools"
    if ask_yes_no "Do you want to install essential tools (curl, wget, vim, htop, unzip, etc.)?"; then
        sudo apt install -y \
            curl wget vim htop unzip zip tree net-tools \
            software-properties-common apt-transport-https \
            ca-certificates gnupg lsb-release build-essential
        print_success "Essential tools installed"
    else
        print_warning "Skipped essential tools"
    fi
}

# -----------------------------------------------------------------------------
# Git
# -----------------------------------------------------------------------------

install_git() {
    is_git_configured && return

    print_header "Git"

    if ! check_command git; then
        if ask_yes_no "Do you want to install Git?"; then
            sudo apt install -y git
            print_success "Git installed"
        else
            print_warning "Skipped Git"
            return
        fi
    fi

    if ask_yes_no "Do you want to configure Git (name and email)?"; then
        read -r -p "Enter your Git username: " git_username < /dev/tty
        read -r -p "Enter your Git email: "    git_email    < /dev/tty
        git config --global user.name "$git_username"
        git config --global user.email "$git_email"
        git config --global init.defaultBranch main
        print_success "Git configured"
    fi
}

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------

install_docker() {
    check_command docker && return

    print_header "Docker"
    if ! ask_yes_no "Do you want to install Docker?"; then
        print_warning "Skipped Docker"
        return
    fi

    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    ARCH="$(dpkg --print-architecture)"
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"

    print_success "Docker installed"
    print_warning "Log out and back in for docker group changes to take effect"
}

# -----------------------------------------------------------------------------
# Python with uv
# -----------------------------------------------------------------------------

install_python_uv() {
    check_command python3 && check_uv && return

    print_header "Python & uv Package Manager"

    if ! check_command python3; then
        if ask_yes_no "Do you want to install Python3?"; then
            sudo apt install -y python3 python3-dev python3-venv
            print_success "Python3 installed"
        fi
    fi

    if ! check_uv; then
        if ask_yes_no "Do you want to install uv (fast Python package manager)?"; then
            curl -LsSf https://astral.sh/uv/install.sh | sh
            print_success "uv installed"
            print_warning "Run 'source ~/.bashrc' or restart shell to use uv"
        else
            print_warning "Skipped uv"
        fi
    fi
}

# -----------------------------------------------------------------------------
# Nginx
# -----------------------------------------------------------------------------

install_nginx() {
    check_command nginx && return

    print_header "Nginx"
    if ask_yes_no "Do you want to install Nginx?"; then
        sudo apt install -y nginx
        sudo systemctl enable nginx
        sudo systemctl start nginx
        print_success "Nginx installed and started"
    else
        print_warning "Skipped Nginx"
    fi
}

# -----------------------------------------------------------------------------
# Certbot (Let's Encrypt SSL)
# -----------------------------------------------------------------------------

install_certbot() {
    check_command certbot && return

    print_header "Certbot (Let's Encrypt SSL)"
    if ask_yes_no "Do you want to install Certbot for SSL certificates?"; then
        sudo apt install -y certbot python3-certbot-nginx
        print_success "Certbot installed"
        echo -e "${YELLOW}To get a certificate run: sudo certbot --nginx -d yourdomain.com${NC}"
    else
        print_warning "Skipped Certbot"
    fi
}

# -----------------------------------------------------------------------------
# Firewall (UFW)
# -----------------------------------------------------------------------------

setup_firewall() {
    is_ufw_active && return

    print_header "Firewall (UFW)"
    if ! ask_yes_no "Do you want to configure UFW firewall?"; then
        print_warning "Skipped firewall configuration"
        return
    fi

    sudo apt install -y ufw
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https

    if ask_yes_no "Do you want to enable the firewall now?"; then
        sudo ufw --force enable
        print_success "Firewall enabled"
    else
        print_warning "Firewall configured but not enabled. Run 'sudo ufw enable' to activate."
    fi

    sudo ufw status
}

# -----------------------------------------------------------------------------
# Fail2ban
# -----------------------------------------------------------------------------

install_fail2ban() {
    check_command fail2ban-client && is_service_active fail2ban && return

    print_header "Fail2ban (Security)"
    if ask_yes_no "Do you want to install Fail2ban for SSH protection?"; then
        sudo apt install -y fail2ban
        sudo systemctl enable fail2ban
        sudo systemctl start fail2ban
        print_success "Fail2ban installed and started"
    else
        print_warning "Skipped Fail2ban"
    fi
}

# -----------------------------------------------------------------------------
# Docker Compose Database Templates
# -----------------------------------------------------------------------------

create_docker_compose_templates() {
    if [ -d ~/docker/databases ] && [ "$(ls -A ~/docker/databases 2>/dev/null)" ]; then
        return
    fi

    print_header "Docker Compose Database Templates"
    if ! ask_yes_no "Do you want to create Docker Compose templates for databases?"; then
        print_warning "Skipped Docker Compose templates"
        return
    fi

    mkdir -p ~/docker/databases

    if ask_yes_no "Create PostgreSQL docker-compose template?"; then
        cat > ~/docker/databases/postgres-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
      POSTGRES_DB: ${POSTGRES_DB:-app}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

volumes:
  postgres_data:
EOF
        print_success "PostgreSQL template created at ~/docker/databases/postgres-compose.yml"
    fi

    if ask_yes_no "Create MySQL docker-compose template?"; then
        cat > ~/docker/databases/mysql-compose.yml << 'EOF'
services:
  mysql:
    image: mysql:8
    container_name: mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-changeme}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-app}
      MYSQL_USER: ${MYSQL_USER:-user}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-changeme}
    volumes:
      - mysql_data:/var/lib/mysql
    ports:
      - "3306:3306"

volumes:
  mysql_data:
EOF
        print_success "MySQL template created at ~/docker/databases/mysql-compose.yml"
    fi

    if ask_yes_no "Create Redis docker-compose template?"; then
        cat > ~/docker/databases/redis-compose.yml << 'EOF'
services:
  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"

volumes:
  redis_data:
EOF
        print_success "Redis template created at ~/docker/databases/redis-compose.yml"
    fi

    if ask_yes_no "Create full stack docker-compose (PostgreSQL + Redis)?"; then
        cat > ~/docker/databases/fullstack-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
      POSTGRES_DB: ${POSTGRES_DB:-app}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"

volumes:
  postgres_data:
  redis_data:
EOF
        print_success "Full stack template created at ~/docker/databases/fullstack-compose.yml"
    fi

    echo -e "\n${YELLOW}To start a database: cd ~/docker/databases && docker compose -f <filename>.yml up -d${NC}"
}

# -----------------------------------------------------------------------------
# SSH Key
# -----------------------------------------------------------------------------

setup_ssh_key() {
    [ -f ~/.ssh/id_ed25519 ] && return

    print_header "SSH Key"
    if ! ask_yes_no "Do you want to generate an SSH key?"; then
        print_warning "Skipped SSH key generation"
        return
    fi

    read -r -p "Enter your email for SSH key: " ssh_email < /dev/tty
    ssh-keygen -t ed25519 -C "$ssh_email" -f ~/.ssh/id_ed25519

    print_success "SSH key generated"
    echo -e "\n${YELLOW}Your public key:${NC}"
    cat ~/.ssh/id_ed25519.pub
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

print_summary() {
    print_header "Installation Summary"
    echo "Installed components:"
    check_command git          && echo -e "  ${GREEN}✓${NC} Git $(git --version 2>/dev/null | cut -d' ' -f3)"
    check_command docker       && echo -e "  ${GREEN}✓${NC} Docker $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
    check_command python3      && echo -e "  ${GREEN}✓${NC} Python $(python3 --version 2>/dev/null | cut -d' ' -f2)"
    check_uv                   && echo -e "  ${GREEN}✓${NC} uv $(uv_version)"
    check_command nginx        && echo -e "  ${GREEN}✓${NC} Nginx"
    check_command certbot      && echo -e "  ${GREEN}✓${NC} Certbot"
    check_command fail2ban-client && echo -e "  ${GREEN}✓${NC} Fail2ban"
    [ -f ~/.ssh/id_ed25519 ]   && echo -e "  ${GREEN}✓${NC} SSH key"
    echo ""
    print_warning "Remember to:"
    echo "  - Log out and back in for docker group changes"
    echo "  - Run 'source ~/.bashrc' to use uv"
    echo "  - Configure your firewall rules as needed"
    echo ""
    print_success "Setup complete!"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    print_header "Server Setup Script"
    echo "This script will help you set up a fresh Ubuntu/Debian server."
    echo ""

    analyze_system

    if ! ask_yes_no "Do you want to continue with setup?"; then
        echo "Setup cancelled"
        exit 0
    fi

    update_system
    install_essentials
    install_git
    install_docker
    install_python_uv
    install_nginx
    install_certbot
    setup_firewall
    install_fail2ban
    create_docker_compose_templates
    setup_ssh_key
    print_summary
}

main "$@"
