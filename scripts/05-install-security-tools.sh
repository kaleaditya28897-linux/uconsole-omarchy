#!/bin/bash
# =============================================================================
# uConsole Omarchy - Security & Hacking Tools
# Pentesting, network analysis, and security tools
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

[ "$EUID" -ne 0 ] && error "Run as root"

USERNAME="cyber"
USER_HOME="/home/${USERNAME}"

# =============================================================================
# Enable BlackArch Repository (Optional - for more tools)
# =============================================================================
log "Setting up BlackArch repository..."

curl -s https://blackarch.org/strap.sh -o /tmp/strap.sh
chmod +x /tmp/strap.sh
# Verify checksum before running (check blackarch.org for current hash)
# /tmp/strap.sh

warn "BlackArch setup script downloaded to /tmp/strap.sh"
warn "Verify and run manually if you want BlackArch tools"

# =============================================================================
# Network Analysis & Reconnaissance
# =============================================================================
log "Installing network analysis tools..."

pacman -S --noconfirm --needed \
    nmap \
    masscan \
    rustscan \
    wireshark-cli \
    tcpdump \
    netcat \
    socat \
    netsniff-ng \
    arp-scan \
    iftop \
    nethogs \
    bandwhich \
    termshark \
    traceroute \
    mtr \
    whois \
    bind-tools \
    dnsutils \
    inetutils \
    iputils \
    net-tools

# =============================================================================
# Web Security
# =============================================================================
log "Installing web security tools..."

pacman -S --noconfirm --needed \
    nikto \
    sqlmap \
    gobuster \
    ffuf \
    httpie \
    curl \
    wget \
    lynx \
    w3m

# Install additional tools via pip
sudo -u ${USERNAME} pip install --user \
    wfuzz \
    sslyze \
    arjun \
    dirsearch 2>/dev/null || warn "Some pip tools failed"

# =============================================================================
# Password & Credential Tools
# =============================================================================
log "Installing password tools..."

pacman -S --noconfirm --needed \
    john \
    hashcat \
    hydra \
    crunch \
    wordlists

# Download SecLists if not present
if [ ! -d "/usr/share/seclists" ]; then
    log "Downloading SecLists wordlists..."
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git /usr/share/seclists 2>/dev/null || \
        warn "SecLists download failed - install manually"
fi

# =============================================================================
# Wireless Tools
# =============================================================================
log "Installing wireless tools..."

pacman -S --noconfirm --needed \
    aircrack-ng \
    iw \
    wireless_tools \
    wpa_supplicant \
    hostapd \
    macchanger \
    horst \
    wavemon

# =============================================================================
# Exploitation & Reversing
# =============================================================================
log "Installing exploitation tools..."

pacman -S --noconfirm --needed \
    metasploit \
    radare2 \
    ghidra \
    binwalk \
    foremost \
    gdb \
    pwndbg \
    ropper \
    hexedit \
    xxd

# Python exploitation libraries
sudo -u ${USERNAME} pip install --user \
    pwntools \
    ropper \
    keystone-engine \
    capstone \
    unicorn 2>/dev/null || warn "Some Python tools failed"

# =============================================================================
# Forensics
# =============================================================================
log "Installing forensics tools..."

pacman -S --noconfirm --needed \
    sleuthkit \
    autopsy \
    volatility3 \
    testdisk \
    photorec \
    scalpel \
    exiftool \
    strings \
    file

# =============================================================================
# Cryptography
# =============================================================================
log "Installing cryptography tools..."

pacman -S --noconfirm --needed \
    openssl \
    gnupg \
    age \
    sops \
    hashdeep

# =============================================================================
# Sysadmin & Infrastructure
# =============================================================================
log "Installing sysadmin/DevOps tools..."

pacman -S --noconfirm --needed \
    ansible \
    terraform \
    docker \
    docker-compose \
    kubectl \
    helm \
    k9s \
    aws-cli-v2 \
    nfs-utils \
    samba \
    ldap-utils \
    openvpn \
    wireguard-tools

# Enable Docker
systemctl enable docker
usermod -aG docker ${USERNAME}

# =============================================================================
# Monitoring & Logging
# =============================================================================
log "Installing monitoring tools..."

pacman -S --noconfirm --needed \
    lnav \
    goaccess \
    sysstat \
    iotop \
    strace \
    ltrace \
    lsof \
    perf \
    audit

# =============================================================================
# Anonymity & Privacy
# =============================================================================
log "Installing privacy tools..."

pacman -S --noconfirm --needed \
    tor \
    torsocks \
    proxychains-ng

cat > /etc/proxychains.conf << 'PROXYCHAINS'
# ProxyChains Configuration
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
localnet ::1/128

[ProxyList]
socks5 127.0.0.1 9050
PROXYCHAINS

# =============================================================================
# Helper Scripts
# =============================================================================
log "Creating helper scripts..."

mkdir -p ${USER_HOME}/.local/bin

# Quick scan script
cat > ${USER_HOME}/.local/bin/quickscan << 'QUICKSCAN'
#!/bin/bash
# Quick network scan helper

TARGET="${1:-192.168.1.0/24}"

echo "[*] Quick scan of $TARGET"
echo ""

echo "[+] Fast port scan..."
rustscan -a "$TARGET" --ulimit 5000 -- -sV 2>/dev/null || \
    nmap -sn "$TARGET" 2>/dev/null

echo ""
echo "[+] Done"
QUICKSCAN
chmod +x ${USER_HOME}/.local/bin/quickscan

# Web recon script
cat > ${USER_HOME}/.local/bin/webrecon << 'WEBRECON'
#!/bin/bash
# Quick web reconnaissance

URL="${1}"

if [ -z "$URL" ]; then
    echo "Usage: webrecon <url>"
    exit 1
fi

echo "[*] Web recon: $URL"
echo ""

# Basic info
echo "[+] HTTP Headers:"
curl -sI "$URL" | head -20
echo ""

# Technology detection
echo "[+] Technology hints:"
curl -s "$URL" | grep -Eoi '<(script|link)[^>]+(src|href)="[^"]+' | head -10
echo ""

echo "[+] Robots.txt:"
curl -s "${URL}/robots.txt" 2>/dev/null | head -20
echo ""

echo "[+] Done"
WEBRECON
chmod +x ${USER_HOME}/.local/bin/webrecon

# Hash identifier
cat > ${USER_HOME}/.local/bin/hashid << 'HASHID'
#!/bin/bash
# Simple hash identifier

HASH="$1"

if [ -z "$HASH" ]; then
    echo "Usage: hashid <hash>"
    exit 1
fi

LEN=${#HASH}

echo "Hash: $HASH"
echo "Length: $LEN characters"
echo ""
echo "Possible types:"

case $LEN in
    32) echo "  - MD5" ;;
    40) echo "  - SHA-1" ;;
    64) echo "  - SHA-256 / NTLM (if hex)" ;;
    96) echo "  - SHA-384" ;;
    128) echo "  - SHA-512" ;;
    *) echo "  - Unknown (check manually)" ;;
esac

# Check format
if [[ "$HASH" =~ ^\$[0-9a-z]+\$ ]]; then
    echo "  - Unix crypt format detected"
    if [[ "$HASH" =~ ^\$6\$ ]]; then echo "    -> SHA-512 crypt"; fi
    if [[ "$HASH" =~ ^\$5\$ ]]; then echo "    -> SHA-256 crypt"; fi
    if [[ "$HASH" =~ ^\$2[aby]\$ ]]; then echo "    -> bcrypt"; fi
    if [[ "$HASH" =~ ^\$1\$ ]]; then echo "    -> MD5 crypt"; fi
fi
HASHID
chmod +x ${USER_HOME}/.local/bin/hashid

# Port info
cat > ${USER_HOME}/.local/bin/portinfo << 'PORTINFO'
#!/bin/bash
# Quick port service info

PORT="${1}"

if [ -z "$PORT" ]; then
    echo "Usage: portinfo <port>"
    exit 1
fi

echo "Port $PORT:"
grep -w "$PORT" /etc/services 2>/dev/null | head -5

# Common ports not in services
case $PORT in
    8080) echo "  Common: HTTP Proxy / Alt HTTP" ;;
    8443) echo "  Common: HTTPS Alt" ;;
    3389) echo "  Common: RDP (Windows Remote Desktop)" ;;
    5432) echo "  Common: PostgreSQL" ;;
    27017) echo "  Common: MongoDB" ;;
    6379) echo "  Common: Redis" ;;
    9200) echo "  Common: Elasticsearch" ;;
    2375|2376) echo "  Common: Docker API" ;;
    4444) echo "  Common: Metasploit default handler" ;;
esac
PORTINFO
chmod +x ${USER_HOME}/.local/bin/portinfo

# =============================================================================
# Zsh aliases for security tools
# =============================================================================
log "Adding security aliases..."

cat >> ${USER_HOME}/.zshrc << 'SECURITY_ALIASES'

# Security tool aliases
alias nse='ls /usr/share/nmap/scripts/ | grep'
alias serve='python -m http.server'
alias urlencode='python -c "import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))"'
alias urldecode='python -c "import sys,urllib.parse;print(urllib.parse.unquote(sys.argv[1]))"'
alias b64e='base64'
alias b64d='base64 -d'
alias rot13='tr "A-Za-z" "N-ZA-Mn-za-m"'
alias listening='ss -tlnp'
alias connections='ss -tnp'
alias myip='curl -s ifconfig.me'
alias localip="ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1"
alias sniff='sudo tcpdump -i any -w /tmp/capture.pcap'
alias tshark-http='tshark -i any -Y http'
alias proxyon='export http_proxy="socks5://127.0.0.1:9050" https_proxy="socks5://127.0.0.1:9050"'
alias proxyoff='unset http_proxy https_proxy'
SECURITY_ALIASES

# =============================================================================
# Set ownership
# =============================================================================
chown -R ${USERNAME}:${USERNAME} ${USER_HOME}

log "=============================================="
log "Security tools installation complete!"
log ""
log "Installed categories:"
log "  - Network: nmap, masscan, rustscan, wireshark"
log "  - Web: nikto, sqlmap, gobuster, ffuf"
log "  - Passwords: john, hashcat, hydra"
log "  - Wireless: aircrack-ng, hostapd"
log "  - Exploitation: metasploit, radare2, pwntools"
log "  - Forensics: sleuthkit, volatility3"
log "  - Infrastructure: docker, ansible, terraform"
log "  - Privacy: tor, proxychains"
log ""
log "Helper scripts in ~/.local/bin:"
log "  - quickscan, webrecon, hashid, portinfo"
log ""
log "Next: Run ./06-system-services.sh"
log "=============================================="
