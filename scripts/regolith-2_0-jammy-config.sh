#!/bin/bash

# This script provides common customization options for the ISO
# 
# Usage: Copy this file to config.sh and make changes there.  Keep this file (default_config.sh) as-is
#   so that subsequent changes can be easily merged from upstream.  Keep all customiations in config.sh

# The brand name of the distribution
export TARGET_DISTRO_NAME="Regolith"

# The version of the distribution to be installed
export TARGET_DISTRO_VERSION="2.0.0"

# The version of Ubuntu to generate.  Successfully tested: bionic, cosmic, disco, eoan, jammy, groovy
# See https://wiki.ubuntu.com/DevelopmentCodeNames for details
export TARGET_UBUNTU_VERSION="jammy"

# The Ubuntu Mirror URL. It's better to change for faster download.
# More mirrors see: https://launchpad.net/ubuntu/+archivemirrors
export TARGET_UBUNTU_MIRROR="http://us.archive.ubuntu.com/ubuntu/"

# The packaged version of the Linux kernel to install on target image.
# See https://wiki.ubuntu.com/Kernel/LTSEnablementStack for details
export TARGET_KERNEL_PACKAGE="linux-generic"

# The file (no extension) of the ISO containing the generated disk image,
# the volume id, and the hostname of the live environment are set from this name.
export TARGET_NAME="${TARGET_DISTRO_NAME// /_}"

# The text label shown in GRUB for booting into the live environment
export GRUB_LIVEBOOT_LABEL="Try $TARGET_DISTRO_NAME"

# The text label shown in GRUB for starting installation
export GRUB_INSTALL_LABEL="Install $TARGET_DISTRO_NAME"

# A link to a web page containing release notes associated with the installation
# Selectable in the first page of the Ubiquity installer
export RELEASE_NOTES_URL="https://regolith-desktop.com/docs/reference/Releases/regolith-2.0-release-notes/"

# Name and version of distribution
export VERSIONED_DISTRO_NAME="$TARGET_DISTRO_NAME $TARGET_DISTRO_VERSION $TARGET_UBUNTU_VERSION"

# Packages to be removed from the target system after installation completes succesfully
export TARGET_PACKAGE_REMOVE="
    ubiquity \
    casper \
    discover \
    laptop-detect \
    os-prober \
"

# Package customisation function.  Update this function to customize packages
# present on the installed system.
function customize_image() {
    apt install -y gpg wget

    wget -qO - https://regolith-desktop.io/regolith.key | gpg --dearmor | sudo tee /usr/share/keyrings/regolith-archive-keyring.gpg
    echo deb "[arch=amd64 signed-by=/usr/share/keyrings/regolith-archive-keyring.gpg] https://regolith-desktop.io/testing-ubuntu-jammy-amd64 jammy main" | sudo tee /etc/apt/sources.list.d/regolith.list
    apt update

    apt-get purge -y \
        plymouth-theme-spinner \
        plymouth-theme-ubuntu-text

    # install graphics and desktop
    apt-get install -y \
    regolith-system-ubuntu
    plymouth-theme-regolith-logo \
    plymouth-themes

    # useful tools
    apt-get install -y \
    clamav-daemon \
    terminator \
    apt-transport-https \
    curl \
    vim \
    nano \
    memtest86+ \
    less

    # purge
    apt-get purge -y \
    transmission-gtk \
    transmission-common \
    gnome-mahjongg \
    gnome-mines \
    gnome-sudoku \
    aisleriot \
    hitori \
    ubuntu-session \
    ubuntu-desktop
}

# Used to version the configuration.  If breaking changes occur, manual
# updates to this file from the default may be necessary.
export CONFIG_FILE_VERSION="0.4"