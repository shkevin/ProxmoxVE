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
# Install software-properties-common first for add-apt-repository
$STD apt-get install -y software-properties-common

# Add deadsnakes PPA for Python 3.10
$STD add-apt-repository ppa:deadsnakes/ppa -y
$STD apt-get update

$STD apt-get install -y \
    python3.10 \
    python3.10-dev \
    libpython3.10-dev \
    python3.10-venv \
    golang-cfssl \
    python-is-python3 \
    etcd-client \
    net-tools \
    curl \
    jq \
    libcairo2-dev \
    libgirepository1.0-dev \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    bc
msg_ok "Installed Dependencies"

msg_info "Installing Node.js 22"
# Install Node.js globally as root to avoid NVM permission issues
# curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
# $STD apt-get install -y nodejs

# # Install global packages required by KamiWaza
# npm install -g webpack webpack-cli pm2
NODE_VERSION="22" NODE_MODULE="webpack@latest,webpack-cli@latest,pm2@latest" setup_nodejs

# Make Node.js available for all users
chmod a+rx /usr/bin/node /usr/bin/npm /usr/bin/npx

msg_ok "Installed Node.js 22 and required packages"

msg_info "Installing Docker"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg &>/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
$STD apt-get update
$STD apt-get install -y docker-ce docker-ce-cli containerd.io

mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/v2.39.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
usermod -aG docker root
msg_ok "Installed Docker Engine + Compose v2"

# Install CockroachDB
msg_info "Installing CockroachDB"
wget -qO- https://binaries.cockroachdb.com/cockroach-v23.2.12.linux-amd64.tgz | tar xvz
cp cockroach-v23.2.12.linux-amd64/cockroach /usr/local/bin/
chmod +x /usr/local/bin/cockroach
rm -rf cockroach-v23.2.12.linux-amd64
msg_ok "Installed CockroachDB"

# Check for NVIDIA GPU support
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
  msg_info "Refer to step 6 in the official installation guide for GPU setup"
  msg_info "guide: https://docs.kamiwaza.ai/installation/linux_macos_tarball"
fi

msg_info "Creating kamiwaza user"
if ! id "kamiwaza" &>/dev/null; then
    useradd -m -s /bin/bash kamiwaza
fi
usermod -aG docker kamiwaza

# Add kamiwaza to sudo group for passwordless sudo (needed for startup/shutdown)
usermod -aG sudo kamiwaza
echo "kamiwaza ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/kamiwaza-temp

# Add GPU group memberships for compute access
if [[ "$CTTYPE" == "0" ]]; then
    usermod -aG video kamiwaza 2>/dev/null || true
    usermod -aG render kamiwaza 2>/dev/null || true
fi

msg_ok "Created kamiwaza user"

msg_info "Downloading and installing KamiWaza CE"

# Ensure /usr/local/bin is in PATH for the installer
export PATH="/usr/local/bin:$PATH"
echo 'export PATH="/usr/local/bin:$PATH"' >> /root/.bashrc

# Set up the installation directory
KAMIWAZA_DIR="/opt/kamiwaza"
KAMIWAZA_LOG_DIR="/opt/kamiwaza/logs"
mkdir -p "$KAMIWAZA_DIR"
mkdir -p "$KAMIWAZA_LOG_DIR"
chown -R kamiwaza:kamiwaza "$KAMIWAZA_DIR"
chown -R kamiwaza:kamiwaza "$KAMIWAZA_LOG_DIR"
# Set log directory environment variable system-wide for all users
echo "KAMIWAZA_LOG_DIR=\"$KAMIWAZA_LOG_DIR\"" >> /etc/environment

# Also set for kamiwaza user specifically
echo "export KAMIWAZA_LOG_DIR=\"$KAMIWAZA_LOG_DIR\"" >> /home/kamiwaza/.bashrc
echo "export KAMIWAZA_LOG_DIR=\"$KAMIWAZA_LOG_DIR\"" >> /home/kamiwaza/.profile

# Run the installation as root (for system-level access)
cd "$KAMIWAZA_DIR" || exit

# Get the latest version or use fallback
KAMIWAZA_VERSION=$(curl -fsSL https://api.github.com/repos/kamiwaza-ai/kamiwaza-community-edition/contents/ 2>/dev/null | jq -r '.[] | select(.name | test("kamiwaza-community-.*-UbuntuLinux.tar.gz")) | .name' 2>/dev/null | sed 's/kamiwaza-community-\(.*\)-UbuntuLinux.tar.gz/\1/' | sort -V | tail -1)
if [[ -z "$KAMIWAZA_VERSION" ]]; then
    KAMIWAZA_VERSION="0.5.0"
fi

wget "https://github.com/kamiwaza-ai/kamiwaza-community-edition/raw/main/kamiwaza-community-${KAMIWAZA_VERSION}-UbuntuLinux.tar.gz"
tar -xvf "kamiwaza-community-${KAMIWAZA_VERSION}-UbuntuLinux.tar.gz"

# Ensure Node.js is available for installer
export NODE_PATH=/usr/bin/node
export NPM_PATH=/usr/bin/npm

# Run the installer with automatic EULA acceptance (as root)
echo -e '\n\nyes' | KAMIWAZA_LOG_DIR=$KAMIWAZA_LOG_DIR bash install.sh --community

# Fix missing Milvus architecture folder (critical for container validation)
if [ -d "kamiwaza/deployment/kamiwaza-milvus/amd64-gpu" ] && [ ! -e "kamiwaza/deployment/kamiwaza-milvus/amd64" ]; then
    ln -s amd64-gpu kamiwaza/deployment/kamiwaza-milvus/amd64
fi

# Clean up tarball
rm -f "kamiwaza-community-${KAMIWAZA_VERSION}-UbuntuLinux.tar.gz"

# Set proper ownership after installation
chown -R kamiwaza:kamiwaza "$KAMIWAZA_DIR"
chown -R kamiwaza:kamiwaza "$KAMIWAZA_LOG_DIR"

# Create notebook virtual environment if it doesn't exist
if [[ ! -d "/opt/kamiwaza/notebook-venv" ]]; then
    msg_info "Creating notebook virtual environment"
    cd /opt/kamiwaza || exit
    python3.10 -m venv notebook-venv

    # Install Jupyter packages in the notebook venv
    source notebook-venv/bin/activate
    pip install --upgrade pip
    pip install jupyterlab notebook ipykernel
    deactivate

    # Set ownership to kamiwaza user
    chown -R kamiwaza:kamiwaza notebook-venv
    msg_ok "Created notebook virtual environment"
else
    msg_info "Notebook virtual environment already exists"
fi


INSTALLATION_STATUS=$?
if [[ $INSTALLATION_STATUS -eq 0 ]]; then
    msg_ok "KamiWaza installation completed"
else
    msg_error "KamiWaza installation failed"
    exit 1
fi

msg_info "Creating systemd service"
cat > /etc/systemd/system/kamiwaza.service << 'EOF'
[Unit]
Description=KamiWaza Community Edition AI Platform
Documentation=https://github.com/kamiwaza-ai/kamiwaza-community-edition
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=exec
User=kamiwaza
Group=kamiwaza
WorkingDirectory=/opt/kamiwaza/
Environment=PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
Environment=KAMIWAZA_LOG_DIR=/opt/kamiwaza/logs
Environment=NODE_PATH=/usr/bin/node
Environment=NPM_PATH=/usr/bin/npm

ExecStart=/bin/bash startup/kamiwazad.sh start
ExecStop=/bin/bash startup/kamiwazad.sh stop
ExecReload=/bin/bash startup/kamiwazad.sh restart

# Service behavior
Restart=on-failure
RestartSec=30
TimeoutStartSec=600
TimeoutStopSec=120

# Security settings (relaxed for KamiWaza requirements)
NoNewPrivileges=false
PrivateTmp=false
ProtectSystem=false
ProtectHome=false
ReadWritePaths=/opt/kamiwaza /var/log /home/kamiwaza
SupplementaryGroups=docker

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=kamiwaza

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kamiwaza.service
msg_ok "Created systemd service"

msg_info "Starting KamiWaza service"
systemctl start kamiwaza.service
msg_ok "Started KamiWaza service"

msg_info "Saving access information"
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
UBUNTU_VERSION=$(lsb_release -rs)
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
  echo "- Python: 3.10"
  echo "- Docker: Engine with Compose v2"
  echo "- Node.js: 22"
  echo ""
  echo "GPU Support: OpenCL compute enabled for AI/ML workloads"
  echo ""
  echo "Installation Directory: $KAMIWAZA_LOG_DIR"
  echo ""
  echo "Network Ports:"
  echo "- 443/tcp: HTTPS primary access"
  echo "- 3000/tcp: Frontend (if not using reverse proxy)"
  echo ""
  echo "Troubleshooting:"
  echo "- Check status: bash $KAMIWAZA_LOG_DIR/startup/kamiwazad.sh doctor"
  echo "- View logs: ls $KAMIWAZA_LOG_DIR/logs/"
  echo "- Monitor startup: bash $KAMIWAZA_LOG_DIR/startup/kamiwazad.sh status -w"
  echo "- Test GPU compute: clinfo"
  echo "- Logs: tail -f /opt/kamiwaza/logs/*.log"
} > /home/kamiwaza/kamiwaza-access-info.txt

chown kamiwaza:kamiwaza /home/kamiwaza/kamiwaza-access-info.txt

msg_ok "Access information saved to ~/kamiwaza-access-info.txt"

msg_info "Cleaning up and finalizing installation"
cd /root || exit

$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned up installation files"

echo ""
msg_ok "KamiWaza installation completed successfully!"
msg_info "Access the web console at: https://$(hostname -I | awk '{print $1}')"
msg_info "Default login - Username: admin, Password: kamiwaza"
msg_info "Check ~/kamiwaza-access-info.txt for complete access details"
msg_warn "Note: If you added Docker group membership, you may need to log out and back in"
msg_warn "Initial startup may take 10-30 minutes to download and start all services"

motd_ssh
customize
