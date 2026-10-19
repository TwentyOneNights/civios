#!/usr/bin/env bash
# Baut das CiviOS-ISO mit den offiziellen Garuda-Werkzeugen (garuda-tools).
#
# Läuft als root in einem Arch-Linux-Container mit --privileged, zum Beispiel:
#   docker run --rm --privileged -v "$PWD":/work -w /work archlinux:latest bash iso/build-iso.sh
#
# Ablauf:
#   1. Arch-Container vorbereiten, Chaotic-AUR und Garuda-Repo einbinden
#   2. garuda-tools installieren und die offiziellen iso-profiles laden
#   3. Ein Garuda-Profil als Vorlage kopieren (Standard: dr460nized-gaming)
#   4. CiviOS-Pakete, Overlay und Einstellungen einspielen
#   5. buildiso ausführen und das ISO nach ./out kopieren
set -euo pipefail

BASE_PROFILE="${CIVIOS_BASE_PROFILE:-dr460nized-gaming}"
PROFILE=civios
WORK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$WORK/out"
CHAOTIC_KEY=3056513887B78AEB
CHAOTIC_CDN=https://cdn-mirror.chaotic.cx/chaotic-aur

step() { printf '\n\033[1;33m### %s\033[0m\n' "$*"; }
die()  { printf '\033[31mFehler:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Muss als root laufen."
command -v pacman >/dev/null || die "Muss in einem Arch-Linux-Container laufen."

step "1/5 Paketquellen einrichten"
pacman-key --init
pacman-key --populate archlinux
grep -q '^\[multilib\]' /etc/pacman.conf || printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
pacman -Syu --noconfirm --needed git

# Chaotic-AUR nach offizieller Anleitung
pacman-key --recv-key "$CHAOTIC_KEY" --keyserver keyserver.ubuntu.com
pacman-key --lsign-key "$CHAOTIC_KEY"
pacman -U --noconfirm "$CHAOTIC_CDN/chaotic-keyring.pkg.tar.zst" "$CHAOTIC_CDN/chaotic-mirrorlist.pkg.tar.zst"
if ! grep -q '^\[garuda\]' /etc/pacman.conf; then
    printf '\n[garuda]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' >> /etc/pacman.conf
fi
if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
    printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' >> /etc/pacman.conf
fi
pacman -Sy

step "2/5 garuda-tools installieren und Profile laden"
installed=""
for pkg in garuda-tools-iso-git garuda-tools-iso; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        pacman -S --noconfirm --needed "$pkg" && installed=$pkg && break
    fi
done
[[ -n $installed ]] || die "garuda-tools nicht in den Paketquellen gefunden. Verfügbar: $(pacman -Ssq garuda-tools | tr '\n' ' ')"
echo "Installiert: $installed"

mkdir -p /root/.config/garuda-tools
cat > /root/.config/garuda-tools/garuda-tools.conf <<'EOF'
dist_branding="CIVIOS"
EOF

buildiso -i
REPO_INFO=$(find / -xdev -name repo_info -path '*iso-profiles*' 2>/dev/null | head -n1)
[[ -n $REPO_INFO ]] || die "iso-profiles wurden nicht geladen (repo_info fehlt)."
RUN_DIR=$(dirname "$REPO_INFO")
echo "Profile in: $RUN_DIR"

step "3/5 Vorlage '$BASE_PROFILE' kopieren"
SRC_PROFILE=$(find "$RUN_DIR" -mindepth 2 -maxdepth 2 -type d -name "$BASE_PROFILE" | head -n1)
if [[ -z $SRC_PROFILE ]]; then
    echo "Verfügbare Profile:"
    find "$RUN_DIR" -mindepth 2 -maxdepth 2 -type d -printf '  %P\n' | sort
    die "Profil '$BASE_PROFILE' nicht gefunden. Mit CIVIOS_BASE_PROFILE=<name> ein anderes wählen."
fi
DEST="$(dirname "$SRC_PROFILE")/$PROFILE"
rm -rf "$DEST"
cp -a "$SRC_PROFILE" "$DEST"

step "4/5 CiviOS einspielen"
PKG_FILE="$DEST/Packages-Desktop"
[[ -f $PKG_FILE ]] || die "Packages-Desktop fehlt in $DEST. Inhalt: $(ls "$DEST")"

# Pakete entfernen, die ein eigenes Design mitbringen und CiviOS überschreiben würden.
while IFS= read -r pkg; do
    pkg=${pkg%%#*}; pkg=${pkg// /}
    [[ -z $pkg ]] && continue
    if grep -qxE "\s*$pkg\s*" "$PKG_FILE"; then
        sed -i -E "/^\s*$pkg\s*$/d" "$PKG_FILE"
        echo "Entfernt: $pkg"
    fi
done < "$WORK/iso/Packages-Remove"

# CiviOS-Pakete ergänzen.
{ echo; echo "# CiviOS"; grep -vE '^\s*(#|$)' "$WORK/iso/Packages-CiviOS"; } >> "$PKG_FILE"

# Overlay: wird nach der Paketinstallation ins Desktop-Image kopiert.
mkdir -p "$DEST/desktop-overlay"
cp -a "$WORK/overlay/." "$DEST/desktop-overlay/"
chmod 755 "$DEST/desktop-overlay/usr/bin/civios" "$DEST/desktop-overlay/usr/bin/civios-firstrun"

# Live-Sitzung umbenennen. Spätere Zuweisungen in profile.conf gewinnen.
cat >> "$DEST/profile.conf" <<'EOF'

# CiviOS
hostname="civios"
username="civios"
password="civios"
EOF

echo "--- Packages-Desktop (Auszug) ---"
tail -n 25 "$PKG_FILE"

step "5/5 ISO bauen (dauert 20 bis 60 Minuten)"
buildiso -p "$PROFILE"

mkdir -p "$OUT"
ISO=$(find /var/cache/garuda-tools -name '*.iso' -newer "$REPO_INFO" | head -n1)
[[ -n $ISO ]] || die "Kein ISO gefunden. Logs unter /var/log/garuda-tools prüfen."
cp -v "$ISO" "$OUT/"
( cd "$OUT" && sha256sum ./*.iso > SHA256SUMS )
echo
echo "Fertig: $OUT/$(basename "$ISO")"
