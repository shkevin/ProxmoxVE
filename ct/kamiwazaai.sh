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
  if [[ ! -d /opt/kamiwaza ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # Check for latest version from available tarballs
  LATEST_VERSION=$(curl -fsSL https://api.github.com/repos/kamiwaza-ai/kamiwaza-community-edition/contents/ | jq -r '.[] | select(.name | test("kamiwaza-community-.*-UbuntuLinux.tar.gz")) | .name' | sed 's/kamiwaza-community-\(.*\)-UbuntuLinux.tar.gz/\1/' | sort -V | tail -1)
  if [[ -z "$LATEST_VERSION" ]]; then
    # Fallback to known version if API fails
    LATEST_VERSION="0.5.0"
  fi
  CURRENT_VERSION=$(cat /opt/KamiWazaAI_version.txt 2>/dev/null || echo "0.0.0")

  if [[ "${LATEST_VERSION}" != "${CURRENT_VERSION}" ]]; then
    msg_info "Updating ${APP} to v${LATEST_VERSION}"

    msg_info "Stopping KamiWaza Service"
    $STD systemctl stop kamiwaza
    msg_ok "Service Stopped"

    msg_info "Creating backup"
    cp -r /opt/kamiwaza /opt/kamiwaza-backup
    msg_ok "Backup created"

    msg_info "Downloading ${APP} v${LATEST_VERSION}"
    cd /opt || exit
    rm -rf kamiwaza
    mkdir -p kamiwaza && cd kamiwaza || exit
    wget -q "https://github.com/kamiwaza-ai/kamiwaza-community-edition/raw/main/kamiwaza-community-${LATEST_VERSION}-UbuntuLinux.tar.gz"
    tar -xf "kamiwaza-community-${LATEST_VERSION}-UbuntuLinux.tar.gz" &>/dev/null
    msg_ok "Downloaded ${APP} v${LATEST_VERSION}"

    msg_info "Running KamiWaza installer"
    export PATH="/usr/local/bin:$PATH"
    chown -R kamiwaza:kamiwaza /opt/kamiwaza
    $STD sudo -u kamiwaza bash install.sh --community
    msg_ok "Installation completed"

    msg_info "Starting KamiWaza Service"
    $STD systemctl start kamiwaza
    msg_ok "Service Started"

    msg_info "Cleanup"
    rm -rf /opt/kamiwaza-community-"${LATEST_VERSION}"-UbuntuLinux.tar.gz
    rm -rf /opt/kamiwaza-backup
    msg_ok "Cleanup completed"

    echo "${LATEST_VERSION}" > /opt/KamiWazaAI_version.txt
    msg_ok "Updated ${APP} to v${LATEST_VERSION}"
  else
    msg_ok "No update required. ${APP} is already at v${CURRENT_VERSION}."
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
