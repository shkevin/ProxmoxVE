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

