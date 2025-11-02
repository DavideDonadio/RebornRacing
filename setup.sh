#!/bin/bash

# OVH VPS AC Server Setup Script
# Run as root: sudo bash setup.sh

set -e  # Exit on error

echo "================================"
echo "OVH VPS AC Server Setup"
echo "================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${GREEN}[1/6] Updating system packages...${NC}"
apt update && apt upgrade -y

echo -e "${GREEN}[2/6] Installing required packages...${NC}"
apt install -y nginx certbot python3-certbot-nginx ufw curl wget git expect build-essential

echo -e "${GREEN}[3/6] Installing and configuring No-IP2...${NC}"

cd /tmp
wget https://www.noip.com/client/linux/noip-duc-linux.tar.gz
tar xzf noip-duc-linux.tar.gz
cd noip-2.1.9-1
make install

# Create systemd service for noip2
cat > /etc/systemd/system/noip2.service <<'EOF'
[Unit]
Description=No-IP Dynamic DNS Update Client
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/noip2
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable noip2
systemctl start noip2

echo -e "${GREEN}[4/6] Configuring NGINX...${NC}"

# Download nginx.conf from GitHub
wget -O /etc/nginx/nginx.conf https://raw.githubusercontent.com/DavideDonadio/rebornracing-vps-setup/main/nginx.conf

# Test nginx configuration
nginx -t

# Restart nginx
systemctl restart nginx
systemctl enable nginx

echo -e "${GREEN}[5/6] Setting up SSL certificates with Certbot...${NC}"
echo -e "${YELLOW}Waiting for No-IP DNS to propagate...${NC}"

# Wait for DNS to resolve correctly
until host rebornracing.ddns.net >/dev/null 2>&1; do
  echo -e "${YELLOW}Still waiting for DNS to resolve...${NC}"
  sleep 10
done

# Run certbot automatically (non-interactive)
sudo certbot certonly --standalone -d rebornracing.ddns.net --non-interactive --agree-tos --email davide.donadio@protonmail.com
echo -e "${GREEN}SSL certificates configured!${NC}"

echo -e "${GREEN}[6/6] Configuring Firewall (UFW)...${NC}"
# Reset UFW to default
ufw --force reset

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow required ports
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 8081/tcp comment 'AC Server Port'
ufw allow 8108/tcp comment 'AC Server Port'
ufw allow 19600/tcp comment 'AC Server Port'
ufw allow 19600/udp comment 'AC Server Port'

# Enable UFW
ufw --force enable

echo -e "${GREEN}[7/7] Setting UDP Buffer Values to 4MB...${NC}"

# Set UDP buffer sizes
sysctl -w net.core.rmem_max=4194304
sysctl -w net.core.wmem_max=4194304
sysctl -w net.core.rmem_default=4194304
sysctl -w net.core.wmem_default=4194304

# Make changes persistent only once
if ! grep -q "UDP Buffer Settings for AC Server" /etc/sysctl.conf; then
cat >> /etc/sysctl.conf <<EOF

# UDP Buffer Settings for AC Server
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.core.rmem_default=4194304
net.core.wmem_default=4194304
EOF
fi

# Apply sysctl changes
sysctl -p

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Important Next Steps:${NC}"
echo ""
echo "1. Configure No-IP2:"
echo "   sudo noip2 -C"
echo "   (Enter your No-IP username, password, and select hostname)"
echo ""
echo "2. Start No-IP2 service:"
echo "   sudo systemctl start noip2"
echo ""
echo "3. Verify firewall rules:"
echo "   sudo ufw status verbose"
echo ""
echo "4. Check NGINX status:"
echo "   sudo systemctl status nginx"
echo ""
echo "5. Verify UDP buffer settings:"
echo "   sysctl net.core.rmem_max net.core.wmem_max"
echo ""
echo -e "${YELLOW}Ports opened:${NC}"
echo "  - 22 (SSH)"
echo "  - 80 (HTTP)"
echo "  - 443 (HTTPS)"
echo "  - 8081 (AC Server)"
echo "  - 8108 (AC Server)"
echo "  - 19600 (AC Server TCP/UDP)"
echo ""
echo -e "${GREEN}Server is ready for Assetto Corsa server deployment!${NC}"
echo ""
