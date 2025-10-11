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

msg_info "Adding Kamiwaza APT Repository"
echo "deb [signed-by=/usr/share/keyrings/kamiwaza-archive-keyring.gpg] https://packages.kamiwaza.ai/ubuntu/ noble main" | tee /etc/apt/sources.list.d/kamiwaza.list
curl -fsSL https://packages.kamiwaza.ai/gpg | gpg --dearmor -o /usr/share/keyrings/kamiwaza-archive-keyring.gpg
$STD apt-get update -y
$STD apt-get upgrade -y
msg_ok "Added Kamiwaza APT Repository"

msg_info "Installing Kamiwaza"
# export DEBIAN_FRONTEND=noninteractive
# export KAMIWAZA_INSTALL_MODE=unattended
$STD apt-get install -y kamiwaza
msg_ok "Installed Kamiwaza package"

msg_info "Starting Kamiwaza service"
$STD kamiwaza start
msg_ok "Kamiwaza service started"

msg_info "Waiting for Kamiwaza to start"
$STD kamiwaza start -w
msg_ok "KamiWaza is ready"

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
