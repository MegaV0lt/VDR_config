#!/usr/bin/env bash

# Script to update VDR and its plugins to a specific version on yaVDR

# VERSION=261001

# Get version to be installed from command line argument
if [[ -z "$1" ]] ; then
  echo "Usage: $0 <version>"
  exit 1
fi

NEW_VDR_VERSION="$1"  # Version to be installed

# Check if version is valid (eg. 2.6.6 or 2.6.7)
if ! [[ "$NEW_VDR_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
  echo "Invalid version specified. Only numbers with dots (eg. 2.8.3) are supported."
  exit 1
fi

# Get current vdr version number
CURRENT_VDR_VERSION="$(vdr --version |awk '{print $2}')"

# Print what will be done and wait for an keypress
echo "Current VDR version: ${CURRENT_VDR_VERSION}"
echo "New VDR version to be installed: ${NEW_VDR_VERSION}"
echo "This script will add a new PPA for version ${NEW_VDR_VERSION}, remove the old PPA for version ${CURRENT_VDR_VERSION}, and then update VDR and its plugins."
echo "Press any key to continue or Ctrl+C to abort..."
read -r -n 1 -s

# Check if the new PPA is already added
if ! grep -q "ppa:seahawk1986-hotmail/vdr-${NEW_VDR_VERSION}" /etc/apt/sources.list.d/vdr.list ; then
  echo "Adding new PPA for version ${NEW_VDR_VERSION}..."
  sudo add-apt-repository --enable-source "ppa:seahawk1986-hotmail/vdr-${NEW_VDR_VERSION}"
else
  echo "PPA for version ${NEW_VDR_VERSION} is already added."
fi
# Add new PPA and exit on error if the new PPA is not added successfully
echo "Adding new PPA for version ${NEW_VDR_VERSION}..."
if ! sudo add-apt-repository --enable-source "ppa:seahawk1986-hotmail/vdr-${NEW_VDR_VERSION}" ; then
  echo "Failed to add PPA for version ${NEW_VDR_VERSION}. Exiting."
  exit 1
fi

# Remove old PPA
echo "Removing old PPA for version ${CURRENT_VDR_VERSION}..."
sudo ppa-purge "ppa:seahawk1986-hotmail/vdr-${CURRENT_VDR_VERSION}"

# Check and install updates and restore modified configuration files
sudo /_config/sbin/SysUpdate.sh

# End
