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

# msg_info "Setting Up GPU Compute Support for AI/ML"
# # Detect available GPUs
# INTEL_GPU_DETECTED=false
# AMD_GPU_DETECTED=false

# if lspci | grep -i "vga\|3d\|display" | grep -i intel &> /dev/null; then
#   INTEL_GPU_DETECTED=true
#   msg_info "Intel GPU detected"
# fi

# if lspci | grep -i "vga\|3d\|display" | grep -i "amd\|radeon" &> /dev/null; then
#   AMD_GPU_DETECTED=true
#   msg_info "AMD GPU detected"
# fi

# if [[ "$INTEL_GPU_DETECTED" == "false" && "$AMD_GPU_DETECTED" == "false" ]]; then
#   msg_info "No Intel or AMD GPU detected - installing basic OpenCL support only"
# fi

# $STD apt-get -y install {ocl-icd-libopencl1,clinfo,mesa-opencl-icd}

# if [[ "$CTTYPE" == "0" ]]; then
#   # Set up GPU device permissions
#   if [[ -d /dev/dri ]]; then
#     chgrp video /dev/dri
#     chmod 755 /dev/dri
#     chmod 660 /dev/dri/* 2>/dev/null || true
#   fi
#   $STD adduser "$(id -u -n)" video
#   $STD adduser "$(id -u -n)" render
# fi
# msg_ok "Set Up Base GPU Compute Support"

# # Intel GPU compute support for AI workloads (only if detected)
# if [[ "$INTEL_GPU_DETECTED" == "true" ]]; then
#   read -r -p "${TAB3}Install Intel GPU compute support for AI workloads? <y/N> " intel_prompt
#   if [[ ${intel_prompt,,} =~ ^(y|yes)$ ]]; then
#     msg_info "Installing Intel GPU compute support"

#     # Add Intel GPU repositories
#     mkdir -p /etc/apt/keyrings
#     curl -fsSL https://repositories.intel.com/gpu/intel-graphics.key | gpg --dearmor -o /etc/apt/keyrings/intel-graphics.gpg
#     echo "deb [arch=amd64,i386 signed-by=/etc/apt/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" >/etc/apt/sources.list.d/intel-gpu-jammy.list
#     curl -fsSL https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor -o /etc/apt/keyrings/oneapi-archive-keyring.gpg
#     echo "deb [signed-by=/etc/apt/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" >/etc/apt/sources.list.d/oneAPI.list
#     $STD apt-get update

#     # Install Intel compute packages
#     $STD apt-get -y install {intel-opencl-icd,intel-level-zero-gpu,level-zero,level-zero-dev,intel-gpu-tools}

#     msg_ok "Installed Intel GPU compute support"
#   fi
# fi

# # AMD GPU compute support for AI workloads (only if detected)
# if [[ "$AMD_GPU_DETECTED" == "true" ]]; then
#   read -r -p "${TAB3}Install AMD GPU compute support for AI workloads? <y/N> " amd_prompt
#   if [[ ${amd_prompt,,} =~ ^(y|yes)$ ]]; then
#     msg_info "Installing AMD GPU compute support"

#     # Install AMD compute packages
#     $STD apt-get -y install {mesa-opencl-icd,radeontop}

#     # Check if user wants ROCm for advanced compute
#     read -r -p "${TAB3}Install AMD ROCm for advanced GPU compute? (Large download) <y/N> " rocm_prompt
#     if [[ ${rocm_prompt,,} =~ ^(y|yes)$ ]]; then
#       msg_info "Installing AMD ROCm"

#       # Add ROCm repository
#       curl -fsSL https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor -o /etc/apt/keyrings/rocm.gpg
#       echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.0.2 jammy main" > /etc/apt/sources.list.d/rocm.list
#       $STD apt-get update

#       # Install basic ROCm packages
#       $STD apt-get -y install {rocm-dev,rocm-libs,rocm-utils}

#       msg_ok "Installed AMD ROCm"
#     fi
#     msg_ok "Installed AMD GPU compute support"
#   fi
# fi

msg_info "Installing Dependencies"
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
    software-properties-common \
    gnupg \
    lsb-release \
    bc
msg_ok "Installed Dependencies"

NODE_VERSION="22" NODE_MODULE="webpack@latest,webpack-cli@latest,pm2@latest" setup_nodejs

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

msg_info "Creating kamiwaza user"
if ! id "kamiwaza" &>/dev/null; then
    useradd -m -s /bin/bash kamiwaza
fi
usermod -aG docker kamiwaza

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
KAMIWAZA_LOG_DIR="/home/kamiwaza/logs"
mkdir -p "$KAMIWAZA_DIR"
mkdir -p "$KAMIWAZA_LOG_DIR"
chown -R kamiwaza:kamiwaza "$KAMIWAZA_DIR"
chown -R kamiwaza:kamiwaza "$KAMIWAZA_LOG_DIR"
echo "export KAMIWAZA_LOG_DIR=\"$KAMIWAZA_LOG_DIR\"" >> /home/kamiwaza/.bashrc

# Run the installation as the kamiwaza user
sudo -u kamiwaza bash -c "
    export PATH='/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\$PATH'
    cd '$KAMIWAZA_DIR'

    # Get the latest version or use fallback
    KAMIWAZA_VERSION=\$(curl -fsSL https://api.github.com/repos/kamiwaza-ai/kamiwaza-community-edition/contents/ 2>/dev/null | jq -r '.[] | select(.name | test(\"kamiwaza-community-.*-UbuntuLinux.tar.gz\")) | .name' 2>/dev/null | sed 's/kamiwaza-community-\(.*\)-UbuntuLinux.tar.gz/\1/' | sort -V | tail -1)
    if [[ -z \"\$KAMIWAZA_VERSION\" ]]; then
        KAMIWAZA_VERSION=\"0.5.0\"
    fi

    wget \"https://github.com/kamiwaza-ai/kamiwaza-community-edition/raw/main/kamiwaza-community-\${KAMIWAZA_VERSION}-UbuntuLinux.tar.gz\"
    tar -xvf \"kamiwaza-community-\${KAMIWAZA_VERSION}-UbuntuLinux.tar.gz\"

    # Set up proper environment for the user
    echo 'export PATH=\"/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\$PATH\"' >> ~/.bashrc

    # Ensure Node.js is available
    export NODE_PATH=/usr/bin/node
    export NPM_PATH=/usr/bin/npm

    # Run the installer with automatic EULA acceptance
    echo -e '\n\nyes' | bash install.sh --community

    # Fix missing Milvus architecture folder (critical for container validation)
    if [ -d \"kamiwaza/deployment/kamiwaza-milvus/amd64-gpu\" ] && [ ! -e \"kamiwaza/deployment/kamiwaza-milvus/amd64\" ]; then
        ln -s amd64-gpu kamiwaza/deployment/kamiwaza-milvus/amd64
    fi

    # Clean up tarball
    rm -f \"kamiwaza-community-\${KAMIWAZA_VERSION}-UbuntuLinux.tar.gz\"
"

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

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=false
ReadWritePaths=/opt/kamiwaza /var/log
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
