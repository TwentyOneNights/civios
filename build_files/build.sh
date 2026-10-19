#!/usr/bin/env bash
# CiviOS Build-Skript. Läuft einmal während des Container-Builds.
set -euxo pipefail

CIVIOS_VERSION="${CIVIOS_VERSION:-0.1.0}"

### 1. Systemdateien übernehmen (Branding, Design, Werkzeuge)
cp -avf /ctx/system_files/. /
chmod 0755 /usr/bin/civios

### 2. Branding in os-release
# ID und ID_LIKE bleiben unverändert, weil Bazzite- und Fedora-Werkzeuge
# darauf prüfen. Geändert wird nur, was Nutzer sehen.
OSR=/usr/lib/os-release
sed -i \
  -e "s/^NAME=.*/NAME=\"CiviOS\"/" \
  -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"CiviOS ${CIVIOS_VERSION}\"/" \
  -e "s|^HOME_URL=.*|HOME_URL=\"https://github.com/REPO_OWNER/civios\"|" \
  -e "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"https://github.com/REPO_OWNER/civios/issues\"|" \
  "$OSR"
grep -q '^CIVIOS_VERSION=' "$OSR" || echo "CIVIOS_VERSION=\"${CIVIOS_VERSION}\"" >> "$OSR"

# Universal-Blue-Metadaten auf CiviOS umstellen, falls vorhanden.
INFO=/usr/share/ublue-os/image-info.json
if [[ -f "$INFO" ]] && command -v jq >/dev/null; then
  tmp=$(mktemp)
  jq --arg v "$CIVIOS_VERSION" \
     '."image-name"="civios" | ."image-vendor"="REPO_OWNER" | ."civios-version"=$v' \
     "$INFO" > "$tmp" && mv "$tmp" "$INFO"
fi

### 3. Zusätzliche Pakete
# Bazzite bringt Steam, Gamescope, GameMode, MangoHud, Lutris-Unterstützung,
# Mesa und Treiber bereits mit. Hier kommt nur dazu, was CiviOS selbst braucht.
# --skip-unavailable verhindert, dass ein umbenanntes Paket den ganzen
# Build bricht. Fehlende Pakete stehen im Build-Log.
dnf5 install -y --skip-unavailable \
  rsms-inter-fonts \
  jetbrains-mono-fonts-all \
  vulkan-tools \
  jq

### 4. Dienste
systemctl enable podman.socket

### 5. Aufräumen
dnf5 clean all
rm -rf /var/lib/dnf
