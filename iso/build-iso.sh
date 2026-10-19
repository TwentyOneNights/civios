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

# garuda-tools liest Angaben über den Build-Rechner und nutzt sie im ISO:
#  - ID aus os-release: Ordnername auf dem ISO, Calamares-Branding, Live-GRUB-Theme.
#    Muss "garuda" sein, weil die Garuda-Pakete genau diese Namen mitbringen.
#  - DISTRIB_ID aus lsb-release: Name im Bootmenü und im Installer ("CiviOS Linux").
# Beides betrifft nur den Build-Container, nicht das installierte System.
sed -i 's/^ID=.*/ID=garuda/' /usr/lib/os-release
cat > /etc/lsb-release <<'EOF'
DISTRIB_ID="CiviOS"
DISTRIB_RELEASE="Rolling"
DISTRIB_CODENAME="CiviOS"
DISTRIB_DESCRIPTION="CiviOS Build"
EOF

mkdir -p /root/.config/garuda-tools
cat > /root/.config/garuda-tools/garuda-tools.conf <<'EOF'
dist_branding="CIVIOS"
EOF

buildiso -i
RUN_DIR=/var/cache/garuda-tools/iso-profiles
if [[ ! -d $RUN_DIR/garuda && ! -d $RUN_DIR/community ]]; then
    die "iso-profiles nicht gefunden. Inhalt: $(ls -la /var/cache/garuda-tools 2>&1)"
fi
echo "Profile in: $RUN_DIR"
ls "$RUN_DIR" "$RUN_DIR/garuda" 2>/dev/null || true
# garuda-tools erkennt den Profilordner an einer repo_info-Datei.
[[ -f $RUN_DIR/repo_info ]] || touch "$RUN_DIR/repo_info"
REPO_INFO=$RUN_DIR/repo_info

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
chmod 755 "$DEST"/desktop-overlay/usr/bin/civios*

# Live-Overlay: wird ins Live-System kopiert. Ersetzt unter anderem das
# Bootmenü-Design des ISO durch das CiviOS-Theme.
mkdir -p "$DEST/live-overlay"
cp -a "$WORK/iso/live-overlay/." "$DEST/live-overlay/"

# Installer-Starter umbenennen ("Install Garuda Linux" -> "Install CiviOS").
# Die Originaldatei kommt aus dem Garuda-Paket, nur Name und Beschreibung ändern sich.
CAL=usr/share/applications/calamares.desktop
pacman -Fy >/dev/null 2>&1 || true
OWNER=$(pacman -Fq "$CAL" 2>/dev/null | head -n1 || true)
if [[ -n $OWNER ]] && pacman -Sw --noconfirm "$OWNER" >/dev/null 2>&1; then
    PKG=$(find /var/cache/pacman/pkg -name "${OWNER##*/}-[0-9]*.pkg.tar.zst" | sort | tail -n1)
    mkdir -p "$DEST/live-overlay/usr/share/applications"
    if [[ -n $PKG ]] && bsdtar -xOf "$PKG" "$CAL" > "$DEST/live-overlay/$CAL" 2>/dev/null; then
        sed -i -E '/^(Name|GenericName|Comment)(\[[^]]*\])?=/ s/Garuda Linux/CiviOS/g; /^(Name|GenericName|Comment)(\[[^]]*\])?=/ s/Garuda/CiviOS/g' "$DEST/live-overlay/$CAL"
        echo "Installer-Starter angepasst (aus $OWNER):"
        grep -E '^(Name|Exec)=' "$DEST/live-overlay/$CAL" || true
    else
        rm -f "$DEST/live-overlay/$CAL"
        echo "Hinweis: calamares.desktop nicht im Paket gefunden, Name bleibt unverändert."
    fi
else
    echo "Hinweis: Besitzer von $CAL nicht ermittelbar, Name bleibt unverändert."
fi

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
echo "Initcpio-Dateien des Build-Rechners:"
ls /etc/initcpio /etc/initcpio/hooks /etc/initcpio/install 2>&1 | head -n 30 || true
buildiso -p "$PROFILE"

mkdir -p "$OUT"
ISO=$(find /var/cache/garuda-tools -name '*.iso' -newer "$REPO_INFO" | head -n1)
[[ -n $ISO ]] || die "Kein ISO gefunden. Logs unter /var/log/garuda-tools prüfen."
NAME="civios-$(date +%Y.%m.%d)-x86_64.iso"
cp -v "$ISO" "$OUT/$NAME"
( cd "$OUT" && sha256sum ./*.iso > SHA256SUMS )
echo
echo "Fertig: $OUT/$NAME"
