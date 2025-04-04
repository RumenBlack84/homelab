#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

header_info() {
  clear
  cat <<"EOF"
    ____ _    ________   ____             __     ____           __        ____
   / __ \ |  / / ____/  / __ \____  _____/ /_   /  _/___  _____/ /_____ _/ / /
  / /_/ / | / / __/    / /_/ / __ \/ ___/ __/   / // __ \/ ___/ __/ __ `/ / /
 / ____/| |/ / /___   / ____/ /_/ (__  ) /_   _/ // / / (__  ) /_/ /_/ / / /
/_/     |___/_____/  /_/    \____/____/\__/  /___/_/ /_/____/\__/\__,_/_/_/

EOF
}

RD="\033[01;31m"
YW="\033[33m"
GN="\033[1;92m"
CL="\033[m"
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

set -euo pipefail
shopt -s inherit_errexit nullglob

msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

# Function to print usage
usage() {
  echo "Usage: $0 [-y] [-s] [-e] [-p] [-c] [-t] [-u] [-n] [-r]"
  echo "  -y    Run in non-interactive mode"
  echo "  -s    Correct Proxmox VE Sources"
  echo "  -e    Disable pve-enterprise repository"
  echo "  -p    Enable pve-no-subscription repository"
  echo "  -c    Correct ceph package repositories"
  echo "  -t    Add pvetest repository"
  echo "  -u    Update Proxmox VE"
  echo "  -n    Disable Subscription Nag"
  echo "  -r    Reboot Proxmox VE"
  exit 1
}

# Function to handle script arguments
handle_args() {
  while getopts ":ysecpctur" opt; do
    case $opt in
      y)
        non_interactive=true
        ;;
      s)
        correct_sources=true
        ;;
      e)
        disable_enterprise=true
        ;;
      p)
        enable_no_subscription=true
        ;;
      c)
        correct_ceph=true
        ;;
      t)
        add_pvetest=true
        ;;
      u)
        update_proxmox=true
        ;;
      n)
        remove_nag=true
        ;;		
      r)
        reboot_proxmox=true
        ;;
      \?)
        usage
        ;;
    esac
  done
}

start_routines() {
  header_info

  if [ "${correct_sources:-false}" = true ]; then
    msg_info "Correcting Proxmox VE Sources"
    cat <<EOF >/etc/apt/sources.list
deb http://deb.debian.org/debian bookworm main contrib
deb http://deb.debian.org/debian bookworm-updates main contrib
deb http://security.debian.org/debian-security bookworm-security main contrib
EOF
    echo 'APT::Get::Update::SourceListWarnings::NonFreeFirmware "false";' >/etc/apt/apt.conf.d/no-bookworm-firmware.conf
    msg_ok "Corrected Proxmox VE Sources"
  fi

  if [ "${disable_enterprise:-false}" = true ]; then
    msg_info "Disabling 'pve-enterprise' repository"
    cat <<EOF >/etc/apt/sources.list.d/pve-enterprise.list
# deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise
EOF
    msg_ok "Disabled 'pve-enterprise' repository"
  fi

  if [ "${enable_no_subscription:-false}" = true ]; then
    msg_info "Enabling 'pve-no-subscription' repository"
    cat <<EOF >/etc/apt/sources.list.d/pve-install-repo.list
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
    msg_ok "Enabled 'pve-no-subscription' repository"
  fi

  if [ "${correct_ceph:-false}" = true ]; then
    msg_info "Correcting 'ceph package repositories'"
    cat <<EOF >/etc/apt/sources.list.d/ceph.list
# deb https://enterprise.proxmox.com/debian/ceph-quincy bookworm enterprise
# deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription
# deb https://enterprise.proxmox.com/debian/ceph-reef bookworm enterprise
# deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription
EOF
    msg_ok "Corrected 'ceph package repositories'"
  fi

  if [ "${add_pvetest:-false}" = true ]; then
    msg_info "Adding 'pvetest' repository and set disabled"
    cat <<EOF >/etc/apt/sources.list.d/pvetest-for-beta.list
# deb http://download.proxmox.com/debian/pve bookworm pvetest
EOF
    msg_ok "Added 'pvetest' repository"
  fi

  if [ "${update_proxmox:-false}" = true ]; then
    msg_info "Updating Proxmox VE (Patience)"
    apt-get update &>/dev/null
    apt-get -y dist-upgrade &>/dev/null
    msg_ok "Updated Proxmox VE"
  fi
  
  if [ "${remove_nag:-false}" = true ]; then
    echo "DPkg::Post-Invoke { \"dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'; if [ \$? -eq 1 ]; then { echo 'Removing subscription nag from UI...'; sed -i '/.*data\.status.*{/{s/\!//;s/active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; }; fi\"; };" > /etc/apt/apt.conf.d/no-nag-script
    apt --reinstall install proxmox-widget-toolkit &>/dev/null
fi


  if [ "${reboot_proxmox:-false}" = true ]; then
    msg_info "Rebooting Proxmox VE"
    sleep 2
    msg_ok "Completed Post Install Routines"
    reboot
  fi
}

# Main script execution
non_interactive=false

handle_args "$@"

if [ "${non_interactive}" = false ]; then
  header_info
  echo -e "\nThis script will Perform Post Install Routines.\n"
  while true; do
    read -p "Start the Proxmox VE Post Install Script (y/n)?" yn
    case $yn in
      [Yy]*) break ;;
      [Nn]*) clear; exit ;;
      *) echo "Please answer yes or no." ;;
    esac
  done
fi

if ! pveversion | grep -Eq "pve-manager/8.[0-2]"; then
  msg_error "This version of Proxmox Virtual Environment is not supported"
  echo -e "Requires Proxmox Virtual Environment Version 8.0 or later."
  echo -e "Exiting..."
  sleep 2
  exit
fi

start_routines
