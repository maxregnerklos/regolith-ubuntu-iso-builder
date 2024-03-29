#!/bin/bash
# Concept OS build script based on Ubuntu 25.04

set -e                  # exit on error
set -o pipefail         # exit on pipeline error
set -u                  # treat unset variable as error

# Set script directory
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Define commands
COMMANDS=(setup_host install_pkg customize_image finish_up)

# Help function
function help() {
    echo -e "This script builds a concept OS based on Ubuntu 25.04"
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

    echo "ConceptOS" > /etc/hostname

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

    # Customization steps go here
}

# Function to perform finishing tasks
function finish_up() {
    echo "=====> finish_up"

    truncate -s 0 /etc/machine-id

    rm /sbin/initctl
    dpkg-divert --rename --remove /sbin/initctl

    rm -rf /tmp/* ~/.bash_history
}

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
