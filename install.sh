#!/usr/bin/env bash
# CiviOS auf einem bestehenden Garuda-Linux-System installieren.
#
#   sudo ./install.sh              installieren oder aktualisieren
#   sudo ./install.sh --uninstall  alles entfernen und Sicherungen zurückspielen
#
# Überschriebene Systemdateien werden vorher nach /var/backups/civios/ gesichert.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/overlay"
MANIFEST=/usr/share/civios/installed-files
BACKUP=/var/backups/civios
DEPS=(inter-font ttf-jetbrains-mono vulkan-tools pacman-contrib pyside6)

say()  { printf '\033[38;2;242;192;85m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mHinweis:\033[0m %s\n' "$*"; }
die()  { printf '\033[31mFehler:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Bitte mit sudo starten: sudo ./install.sh"
command -v pacman >/dev/null || die "pacman fehlt. CiviOS braucht Garuda Linux (oder Arch)."

uninstall() {
    [[ -f $MANIFEST ]] || die "CiviOS ist nicht installiert (kein $MANIFEST)."
    say "Entferne CiviOS-Dateien"
    while IFS= read -r f; do
        if [[ -f "$BACKUP$f" ]]; then
            cp -a "$BACKUP$f" "$f"
        else
            rm -f "$f"
        fi
    done < "$MANIFEST"
    regrub=0
    grep -qxF /etc/default/grub "$MANIFEST" && regrub=1
    rm -f "$MANIFEST"
    rm -rf "$BACKUP"
    if [[ $regrub -eq 1 ]] && command -v grub-mkconfig >/dev/null; then
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
    say "Fertig. Design in den Systemeinstellungen wieder umstellen, falls gewünscht."
    exit 0
}
[[ ${1:-} == "--uninstall" ]] && uninstall

[[ -d $SRC ]] || die "Ordner overlay/ nicht gefunden. Skript aus dem CiviOS-Ordner starten."

if ! grep -qi '^ID=garuda' /etc/os-release; then
    warn "Das ist kein Garuda Linux. CiviOS ist nur auf Garuda getestet."
    read -rp "Trotzdem fortfahren? [j/N] " a
    [[ $a =~ ^[jJyY] ]] || exit 1
fi

say "Installiere Abhängigkeiten: ${DEPS[*]}"
pacman -S --needed --noconfirm "${DEPS[@]}"

say "Sichere Dateien, die überschrieben werden"
mkdir -p "$BACKUP"
new_manifest=$(mktemp)
while IFS= read -r -d '' rel; do
    rel=${rel#./}
    dest="/$rel"
    # Nur sichern, wenn die Datei nicht schon von CiviOS stammt.
    if [[ -f $dest && ! -f "$BACKUP$dest" ]] && ! grep -qxF "$dest" "$MANIFEST" 2>/dev/null; then
        mkdir -p "$(dirname "$BACKUP$dest")"
        cp -a "$dest" "$BACKUP$dest"
    fi
    echo "$dest" >> "$new_manifest"
done < <(cd "$SRC" && find . -type f -print0)

say "Kopiere CiviOS-Dateien"
cp -r --no-preserve=ownership "$SRC"/. /
chmod 755 /usr/bin/civios /usr/bin/civios-firstrun /usr/bin/civios-center
install -Dm644 "$new_manifest" "$MANIFEST"
rm -f "$new_manifest"

# SDDM: /etc/sddm.conf hat Vorrang vor sddm.conf.d. Garuda setzt dort oft ein eigenes Theme.
if [[ -f /etc/sddm.conf ]] && grep -q '^Current=' /etc/sddm.conf; then
    [[ -f $BACKUP/etc/sddm.conf ]] || { mkdir -p "$BACKUP/etc"; cp -a /etc/sddm.conf "$BACKUP/etc/sddm.conf"; }
    sed -i 's/^Current=.*/Current=breeze/' /etc/sddm.conf
    grep -qxF /etc/sddm.conf "$MANIFEST" || echo /etc/sddm.conf >> "$MANIFEST"
fi

# Bootmenü-Design (optional, ändert /etc/default/grub)
if [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null; then
    read -rp "Bootmenü (GRUB) ebenfalls im CiviOS-Design? [j/N] " g
    if [[ $g =~ ^[jJyY] ]]; then
        [[ -f $BACKUP/etc/default/grub ]] || { mkdir -p "$BACKUP/etc/default"; cp -a /etc/default/grub "$BACKUP/etc/default/grub"; }
        if grep -q '^#\?GRUB_THEME=' /etc/default/grub; then
            sed -i 's|^#\?GRUB_THEME=.*|GRUB_THEME="/usr/share/grub/themes/civios/theme.txt"|' /etc/default/grub
        else
            echo 'GRUB_THEME="/usr/share/grub/themes/civios/theme.txt"' >> /etc/default/grub
        fi
        grep -qxF /etc/default/grub "$MANIFEST" || echo /etc/default/grub >> "$MANIFEST"
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
fi

command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -f /usr/share/icons/hicolor || true

say "CiviOS ist installiert."
echo
echo "  Design jetzt anwenden (als normaler Benutzer, nicht mit sudo):"
echo "      civios theme apply"
echo "  Neue Benutzerkonten bekommen das Design automatisch beim ersten Anmelden."
echo "  Zustand prüfen:   civios doctor"
echo "  Entfernen:        sudo ./install.sh --uninstall"
