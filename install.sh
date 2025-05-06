#!/bin/bash
set -e
TARGET_USER=$(logname)

if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root!"
    exit 1
fi

echo "[1/13] Updating system..."
pacman -Syu --noconfirm

echo "[2/13] Installing base packages..."
pacman -S --noconfirm --needed git base-devel zsh wget curl unzip xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils alsa-utils pipewire pipewire-pulse wireplumber networkmanager bluez bluez-utils grim slurp wl-clipboard swaybg swappy polkit-gnome qt5-wayland qt6-wayland qt5ct qt6ct noto-fonts noto-fonts-emoji ttf-jetbrains-mono ttf-font-awesome firefox thunar thunar-archive-plugin file-roller kitty foot gnome-disk-utility pavucontrol gparted htop btop neofetch

echo "[3/13] Enabling system services..."
systemctl enable NetworkManager
systemctl enable bluetooth

echo "[4/13] Installing yay (AUR helper)..."
if ! command -v yay &> /dev/null; then
    cd /opt
    git clone https://aur.archlinux.org/yay.git
    chown -R $TARGET_USER:$TARGET_USER yay
    cd yay
    sudo -u $TARGET_USER makepkg -si --noconfirm
fi

echo "[5/13] Installing Hyprland and AUR apps..."
sudo -u $TARGET_USER yay -S --noconfirm hyprland xdg-desktop-portal-hyprland sddm-git greetd tuigreet wofi waybar rofi-lbonn-wayland hyprpaper dunst nwg-look nwg-displays ttf-iosevka zsh-autosuggestions zsh-syntax-highlighting oh-my-zsh-git pamac-aur

echo "[6/13] ZSH setup..."
usermod --shell /bin/zsh $TARGET_USER
ZSH_DIR="/home/$TARGET_USER/.oh-my-zsh"
sudo -u $TARGET_USER git clone https://github.com/ohmyzsh/ohmyzsh.git $ZSH_DIR
cat > /home/$TARGET_USER/.zshrc <<EOF
export ZSH="$ZSH_DIR"
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source \$ZSH/oh-my-zsh.sh
EOF
chown $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.zshrc

echo "[7/13] Greetd setup..."
cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --cmd Hyprland"
user = "$TARGET_USER"
EOF
systemctl enable greetd

echo "[8/13] Setting environment variables..."
cat >> /etc/environment <<EOF
XDG_CURRENT_DESKTOP=Hyprland
XDG_SESSION_TYPE=wayland
QT_QPA_PLATFORM=wayland
EOF

echo "[9/13] Wallpaper setup..."
mkdir -p /home/$TARGET_USER/Pictures/wallpapers
cp wallpapers/hyprland-default.jpg /home/$TARGET_USER/Pictures/wallpapers/
chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER/Pictures

echo "[10/13] Copying Hyprland and Waybar configs..."
mkdir -p /home/$TARGET_USER/.config/hypr /home/$TARGET_USER/.config/waybar
cp configs/hypr/hyprland.conf /home/$TARGET_USER/.config/hypr/
cp configs/waybar/* /home/$TARGET_USER/.config/waybar/
chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.config

echo "[11/13] Session setup..."
echo "exec Hyprland" > /home/$TARGET_USER/.xinitrc
chown $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.xinitrc

echo "[12/13] Checking for VirtualBox environment..."
if grep -q "VirtualBox" /sys/class/dmi/id/product_name; then
    echo "Installing VirtualBox guest additions..."
    pacman -S --noconfirm virtualbox-guest-utils
    systemctl enable vboxservice
    systemctl start vboxservice
fi

echo "[13/13] Setup complete! Reboot to start Hyprland."
read -p "Reboot now? (y/N): " ans
[[ "$ans" =~ ^[Yy]$ ]] && reboot
