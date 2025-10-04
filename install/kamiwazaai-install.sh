#!/usr/bin/env bash
# Copyright (c) 2021-2025 community-scripts ORG
# Author: shkevin
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/kamiwaza-ai/kamiwaza-community-edition
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
    curl \
    gnupg \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    software-properties-common \
    net-tools \
    jq \
    bc
msg_ok "Installed Dependencies"

msg_info "Installing Python 3.12"
$STD add-apt-repository ppa:deadsnakes/ppa -y
$STD apt-get update
$STD apt-get install -y \
    python3.12 \
    python3.12-dev \
    python3.12-venv \
    python-is-python3
msg_ok "Installed Python 3.12"

msg_info "Installing Node.js 22"
NODE_VERSION="22" NODE_MODULE="webpack@latest,webpack-cli@latest,pm2@latest" setup_nodejs
chmod a+rx /usr/bin/node /usr/bin/npm /usr/bin/npx
msg_ok "Installed Node.js 22"

msg_info "Installing Docker"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg &>/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
$STD apt-get update
$STD apt-get install -y docker-ce docker-ce-cli containerd.io
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/v2.39.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
msg_ok "Installed Docker Engine + Compose v2"

msg_info "Adding Kamiwaza APT Repository"
curl -fsSL https://packages.kamiwaza.ai/gpg | gpg --dearmor -o /usr/share/keyrings/kamiwaza-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kamiwaza-archive-keyring.gpg] https://packages.kamiwaza.ai/ubuntu/ noble main" | tee /etc/apt/sources.list.d/kamiwaza.list
$STD apt-get update
msg_ok "Added Kamiwaza APT Repository"

msg_info "Installing Kamiwaza"
$STD apt-get install -y kamiwaza
msg_ok "Installed Kamiwaza package"

# msg_info "Checking GPU Support"
# if command -v nvidia-smi &> /dev/null; then
#   GPU_INFO=$(nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader,nounits 2>/dev/null | head -1)
#   if [[ -n "$GPU_INFO" ]]; then
#     msg_info "NVIDIA GPU detected: $GPU_INFO"
#     COMPUTE_CAP=$(echo "$GPU_INFO" | cut -d',' -f2 | tr -d ' ')
#     if (( $(echo "$COMPUTE_CAP >= 7.0" | bc -l 2>/dev/null || echo "0") )); then
#       msg_ok "GPU meets KamiWaza requirements (Compute Capability 7.0+)"
#     else
#       msg_info "GPU Compute Capability $COMPUTE_CAP may not meet requirements (7.0+ recommended)"
#     fi
#   fi
# else
#   msg_info "No NVIDIA GPU detected - CPU-only mode"
# fi

# msg_info "Starting Kamiwaza service"
# systemctl daemon-reload
# systemctl enable kamiwaza
# systemctl start kamiwaza
# msg_ok "Kamiwaza service started"

# msg_info "Saving access information"
# TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
# UBUNTU_VERSION=$(lsb_release -rs)
# CONTAINER_IP=$(hostname -I | awk '{print $1}')

# {
#   echo "KamiWaza CE Access Information"
#   echo "============================================"
#   echo ""
#   echo "Web Console: https://$CONTAINER_IP"
#   echo ""
#   echo "Default Credentials:"
#   echo "  Username: admin"
#   echo "  Password: kamiwaza"
#   echo ""
#   echo "System Information:"
#   echo "  - OS: Ubuntu $UBUNTU_VERSION LTS"
#   echo "  - Memory: ${TOTAL_MEM}MB"
#   echo "  - Python: 3.12"
#   echo "  - Docker: Engine with Compose v2"
#   echo "  - Node.js: 22"
#   echo ""
#   echo "Service Management:"
#   echo "  - Status:  systemctl status kamiwaza"
#   echo "  - Logs:    journalctl -u kamiwaza -f"
#   echo "  - Restart: systemctl restart kamiwaza"
#   echo ""
#   echo "Documentation: https://docs.kamiwaza.ai/"
# } > /root/kamiwaza-access-info.txt

# msg_ok "Access information saved"

# msg_info "Cleaning up"
# $STD apt-get -y autoremove
# $STD apt-get -y autoclean
# msg_ok "Cleaned up"

# echo ""
# msg_ok "KamiWaza installation completed!"
# msg_info "Access: https://$CONTAINER_IP"
# msg_info "Login: admin / kamiwaza"
# msg_warn "Initial startup may take 10-30 minutes"

motd_ssh
customize
