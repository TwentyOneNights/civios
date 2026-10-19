#!/usr/bin/env bash
# Prüft ein fertiges CiviOS-ISO, ohne es zu booten.
#   sudo iso/verify-iso.sh out/civios.iso
# Braucht: squashfs-tools (unsquashfs), mount mit Loop-Unterstützung.
set -euo pipefail

ISO=${1:?Pfad zum ISO angeben}
MNT=$(mktemp -d)
FAIL=0
ok()   { printf '  OK     %s\n' "$*"; }
bad()  { printf '  FEHLT  %s\n' "$*"; FAIL=1; }
cleanup() { umount "$MNT" 2>/dev/null || true; rmdir "$MNT"; }
trap cleanup EXIT

mount -o loop,ro "$ISO" "$MNT"
echo "ISO: $ISO ($(du -h "$ISO" | cut -f1))"

DESKTOP_SFS=$(find "$MNT" -name desktopfs.sfs | head -n1)
ROOT_SFS=$(find "$MNT" -name rootfs.sfs | head -n1)
[[ -n $DESKTOP_SFS ]] && ok "desktopfs.sfs vorhanden" || bad "desktopfs.sfs"
[[ -n $ROOT_SFS ]] && ok "rootfs.sfs vorhanden" || bad "rootfs.sfs"

if [[ -n $DESKTOP_SFS ]]; then
    LIST=$(mktemp)
    unsquashfs -l "$DESKTOP_SFS" > "$LIST"
    for f in usr/bin/civios usr/bin/civios-center usr/bin/civios-firstrun \
             usr/lib/civios/civios_core.py \
             usr/share/plasma/look-and-feel/org.civios.desktop/metadata.json \
             usr/share/plasma/look-and-feel/org.civios.desktop/contents/layouts/org.kde.plasma.desktop-layout.js \
             usr/share/color-schemes/CiviOS.colors usr/share/color-schemes/CiviOSLight.colors \
             usr/share/wallpapers/CiviOS/contents/images/3840x2160.png \
             usr/share/konsole/CiviOS.profile usr/share/applications/civios-center.desktop \
             usr/share/grub/themes/civios/theme.txt \
             etc/xdg/kdeglobals etc/xdg/autostart/civios-firstrun.desktop etc/civios-release; do
        grep -q "/$f\$" "$LIST" && ok "$f" || bad "$f"
    done
    # Pakete, die CiviOS braucht, erkennt man an ihren Dateien.
    grep -q "/usr/lib/python3[^/]*/site-packages/PySide6/__init__.py$" "$LIST" \
        && ok "PySide6 (für CiviOS Center)" || bad "PySide6 (Paket pyside6)"
    grep -qi "/usr/share/fonts/.*inter" "$LIST" && ok "Schrift Inter" || bad "Schrift Inter"
    rm -f "$LIST"
fi

if grep -rqs "CiviOS" "$MNT/boot/grub"; then
    ok "Bootmenü nennt CiviOS"
else
    bad "Bootmenü nennt CiviOS"
fi

echo
if [[ $FAIL -eq 0 ]]; then
    echo "Alle Prüfungen bestanden."
else
    echo "Mindestens eine Prüfung ist fehlgeschlagen."
fi
exit $FAIL
