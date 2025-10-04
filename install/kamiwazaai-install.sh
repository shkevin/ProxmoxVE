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
$STD apt-get update
$STD apt-get install -y \
    python3.12 \
    python3.12-dev \
    python3.12-venv \
    python-is-python3
msg_ok "Installed Python 3.12"

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

msg_info "Creating kamiwaza user"
$STD useradd -m -s /bin/bash kamiwaza
msg_ok "Created kamiwaza user"

msg_info "Installing Node.js"
NODE_VERSION="22" NODE_MODULE="pm2@latest" setup_nodejs

msg_info "Adding kamiwaza user to docker group"
$STD usermod -aG docker kamiwaza
msg_ok "Added kamiwaza user to docker group"

msg_info "Installing Kamiwaza"
export DEBIAN_FRONTEND=noninteractive
export KAMIWAZA_INSTALL_MODE=unattended
$STD apt-get install -y kamiwaza
msg_ok "Installed Kamiwaza package"

msg_info "Creating kamiwaza service"
cat <<EOF >/etc/systemd/system/kamiwaza.service
[Unit]
Description=Kamiwaza AI Platform
Documentation=https://docs.kamiwaza.ai
After=network.target docker.service
Wants=docker.service
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
User=kamiwaza
Group=kamiwaza
WorkingDirectory=/opt/kamiwaza
Environment=KAMIWAZA_LOG_DIR=/opt/kamiwaza/logs
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ExecStart=kamiwaza start
ExecStop=kamiwaza stop
ExecReload=kamiwaza restart

Restart=on-failure
RestartSec=10
TimeoutStartSec=300
TimeoutStopSec=120
KillMode=mixed
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

msg_info "Starting Kamiwaza service"
systemctl daemon-reload
systemctl enable kamiwaza
systemctl start kamiwaza
msg_ok "Kamiwaza service started"

msg_info "Saving access information"
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
UBUNTU_VERSION=$(lsb_release -rs)
CONTAINER_IP=$(hostname -I | awk '{print $1}')

{
  echo "KamiWaza CE Access Information"
  echo "============================================"
  echo ""
  echo "Web Console: https://$CONTAINER_IP"
  echo ""
  echo "Default Credentials:"
  echo "  Username: admin"
  echo "  Password: kamiwaza"
  echo ""
  echo "System Information:"
  echo "  - OS: Ubuntu $UBUNTU_VERSION LTS"
  echo "  - Memory: ${TOTAL_MEM}MB"
  echo ""
  echo "Service Management:"
  echo "  - Status:  systemctl status kamiwaza"
  echo "  - Logs:    journalctl -u kamiwaza -f"
  echo "  - Restart: systemctl restart kamiwaza"
  echo "Documentation: https://docs.kamiwaza.ai/"
} > /root/kamiwaza-access-info.txt

msg_ok "Access information saved"

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned up"

msg_ok "KamiWaza installation completed!"
msg_info "Access: https://$CONTAINER_IP"
msg_info "Login: admin / kamiwaza"
msg_warn "Initial startup may take 10-30 minutes"

motd_ssh
customize
