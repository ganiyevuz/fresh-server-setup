#!/bin/bash

# =============================================================================
# Server Setup Script for Ubuntu/Debian
# Interactive installation of development tools
#
# Usage:
#   ./setup.sh              # Interactive mode (asks for each component)
#   ./setup.sh --all        # Install everything without prompts
#   ./setup.sh --docker --nginx --uv   # Install specific components only
#
# Available flags:
#   --all         Install all components
#   --update      System update
#   --essentials  Essential tools (curl, wget, vim, etc.)
#   --git         Git
#   --docker      Docker
#   --python      Python3 & uv
#   --uv          Alias for --python
#   --nginx       Nginx
#   --certbot     Certbot SSL
#   --firewall    UFW firewall
#   --fail2ban    Fail2ban
#   --databases   Docker Compose database templates
#   --ssh         SSH key generation
#   --swap        Create swap file
#   --timezone    Set timezone
#   --help        Show this help
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags for CLI mode
INSTALL_ALL=false
INSTALL_UPDATE=false
INSTALL_ESSENTIALS=false
INSTALL_GIT=false
INSTALL_DOCKER=false
INSTALL_PYTHON=false
INSTALL_NGINX=false
INSTALL_CERTBOT=false
INSTALL_FIREWALL=false
INSTALL_FAIL2BAN=false
INSTALL_DATABASES=false
INSTALL_SSH=false
INSTALL_SWAP=false
INSTALL_TIMEZONE=false
CLI_MODE=false

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

ask_yes_no() {
    while true; do
        read -p "$1 [y/n]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
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
    print_header "Essential Tools"
    if ask_yes_no "Do you want to install essential tools (curl, wget, vim, htop, unzip, etc.)?"; then
        sudo apt install -y \
            curl \
            wget \
            vim \
            htop \
            unzip \
            zip \
            tree \
            net-tools \
            software-properties-common \
            apt-transport-https \
            ca-certificates \
            gnupg \
            lsb-release \
            build-essential
        print_success "Essential tools installed"
    else
        print_warning "Skipped essential tools"
    fi
}

# -----------------------------------------------------------------------------
# Git
# -----------------------------------------------------------------------------

install_git() {
    print_header "Git"
    if check_command git; then
        print_warning "Git is already installed ($(git --version))"
        if ! ask_yes_no "Do you want to configure Git?"; then
            return
        fi
    else
        if ask_yes_no "Do you want to install Git?"; then
            sudo apt install -y git
            print_success "Git installed"
        else
            print_warning "Skipped Git installation"
            return
        fi
    fi

    # Configure Git
    if ask_yes_no "Do you want to configure Git (name and email)?"; then
        read -p "Enter your Git username: " git_username
        read -p "Enter your Git email: " git_email
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
    print_header "Docker"
    if check_command docker; then
        print_warning "Docker is already installed ($(docker --version))"
        if ! ask_yes_no "Do you want to reinstall Docker?"; then
            return
        fi
    else
        if ! ask_yes_no "Do you want to install Docker?"; then
            print_warning "Skipped Docker installation"
            return
        fi
    fi

    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add current user to docker group
    sudo usermod -aG docker $USER

    print_success "Docker installed"
    print_warning "Log out and back in for docker group changes to take effect"
}

# -----------------------------------------------------------------------------
# Python with uv
# -----------------------------------------------------------------------------

install_python_uv() {
    print_header "Python & uv Package Manager"

    # Install Python
    if check_command python3; then
        print_warning "Python3 is already installed ($(python3 --version))"
    else
        if ask_yes_no "Do you want to install Python3?"; then
            sudo apt install -y python3 python3-dev python3-venv
            print_success "Python3 installed"
        fi
    fi

    # Install uv
    if check_command uv; then
        print_warning "uv is already installed ($(uv --version))"
        if ! ask_yes_no "Do you want to reinstall uv?"; then
            return
        fi
    else
        if ! ask_yes_no "Do you want to install uv (fast Python package manager)?"; then
            print_warning "Skipped uv installation"
            return
        fi
    fi

    curl -LsSf https://astral.sh/uv/install.sh | sh
    print_success "uv installed"
    print_warning "Run 'source ~/.bashrc' or restart shell to use uv"
}

# -----------------------------------------------------------------------------
# Nginx
# -----------------------------------------------------------------------------

install_nginx() {
    print_header "Nginx"
    if check_command nginx; then
        print_warning "Nginx is already installed ($(nginx -v 2>&1))"
        if ! ask_yes_no "Do you want to reinstall Nginx?"; then
            return
        fi
    else
        if ! ask_yes_no "Do you want to install Nginx?"; then
            print_warning "Skipped Nginx installation"
            return
        fi
    fi

    sudo apt install -y nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
    print_success "Nginx installed and started"
}

# -----------------------------------------------------------------------------
# Certbot (Let's Encrypt SSL)
# -----------------------------------------------------------------------------

install_certbot() {
    print_header "Certbot (Let's Encrypt SSL)"
    if check_command certbot; then
        print_warning "Certbot is already installed ($(certbot --version))"
        if ! ask_yes_no "Do you want to reinstall Certbot?"; then
            return
        fi
    else
        if ! ask_yes_no "Do you want to install Certbot for SSL certificates?"; then
            print_warning "Skipped Certbot installation"
            return
        fi
    fi

    sudo apt install -y certbot python3-certbot-nginx
    print_success "Certbot installed"
    echo -e "${YELLOW}To get SSL certificate run: sudo certbot --nginx -d yourdomain.com${NC}"
}

# -----------------------------------------------------------------------------
# Firewall (UFW)
# -----------------------------------------------------------------------------

setup_firewall() {
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
# Docker Compose files for Databases
# -----------------------------------------------------------------------------

create_docker_compose_templates() {
    print_header "Docker Compose Database Templates"
    if ! ask_yes_no "Do you want to create Docker Compose templates for databases?"; then
        print_warning "Skipped Docker Compose templates"
        return
    fi

    mkdir -p ~/docker/databases

    # PostgreSQL
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

    # MySQL
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

    # Redis
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

    # Full stack (all databases)
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

    echo -e "\n${YELLOW}To start a database, run:${NC}"
    echo -e "${YELLOW}  cd ~/docker/databases${NC}"
    echo -e "${YELLOW}  docker compose -f <filename>.yml up -d${NC}"
}

# -----------------------------------------------------------------------------
# SSH Key
# -----------------------------------------------------------------------------

setup_ssh_key() {
    print_header "SSH Key"
    if [ -f ~/.ssh/id_ed25519 ]; then
        print_warning "SSH key already exists"
        if ! ask_yes_no "Do you want to generate a new SSH key?"; then
            return
        fi
    else
        if ! ask_yes_no "Do you want to generate an SSH key?"; then
            print_warning "Skipped SSH key generation"
            return
        fi
    fi

    read -p "Enter your email for SSH key: " ssh_email
    ssh-keygen -t ed25519 -C "$ssh_email"

    print_success "SSH key generated"
    echo -e "\n${YELLOW}Your public key:${NC}"
    cat ~/.ssh/id_ed25519.pub
}

# -----------------------------------------------------------------------------
# Fail2ban
# -----------------------------------------------------------------------------

install_fail2ban() {
    print_header "Fail2ban (Security)"
    if check_command fail2ban-client; then
        print_warning "Fail2ban is already installed"
        if ! ask_yes_no "Do you want to reinstall Fail2ban?"; then
            return
        fi
    else
        if ! ask_yes_no "Do you want to install Fail2ban for SSH protection?"; then
            print_warning "Skipped Fail2ban installation"
            return
        fi
    fi

    sudo apt install -y fail2ban
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    print_success "Fail2ban installed and started"
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

print_summary() {
    print_header "Installation Summary"

    echo "Installed components:"
    check_command git && echo -e "  ${GREEN}✓${NC} Git $(git --version 2>/dev/null | cut -d' ' -f3)"
    check_command docker && echo -e "  ${GREEN}✓${NC} Docker $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
    check_command python3 && echo -e "  ${GREEN}✓${NC} Python $(python3 --version 2>/dev/null | cut -d' ' -f2)"
    check_command uv && echo -e "  ${GREEN}✓${NC} uv $(uv --version 2>/dev/null | cut -d' ' -f2)"
    check_command nginx && echo -e "  ${GREEN}✓${NC} Nginx"
    check_command certbot && echo -e "  ${GREEN}✓${NC} Certbot"
    check_command fail2ban-client && echo -e "  ${GREEN}✓${NC} Fail2ban"

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
    echo "This script will help you set up a fresh Ubuntu/Debian server"
    echo "You will be asked before each component is installed"
    echo ""

    if ! ask_yes_no "Do you want to continue?"; then
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
