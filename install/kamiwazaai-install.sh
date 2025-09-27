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

# Check memory requirements
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [[ $TOTAL_MEM -lt 16000 ]]; then
  msg_error "Insufficient memory! KamiWaza requires minimum 16GB RAM. Current: ${TOTAL_MEM}MB"
  msg_info "Recommended: 32GB RAM for optimal performance"
  exit 1
fi
msg_info "Memory check passed: ${TOTAL_MEM}MB available (16GB+ required)"

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)

msg_info "Installing Core System Dependencies"
$STD apt-get install -y \
  software-properties-common \
  apt-transport-https \
  ca-certificates \
  curl \
  wget \
  gnupg \
  lsb-release \
  net-tools \
  jq
msg_ok "Installed Core System Dependencies"

# Install Python 3.10 using deadsnakes PPA (for system-wide availability)
msg_info "Installing Python 3.10"
$STD apt-get install -y software-properties-common
$STD add-apt-repository -y ppa:deadsnakes/ppa
$STD apt-get update
$STD apt-get install -y python3.10 python3.10-venv python3.10-dev python3.10-distutils
msg_ok "Installed Python 3.10"

# Configure Python for KamiWaza compatibility
msg_info "Configuring Python and pip for KamiWaza"
# Clean up any old Python installations
rm -f /usr/local/bin/python /usr/local/bin/python3.10 /usr/local/bin/pip
update-alternatives --remove-all python >/dev/null 2>&1 || true
# Create simple symlinks instead of alternatives for better reliability
ln -sf /usr/bin/python3.10 /usr/local/bin/python
ln -sf /usr/bin/python3.10 /usr/local/bin/python3.10
# Install pip and create symlink
$STD apt-get install -y python3-pip python3-venv
ln -sf /usr/bin/pip3 /usr/local/bin/pip
# Ensure /usr/local/bin is in PATH for current session
export PATH="/usr/local/bin:$PATH"
msg_ok "Configured Python and pip for KamiWaza"

msg_info "Installing Graphics & Development Libraries"
$STD apt-get install -y \
  libcairo2-dev \
  libgirepository1.0-dev
msg_ok "Installed Graphics & Development Libraries"

msg_info "Installing System Tools"
$STD apt-get install -y \
  golang-cfssl \
  etcd-client
msg_ok "Installed System Tools"

msg_info "Installing Node.js 22"
export NODE_VERSION="22"
setup_nodejs
msg_ok "Installed Node.js 22"

msg_info "Installing Docker Engine + Compose v2"
# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg &>/dev/null
# Set up the Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
$STD apt-get update
$STD apt-get install -y docker-ce docker-ce-cli containerd.io
# Install Docker Compose v2
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/v2.39.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose &>/dev/null
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
# Add root to docker group (container runs as root)
usermod -aG docker root
msg_ok "Installed Docker Engine + Compose v2"

msg_info "Installing CockroachDB"
wget -qO- https://binaries.cockroachdb.com/cockroach-v23.2.12.linux-amd64.tgz | tar xz &>/dev/null
cp cockroach-v23.2.12.linux-amd64/cockroach /usr/local/bin/
rm -rf cockroach-v23.2.12.linux-amd64
msg_ok "Installed CockroachDB"

msg_info "Installing KamiWaza CE via Tarball"
# Get the latest version from available tarballs in the repository
KAMIWAZA_VERSION=$(curl -fsSL https://api.github.com/repos/kamiwaza-ai/kamiwaza-community-edition/contents/ | jq -r '.[] | select(.name | test("kamiwaza-community-.*-UbuntuLinux.tar.gz")) | .name' | sed 's/kamiwaza-community-\(.*\)-UbuntuLinux.tar.gz/\1/' | sort -V | tail -1)
if [[ -z "$KAMIWAZA_VERSION" ]]; then
  # Fallback to known version if API fails
  KAMIWAZA_VERSION="0.5.0"
fi

mkdir -p /opt/kamiwaza && cd /opt/kamiwaza || exit
wget -q "https://github.com/kamiwaza-ai/kamiwaza-community-edition/raw/main/kamiwaza-community-${KAMIWAZA_VERSION}-UbuntuLinux.tar.gz"
tar -xf "kamiwaza-community-${KAMIWAZA_VERSION}-UbuntuLinux.tar.gz" &>/dev/null
echo "${KAMIWAZA_VERSION}" > "/opt/KamiWazaAI_version.txt"
msg_ok "Downloaded KamiWaza CE v${KAMIWAZA_VERSION}"

msg_info "Creating KamiWaza user"
# Create a dedicated user for KamiWaza (since it won't run as root)
useradd -r -m -s /bin/bash kamiwaza || true
usermod -aG docker kamiwaza
# Set ownership of KamiWaza directory
chown -R kamiwaza:kamiwaza /opt/kamiwaza
# Ensure kamiwaza user has proper PATH and environment
echo 'export PATH="/usr/local/bin:$PATH"' >> /home/kamiwaza/.bashrc
echo 'export PYTHON=/usr/bin/python3.10' >> /home/kamiwaza/.bashrc
msg_ok "Created KamiWaza user"

msg_info "Running KamiWaza Installer"
# Set environment for installer - ensure all tools are available
export PATH="/usr/local/bin:$PATH"
# Verify prerequisites are available
msg_info "Verifying prerequisites for KamiWaza installer"
echo "Python version: $(python --version)"
echo "Python3.10 version: $(python3.10 --version)"
echo "Pip version: $(pip --version)"
echo "Node version: $(node --version)"
echo "Docker version: $(docker --version)"
msg_ok "Prerequisites verified"

# Run installer without silencing output to debug issues
msg_info "Executing KamiWaza installer as kamiwaza user"
# Automatically accept EULA and continue installation with proper environment
echo -e "\nyes" | sudo -u kamiwaza -H env PATH="/usr/local/bin:$PATH" PYTHON=/usr/bin/python3.10 bash install.sh --community
msg_ok "KamiWaza Installation Completed"

msg_info "Creating systemd service"
cat <<EOF >/etc/systemd/system/kamiwaza.service
[Unit]
Description=KamiWaza AI Platform
Documentation=https://docs.kamiwaza.ai/
After=network.target docker.service
Wants=docker.service

[Service]
Type=forking
User=kamiwaza
Group=kamiwaza
WorkingDirectory=/opt/kamiwaza
ExecStart=/opt/kamiwaza/startup/kamiwazad.sh start
ExecStop=/opt/kamiwaza/startup/kamiwazad.sh stop
ExecReload=/opt/kamiwaza/startup/kamiwazad.sh restart
Restart=on-failure
RestartSec=5
TimeoutStartSec=300
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kamiwaza
systemctl start kamiwaza
msg_ok "Created and started systemd service"


msg_info "Checking GPU Support"
if command -v nvidia-smi &> /dev/null; then
  GPU_INFO=$(nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader,nounits 2>/dev/null | head -1)
  if [[ -n "$GPU_INFO" ]]; then
    msg_info "NVIDIA GPU detected: $GPU_INFO"
    COMPUTE_CAP=$(echo "$GPU_INFO" | cut -d',' -f2 | tr -d ' ')
    if (( $(echo "$COMPUTE_CAP >= 7.0" | bc -l 2>/dev/null || echo "0") )); then
      msg_ok "GPU meets KamiWaza requirements (Compute Capability 7.0+)"
    else
      msg_info "GPU Compute Capability $COMPUTE_CAP may not meet requirements (7.0+ recommended)"
    fi
  fi
else
  msg_info "No NVIDIA GPU detected - CPU-only mode"
  msg_info "For GPU support, install NVIDIA drivers and nvidia-container-toolkit"
fi

msg_info "Saving Access Information"
{
  echo "KamiWaza CE Access Information"
  echo "============================="
  echo "Web Console: https://$(hostname -I | awk '{print $1}')"
  echo "Default Username: admin"
  echo "Default Password: kamiwaza"
  echo ""
  echo "System Requirements Met:"
  echo "- OS: Ubuntu ${UBUNTU_VERSION} LTS"
  echo "- Memory: ${TOTAL_MEM}MB (16GB+ required)"
  echo "- Python: 3.10 (tarball installation)"
  echo "- Docker: Engine with Compose v2"
  echo "- Node.js: 22 (via NVM)"
  echo ""
  if command -v nvidia-smi &> /dev/null; then
    echo "GPU Support: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo 'Not available')"
  else
    echo "GPU Support: Not configured (CPU-only mode)"
    echo "For GPU acceleration: Install NVIDIA drivers >= 450.80.02"
  fi
  echo ""
  echo "Service Management:"
  echo "Start:   systemctl start kamiwaza"
  echo "Stop:    systemctl stop kamiwaza"
  echo "Restart: systemctl restart kamiwaza"
  echo "Status:  systemctl status kamiwaza"
  echo ""
  echo "Installation Directory: /opt/kamiwaza"
  echo "Version: ${KAMIWAZA_VERSION}"
  echo ""
  echo "Network Ports:"
  echo "- 443/tcp: HTTPS primary access"
  echo "- 51100-51199/tcp: Model deployment ports (if needed)"
} >> ~/kamiwaza.info
msg_ok "Saved Access Information"

motd_ssh
customize

msg_info "Cleaning up"
cd /opt/kamiwaza || exit
rm -f "kamiwaza-community-${KAMIWAZA_VERSION}-UbuntuLinux.tar.gz"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
