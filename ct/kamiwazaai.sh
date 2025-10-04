#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/shkevin/ProxmoxVE/refs/heads/kamiwaza-ai-feature/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: shkevin
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/kamiwaza-ai/kamiwaza-community-edition

APP="KamiWazaAI"
var_tags="${var_tags:-ai;machine-learning;gpu-acceleration}"
var_cpu="${var_cpu:-8}"
var_ram="${var_ram:-16384}"
var_disk="${var_disk:-50}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.04}"
var_unprivileged="${var_unprivileged:-0}"

header_info "$APP"
base_settings
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

  msg_info "Checking for ${APP} updates"
  CURRENT_VERSION=$(dpkg -l | grep kamiwaza | awk '{print $3}' | head -1)
  $STD apt-get update

  AVAILABLE_VERSION=$(apt-cache policy kamiwaza | grep Candidate | awk '{print $2}')
  if [[ "${AVAILABLE_VERSION}" != "${CURRENT_VERSION}" ]]; then
    msg_info "Updating ${APP} from v${CURRENT_VERSION} to v${AVAILABLE_VERSION}"

    msg_info "Stopping KamiWaza Service"
    $STD systemctl stop kamiwaza
    msg_ok "Service Stopped"

    msg_info "Upgrading ${APP} package"
    $STD apt-get upgrade -y kamiwaza
    msg_ok "Package upgraded to v${AVAILABLE_VERSION}"

    msg_info "Reloading systemd daemon"
    $STD systemctl daemon-reload
    msg_ok "Daemon reloaded"

    msg_info "Starting KamiWaza Service"
    $STD systemctl start kamiwaza
    msg_ok "Service Started"

    msg_ok "Updated ${APP} to v${AVAILABLE_VERSION}"
  else
    msg_ok "No update required. ${APP} is already at v${CURRENT_VERSION}."
  fi
  exit
}

start
build_container
description
msg_ok "Completed Successfully!\n"
