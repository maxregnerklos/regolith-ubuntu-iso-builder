#!/bin/bash

set -e

# Define variables
ISO_NAME="mrrexos-$(date +%Y%m%d)"
ISO_DIR="iso"
ISO_FILE="${ISO_DIR}/${ISO_NAME}.iso"
WORK_DIR="work"
ROOTFS_DIR="${WORK_DIR}/rootfs"
BOOTSTRAP_SCRIPT="bootstrap.sh"
CUSTOM_SCRIPT="custom.sh"
CUSTOM_FILES_DIR="custom"
CUSTOM_FILES_TAR="custom.tar.gz"
APT_PROXY="http://apt-cacher-ng:3142"
MIRROR_URL="http://ftp.us.debian.org/debian"
ARCH="amd64"
SUITE="bullseye"
EXTRA_PACKAGES="vim,htop,tree"

# Create ISO directory
mkdir -p "${ISO_DIR}"

# Create work directory
mkdir -p "${WORK_DIR}"

# Create root filesystem directory
mkdir -p "${ROOTFS_DIR}"

# Download bootstrap script
wget "https://raw.githubusercontent.com/debuerreotype/docker-debian-artifacts/dist-${SUITE}/buster/${ARCH}/rootfs.tar.xz" -O "${WORK_DIR}/rootfs.tar.xz"
wget "https://raw.githubusercontent.com/debuerreotype/docker-debian-artifacts/dist-${SUITE}/buster/${ARCH}/bootstrap.sh" -O "${WORK_DIR}/${BOOTSTRAP_SCRIPT}"
chmod +x "${WORK_DIR}/${BOOTSTRAP_SCRIPT}"

# Run bootstrap script
sudo "${WORK_DIR}/${BOOTSTRAP_SCRIPT}" "${ROOTFS_DIR}" "${APT_PROXY}" "${MIRROR_URL}" "${SUITE}" "${ARCH}"

# Copy custom files to root filesystem
if [ -d "${CUSTOM_FILES_DIR}" ]; then
  tar -czf "${WORK_DIR}/${CUSTOM_FILES_TAR}" -C "${CUSTOM_FILES_DIR}" .
  sudo tar -xzf "${WORK_DIR}/${CUSTOM_FILES_TAR}" -C "${ROOTFS_DIR}"
fi

# Copy custom script to root filesystem
if [ -f "${CUSTOM_SCRIPT}" ]; then
  sudo cp "${CUSTOM_SCRIPT}" "${ROOTFS_DIR}/root"
  sudo chroot "${ROOTFS_DIR}" /bin/bash -c "chmod +x /root/${CUSTOM_SCRIPT} && /root/${CUSTOM_SCRIPT}"
fi

# Install extra packages
if [ -n "${EXTRA_PACKAGES}" ]; then
  sudo chroot "${ROOTFS_DIR}" /bin/bash -c "apt-get update && apt-get install -y ${EXTRA_PACKAGES}"
fi

# Create ISO
sudo xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid "${ISO_NAME}" -output "${ISO_FILE}" -graft-points \
  "${ROOTFS_DIR}"=/ \
  "${WORK_DIR}/${BOOTSTRAP_SCRIPT}"="/${BOOTSTRAP_SCRIPT}" \
  "${WORK_DIR}/${CUSTOM_FILES_TAR}"="/${CUSTOM_FILES_TAR}" \
  "${CUSTOM_SCRIPT}"="/root/${CUSTOM_SCRIPT}"

# Clean up
sudo rm -rf "${WORK_DIR}"

echo "ISO created: ${ISO_FILE}"
