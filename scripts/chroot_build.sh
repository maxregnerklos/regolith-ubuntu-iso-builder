#!/bin/bash
# HarmonyOS build script based on Ubuntu 25.04

set -e                  # exit on error
set -o pipefail         # exit on pipeline error
set -u                  # treat unset variable as error

# Set script directory
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Load configuration values
function load_config() {
    if [[ -f "$SCRIPT_DIR/config.sh" ]]; then 
        . "$SCRIPT_DIR/config.sh"
    elif [[ -f "$SCRIPT_DIR/default_config.sh" ]]; then
        . "$SCRIPT_DIR/default_config.sh"
    else
        >&2 echo "Unable to find default config file  $SCRIPT_DIR/default_config.sh, aborting."
        exit 1
    fi
}

# Define commands
COMMANDS=(setup_host install_pkg customize_image finish_up)

# Help function
function help() {
    echo -e "This script builds HarmonyOS based on Ubuntu 25.04"
    echo -e
    echo -e "Supported commands: ${COMMANDS[*]}"
    echo -e
    echo -e "Syntax: $0 [start_cmd] [-] [end_cmd]"
    echo -e "\trun from start_cmd to end_cmd"
    echo -e "\tif start_cmd is omitted, start from the first command"
    echo -e "\tif end_cmd is omitted, end with the last command"
    echo -e "\tenter a single cmd to run the specific command"
    echo -e "\tenter '-' as the only argument to run all commands"
    echo -e
    exit 0
}

# Function to find index of a command
function find_index() {
    local ret;
    local i;
    for ((i=0; i<${#COMMANDS[*]}; i++)); do
        if [ "${COMMANDS[i]}" == "$1" ]; then
            index=$i;
            return;
        fi
    done
    help "Command not found : $1"
}

# Function to check if the script is run as root
function check_host() {
    if [ $(id -u) -ne 0 ]; then
        echo "This script should be run as 'root'"
        exit 1
    fi

    export HOME=/root
    export LC_ALL=C
}

# Function to set up the host environment
function setup_host() {
    echo "=====> running setup_host ..."

    cat <<EOF > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse

deb http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse

deb http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
EOF

    echo "HarmonyOS" > /etc/hostname

    apt-get update
    apt-get install -y systemd-sysv dbus

    dbus-uuidgen > /etc/machine-id
    ln -fs /etc/machine-id /var/lib/dbus/machine-id

    dpkg-divert --local --rename --add /sbin/initctl
    ln -s /bin/true /sbin/initctl
}

# Function to install necessary packages
function install_pkg() {
    echo "=====> running install_pkg ..."

    apt-get -y upgrade

    apt-get install -y \
    sudo \
    ubuntu-standard \
    casper \
    discover \
    laptop-detect \
    os-prober \
    network-manager \
    resolvconf \
    net-tools \
    wireless-tools \
    wpagui \
    grub-common \
    grub-gfxpayload-lists \
    grub-pc \
    grub-pc-bin \
    grub2-common \
    locales

    apt-get install -y --no-install-recommends linux-image-generic-hwe-20.04

    apt-get install -y \
    ubiquity \
    ubiquity-casper \
    ubiquity-frontend-gtk \
    ubiquity-slideshow-ubuntu \
    ubiquity-ubuntu-artwork

    dpkg-reconfigure locales
    dpkg-reconfigure systemd-resolved

    cat <<EOF > /etc/NetworkManager/NetworkManager.conf
[main]
plugins=ifupdown,keyfile
dns=dnsmasq

[ifupdown]
managed=false
EOF

    dpkg-reconfigure network-manager

    apt-get autoremove -y
    apt-get clean -y
}

# Function to customize the image
function customize_image() {
    echo "=====> running customize_image ..."

    apt update

    apt install -y \
        gpg \
        wget \
        software-properties-common

    wget -qO - https://harmonyos.org/harmony.key | gpg --dearmor | sudo tee /usr/share/keyrings/harmonyos-archive-keyring.gpg
    echo -e "\ndeb [arch=amd64 signed-by=/usr/share/keyrings/harmonyos-archive-keyring.gpg] https://harmonyos.org/release-ubuntu-jammy-amd64 jammy main" | sudo tee /etc/apt/sources.list.d/harmonyos.list

    # Fix firefox ~ https://ubuntuhandbook.org/index.php/2022/04/install-firefox-deb-ubuntu-22-04/
    apt-get purge -y firefox
    add-apt-repository -y ppa:mozillateam/ppa
    echo "Package: firefox*" > /etc/apt/preferences.d/mozillateamppa
    echo "Pin: release o=LP-PPA-mozillateam" >> /etc/apt/preferences.d/mozillateamppa
    echo "Pin-Priority: 501" >> /etc/apt/preferences.d/mozillateamppa
    apt update

    # install graphics and desktop
    apt-get install -y \
        apt-transport-https \
        apturl \
        apturl-common \
        avahi-autoipd \
        dmz-cursor-theme \
        eog \
        file-roller \
        firefox \
        gnome-disk-utility \
        gnome-font-viewer \
        gnome-power-manager \
        gnome-screenshot \
        less \
        libnotify-bin \
        memtest86+ \
        metacity \
        nautilus \
        network-manager-openvpn \
        network-manager-openvpn-gnome \
        network-manager-pptp-gnome \
        plymouth-theme-harmony-logo \
        policykit-desktop-privileges \
        harmonyos-compositor-picom-glx \
        harmonyos-i3-swap-focus \
        harmonyos-system-ubuntu \
        rfkill \
        rsyslog \
        shim-signed \
        software-properties-gtk \
        ssl-cert \
        syslinux \
        syslinux-common \
        thermald \
        ubiquity-slideshow-harmonyos \
        ubuntu-release-upgrader-gtk \
        update-notifier \
        vim \
        wbritish \
        xcursor-themes \
        xdg-user-dirs-gtk \
        zip

    # purge
    apt-get purge -y \
        aisleriot \
        evolution-data-server \
        evolution-data-server-common \
        gdm3 \
        gnome-mahjongg \
        gnome-mines \
        gnome-sudoku \
        lightdm-gtk-greeter \
        hitori \
        plymouth-theme-spinner \
        plymouth-theme-ubuntu-text \
        transmission-common \
        transmission-gtk \
        ubuntu-desktop \
        ubuntu-session \
        snapd

    apt-get autoremove -y

    # Set wallpaper for installer
    cp /usr/share/backgrounds/pia21972.png /usr/share/backgrounds/warty-final-ubuntu.png

    # Specify HarmonyOS session for autologin
    echo "[SeatDefaults]" >> /etc/lightdm/lightdm.conf.d/10_harmonyos.conf
    echo "user-session=harmonyos" >> /etc/lightdm/lightdm.conf.d/10_harmonyos.conf
}

# Function to perform finishing tasks
function finish_up() {
    echo "=====> finish_up"

    truncate -s 0 /etc/machine-id

    rm /sbin/initctl
    dpkg-divert --rename --remove /sbin/initctl

    rm -rf /tmp/* ~/.bash_history
}

# Main execution starts here
load_config
check_host

if [[ $# == 0 || $# > 3 ]]; then
    help
fi

dash_flag=false
start_index=0
end_index=${#COMMANDS[*]}
for ii in "$@"; do
    if [[ $ii == "-" ]]; then
        dash_flag=true
        continue
    fi
    find_index $ii
    if [[ $dash_flag == false ]]; then
        start_index=$index
    else
        end_index=$(($index+1))
    fi
done

if [[ $dash_flag == false ]]; then
    end_index=$(($start_index + 1))
fi

for ((ii=$start_index; ii<$end_index; ii++)); do
    ${COMMANDS[ii]}
done

echo "$0 - Initial build is done!"
