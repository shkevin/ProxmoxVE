#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/shkevin/ProxmoxVE/refs/heads/kamiwaza-ai-feature/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Kevin Cox
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/kamiwaza-ai/kamiwaza-community-edition

APP="KamiWazaAI"
var_tags="${var_tags:-ai;machine-learning;docker;gpu}"
var_cpu="${var_cpu:-8}"
var_ram="${var_ram:-16384}"
var_disk="${var_disk:-25}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.04}"
var_unprivileged="${var_unprivileged:-0}"

# App Output & Base Settings
header_info "$APP"
base_settings

# Core
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if ! dpkg -l | grep -q kamiwaza; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # Check for updates via APT
  CURRENT_VERSION=$(dpkg -l | grep kamiwaza | awk '{print $3}' | head -1)

  msg_info "Updating ${APP} and system packages"

  msg_info "Stopping KamiWaza Service"
  $STD systemctl stop kamiwaza
  msg_ok "Service Stopped"

  msg_info "Updating package database"
  $STD apt-get update
  msg_ok "Package database updated"

  msg_info "Upgrading KamiWaza"
  if apt-get upgrade -s kamiwaza | grep -q "kamiwaza"; then
    $STD apt-get upgrade -y kamiwaza
    NEW_VERSION=$(dpkg -l | grep kamiwaza | awk '{print $3}' | head -1)
    echo "${NEW_VERSION}" > /opt/KamiWazaAI_version.txt
    msg_ok "Updated ${APP} from v${CURRENT_VERSION} to v${NEW_VERSION}"
  else
    msg_ok "No update available. ${APP} is already at v${CURRENT_VERSION}"
  fi

  msg_info "Starting KamiWaza Service"
  $STD systemctl start kamiwaza
  msg_ok "Service Started"

  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}https://${IP}${CL}"
echo -e "${INFO}${YW} Default Credentials:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}Username: admin${CL}"
echo -e "${TAB}${GATEWAY}${BGN}Password: kamiwaza${CL}"
echo -e "${INFO}${YW} System Info:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}Memory: 16GB+ (Minimum for KamiWaza)${CL}"
echo -e "${TAB}${GATEWAY}${BGN}Storage: 25GB (10GB+ required)${CL}"
echo -e "${TAB}${GATEWAY}${BGN}Service: systemctl {start|stop|restart|status} kamiwaza${CL}"
