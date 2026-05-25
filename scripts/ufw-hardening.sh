#!/usr/bin/env bash
# UFW workstation hardening ruleset.
#
# Apply:
#   # 1. Edit the LAN value below to match your subnet.
#   # 2. Make sure you are physically at the keyboard or have a non-SSH
#   #    way back in, in case you mis-set a rule.
#   sudo bash ufw-hardening.sh
#
# Reverse:
#   sudo ufw --force reset
#   sudo systemctl disable --now ufw
#
# See chapter 11 of the Arch repo for the reasoning behind each rule.

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "this script must run as root (try: sudo bash $0)" >&2
  exit 1
fi

# --- Subnets ---
# Set LAN to your local subnet. Typical home router defaults are
# 192.168.0.0/24 or 192.168.1.0/24. Find yours with:
#   ip -4 addr show | grep "inet 192" -m1
LAN="192.168.1.0/24"

# Tailscale's standard CGNAT range. Only change if you use a different
# mesh VPN; the value below covers any Tailscale-issued address.
TAILNET="100.64.0.0/10"

# --- Reset to a known clean state ---
ufw --force reset

# --- Defaults ---
ufw default deny incoming
ufw default allow outgoing
# Routed = traffic forwarded through this host (Docker, VPN clients,
# KVM bridges). Leave allow-routed so Docker's container networking
# works. Container *ingress from outside* is governed by the
# DOCKER-USER chain we configure in /etc/ufw/after.rules. See the
# ufw-docker-after.rules.snippet in this directory.
ufw default allow routed

# --- Loopback (explicit, harmless) ---
ufw allow in on lo

# --- SSH: LAN only, rate-limited ---
ufw limit in from "$LAN" to any port 22 proto tcp comment 'SSH from LAN, rate-limited'

# --- XRDP (Remote Desktop): LAN + Tailscale only ---
# Public internet is NEVER allowed; only your tailnet devices and LAN
# clients. Delete these two lines if you do not run XRDP.
ufw allow in from "$LAN" to any port 3389 proto tcp comment 'XRDP from LAN'
ufw allow in from "$TAILNET" to any port 3389 proto tcp comment 'XRDP from Tailscale'

# --- KDE Connect: LAN only ---
# Delete if you do not use KDE Connect.
ufw allow in from "$LAN" to any port 1714:1764 proto tcp comment 'KDE Connect TCP from LAN'
ufw allow in from "$LAN" to any port 1714:1764 proto udp comment 'KDE Connect UDP from LAN'

# --- mDNS (Avahi): LAN only ---
# Delete if you do not use network device discovery.
ufw allow in from "$LAN" to any port 5353 proto udp comment 'mDNS from LAN'

# --- Tailscale ---
# Trust traffic that's already on the tailnet. tailscaled handles
# WireGuard authentication before it ever touches our filter rules.
ufw allow in on tailscale0 comment 'Trust traffic from tailnet interface'

# --- Logging ---
# 'low' logs blocked incoming only. Bumps logs slightly but is
# invaluable when you're wondering "why can't I reach X?".
ufw logging low

# --- Enable ---
ufw --force enable

echo
echo "=== Resulting ruleset ==="
ufw status verbose
