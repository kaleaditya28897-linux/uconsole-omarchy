#!/bin/bash
# =============================================================================
# uConsole Omarchy - Hyprland Installation
# Installs Hyprland compositor and Wayland stack
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

# =============================================================================
# Create non-root user if doesn't exist
# =============================================================================
USERNAME="cyber"

if ! id "$USERNAME" &>/dev/null; then
    log "Creating user '${USERNAME}'..."
    useradd -m -G wheel,video,audio,input,gpio -s /bin/bash ${USERNAME}
    echo "${USERNAME}:cyber" | chpasswd
    warn "Default password is 'cyber' - change it!"

    # Enable sudo for wheel group
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
fi

# =============================================================================
# Install Wayland/Hyprland dependencies
# =============================================================================
log "Installing Wayland stack and dependencies..."

pacman -S --noconfirm --needed \
    wayland \
    wayland-protocols \
    xorg-xwayland \
    mesa \
    libdrm \
    pixman \
    libxkbcommon \
    libinput \
    seatd \
    polkit \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-utils \
    qt5-wayland \
    qt6-wayland

log "Installing Hyprland build dependencies..."
pacman -S --noconfirm --needed \
    cmake \
    ninja \
    meson \
    gcc \
    gdb \
    libliftoff \
    libdisplay-info \
    cpio \
    tomlplusplus \
    hyprlang \
    hyprcursor \
    hyprwayland-scanner \
    xcb-util-errors \
    xcb-util-wm \
    xcb-util-renderutil

# =============================================================================
# Install Hyprland
# =============================================================================
log "Installing Hyprland..."

# Try to install from repos first (if available), otherwise build from source
if pacman -Ss "^hyprland$" &>/dev/null; then
    pacman -S --noconfirm hyprland
else
    log "Building Hyprland from source (this takes a while on ARM)..."

    BUILD_DIR="/tmp/hyprland-build"
    mkdir -p ${BUILD_DIR}
    cd ${BUILD_DIR}

    # Clone Hyprland
    git clone --recursive https://github.com/hyprwm/Hyprland
    cd Hyprland

    # Build
    make all
    make install

    cd /
    rm -rf ${BUILD_DIR}
fi

# =============================================================================
# Install companion tools
# =============================================================================
log "Installing Hyprland ecosystem tools..."

pacman -S --noconfirm --needed \
    waybar \
    wofi \
    fuzzel \
    mako \
    swaylock \
    swayidle \
    grim \
    slurp \
    wl-clipboard \
    cliphist \
    brightnessctl \
    playerctl \
    pamixer \
    pavucontrol \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    wireplumber \
    foot \
    ttf-jetbrains-mono-nerd \
    ttf-font-awesome \
    noto-fonts \
    noto-fonts-emoji \
    papirus-icon-theme

# Enable audio
systemctl --global enable pipewire pipewire-pulse wireplumber

# Enable seat management
systemctl enable seatd
usermod -aG seat ${USERNAME}

# =============================================================================
# Install additional Wayland utilities
# =============================================================================
log "Installing additional utilities..."

pacman -S --noconfirm --needed \
    wtype \
    ydotool \
    wlr-randr \
    kanshi \
    swww \
    hyprpaper \
    hypridle \
    hyprlock

# =============================================================================
# Setup XDG environment
# =============================================================================
log "Configuring XDG portal..."

mkdir -p /etc/xdg/xdg-desktop-portal

cat > /etc/xdg/xdg-desktop-portal/portals.conf << 'EOF'
[preferred]
default=gtk
org.freedesktop.impl.portal.Screenshot=gtk
org.freedesktop.impl.portal.ScreenCast=gtk
EOF

# =============================================================================
# Create Hyprland configuration
# =============================================================================
log "Creating Hyprland configuration..."

USER_HOME="/home/${USERNAME}"
mkdir -p ${USER_HOME}/.config/hypr

cat > ${USER_HOME}/.config/hypr/hyprland.conf << 'HYPRCONF'
# =============================================================================
# uConsole Omarchy - Hyprland Configuration
# Optimized for 1280x720 landscape display on small form factor
# =============================================================================

# -----------------------------------------------------------------------------
# Monitor Configuration
# -----------------------------------------------------------------------------
# uConsole has a 5" 720x1280 display, rotated to landscape
monitor=,1280x720@60,0x0,1

# -----------------------------------------------------------------------------
# Environment Variables
# -----------------------------------------------------------------------------
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORMTHEME,qt5ct
env = QT_QPA_PLATFORM,wayland
env = GDK_BACKEND,wayland,x11
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = MOZ_ENABLE_WAYLAND,1

# ARM/RPi specific
env = WLR_NO_HARDWARE_CURSORS,1
env = WLR_RENDERER_ALLOW_SOFTWARE,1

# -----------------------------------------------------------------------------
# Input Configuration
# -----------------------------------------------------------------------------
input {
    kb_layout = us
    kb_options = caps:escape

    follow_mouse = 1
    sensitivity = 0

    touchpad {
        natural_scroll = true
        tap-to-click = true
        disable_while_typing = true
    }
}

# -----------------------------------------------------------------------------
# General Settings
# -----------------------------------------------------------------------------
general {
    gaps_in = 2
    gaps_out = 4
    border_size = 2
    col.active_border = rgba(7aa2f7ff) rgba(bb9af7ff) 45deg
    col.inactive_border = rgba(414868aa)
    layout = dwindle
    allow_tearing = false
}

# -----------------------------------------------------------------------------
# Decoration
# -----------------------------------------------------------------------------
decoration {
    rounding = 6

    blur {
        enabled = true
        size = 3
        passes = 1
        new_optimizations = true
        xray = false
    }

    shadow {
        enabled = true
        range = 8
        render_power = 2
        color = rgba(00000055)
    }
}

# -----------------------------------------------------------------------------
# Animations (lightweight for ARM)
# -----------------------------------------------------------------------------
animations {
    enabled = true

    bezier = easeOutQuint, 0.22, 1, 0.36, 1
    bezier = easeInOutQuint, 0.83, 0, 0.17, 1

    animation = windows, 1, 3, easeOutQuint, slide
    animation = windowsOut, 1, 3, easeInOutQuint, slide
    animation = fade, 1, 3, easeOutQuint
    animation = workspaces, 1, 3, easeOutQuint, slide
    animation = layers, 1, 3, easeOutQuint, fade
}

# -----------------------------------------------------------------------------
# Layout
# -----------------------------------------------------------------------------
dwindle {
    pseudotile = true
    preserve_split = true
    force_split = 2
    smart_split = false
    smart_resizing = true
}

master {
    new_status = master
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
    disable_splash_rendering = true
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
    vfr = true
}

# -----------------------------------------------------------------------------
# Window Rules
# -----------------------------------------------------------------------------
windowrulev2 = float,class:^(pavucontrol)$
windowrulev2 = float,class:^(nm-connection-editor)$
windowrulev2 = float,class:^(blueman-manager)$
windowrulev2 = float,title:^(Picture-in-Picture)$
windowrulev2 = float,class:^(imv)$
windowrulev2 = float,class:^(mpv)$

# Transparency for terminals
windowrulev2 = opacity 0.95 0.85,class:^(foot)$
windowrulev2 = opacity 0.95 0.85,class:^(kitty)$

# -----------------------------------------------------------------------------
# Key Bindings
# -----------------------------------------------------------------------------
$mainMod = SUPER
$terminal = foot
$menu = fuzzel
$browser = firefox
$fileManager = thunar

# Core bindings
bind = $mainMod, Return, exec, $terminal
bind = $mainMod, Q, killactive,
bind = $mainMod SHIFT, E, exit,
bind = $mainMod, Space, exec, $menu
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, B, exec, $browser
bind = $mainMod, V, togglefloating,
bind = $mainMod, F, fullscreen, 0
bind = $mainMod SHIFT, F, fullscreen, 1
bind = $mainMod, P, pseudo,

# Focus movement (vim-style)
bind = $mainMod, H, movefocus, l
bind = $mainMod, L, movefocus, r
bind = $mainMod, K, movefocus, u
bind = $mainMod, J, movefocus, d

# Window movement
bind = $mainMod SHIFT, H, movewindow, l
bind = $mainMod SHIFT, L, movewindow, r
bind = $mainMod SHIFT, K, movewindow, u
bind = $mainMod SHIFT, J, movewindow, d

# Resize mode
bind = $mainMod, R, submap, resize
submap = resize
binde = , H, resizeactive, -20 0
binde = , L, resizeactive, 20 0
binde = , K, resizeactive, 0 -20
binde = , J, resizeactive, 0 20
bind = , escape, submap, reset
bind = , Return, submap, reset
submap = reset

# Workspace switching
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6

# Move to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6

# Workspace navigation
bind = $mainMod, Tab, workspace, e+1
bind = $mainMod SHIFT, Tab, workspace, e-1
bind = $mainMod, grave, workspace, previous

# Special workspace (scratchpad)
bind = $mainMod, S, togglespecialworkspace, magic
bind = $mainMod SHIFT, S, movetoworkspace, special:magic

# Screenshots
bind = , Print, exec, grim - | wl-copy
bind = SHIFT, Print, exec, grim -g "$(slurp)" - | wl-copy
bind = $mainMod, Print, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png

# Audio controls
binde = , XF86AudioRaiseVolume, exec, pamixer -i 5
binde = , XF86AudioLowerVolume, exec, pamixer -d 5
bind = , XF86AudioMute, exec, pamixer -t
bind = , XF86AudioMicMute, exec, pamixer --default-source -t

# Brightness controls
binde = , XF86MonBrightnessUp, exec, brightnessctl set +5%
binde = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# Player controls
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous

# Lock screen
bind = $mainMod SHIFT, L, exec, hyprlock

# Quick actions menu
bind = $mainMod, X, exec, ~/.config/hypr/scripts/power-menu.sh

# Mouse bindings
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# -----------------------------------------------------------------------------
# Autostart
# -----------------------------------------------------------------------------
exec-once = waybar
exec-once = mako
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = swww-daemon
exec-once = swww img ~/.config/hypr/wallpaper.png
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = hypridle
HYPRCONF

# Power menu script
mkdir -p ${USER_HOME}/.config/hypr/scripts

cat > ${USER_HOME}/.config/hypr/scripts/power-menu.sh << 'POWERMENU'
#!/bin/bash
# Simple power menu using fuzzel

options="Lock\nLogout\nSuspend\nReboot\nShutdown"

chosen=$(echo -e "$options" | fuzzel --dmenu -p "Power: ")

case "$chosen" in
    "Lock") hyprlock ;;
    "Logout") hyprctl dispatch exit ;;
    "Suspend") systemctl suspend ;;
    "Reboot") systemctl reboot ;;
    "Shutdown") systemctl poweroff ;;
esac
POWERMENU
chmod +x ${USER_HOME}/.config/hypr/scripts/power-menu.sh

# Create a simple wallpaper
convert -size 1280x720 \
    -define gradient:direction=south \
    gradient:'#1a1b26'-'#24283b' \
    ${USER_HOME}/.config/hypr/wallpaper.png 2>/dev/null || \
    echo "Install imagemagick to generate wallpaper, or add your own"

# Set ownership
chown -R ${USERNAME}:${USERNAME} ${USER_HOME}/.config

log "=============================================="
log "Hyprland installation complete!"
log ""
log "To start Hyprland, login as '${USERNAME}' and run:"
log "  Hyprland"
log ""
log "Or add to ~/.bash_profile for auto-start:"
log "  if [ -z \"\$WAYLAND_DISPLAY\" ] && [ \"\$XDG_VTNR\" -eq 1 ]; then"
log "      exec Hyprland"
log "  fi"
log ""
log "Next: Run ./04-setup-environment.sh"
log "=============================================="
