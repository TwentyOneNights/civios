# CiviOS

Mein Gaming- und Alltagssystem auf Basis von **Garuda Linux** mit eigenem Design: Tiefschwarz, Anthrazit und warmes Gelb.

Version 0.3.0

## Was CiviOS ist

CiviOS ist **Garuda Linux mit einer eigenen Schicht obendrauf**. Unter der Haube arbeiten Arch Linux und die Garuda-Werkzeuge (Kernel `linux-zen`, Chaotic-AUR, automatische Btrfs-Snapshots, Gaming-Pakete). CiviOS ersetzt das Aussehen und bringt ein eigenes Systemwerkzeug mit.

| Bereich | Kommt von | CiviOS-eigen |
|---|---|---|
| Kernel, Treiber, Pakete | Arch Linux, Garuda, Chaotic-AUR | |
| Gaming (Steam, Wine, Proton, Lutris, GameMode) | Garuda Gaming Edition | `civios compat`, `civios doctor` |
| Updates und Snapshots | `garuda-update`, snapper, grub-btrfs | `civios update`, `civios snapshots`, `civios rollback` |
| Desktop | KDE Plasma 6 | Global Theme, Farbschemas, Layout, Hintergrund, Logo, Konsole, Anmeldebildschirm |
| Installer | Calamares (Garuda) | Live-Benutzer `civios` |

## Das Design

- **Farben:** Tiefschwarz `#141415`, Anthrazit `#1C1C1E`, Akzent warmes Gelb `#F2C055`
- **Heller Modus:** Farbschema „CiviOS Hell“ in den Systemeinstellungen
- **Schriften:** Inter für die Oberfläche, JetBrains Mono für Terminal und Code
- **Layout:** schlanke Leiste oben (Launcher, Fenstermenü, Uhr mittig, Systembereich), schwebendes Dock unten, das Fenstern ausweicht
- **Hintergrund:** reproduzierbar erzeugt mit `tools/make-wallpaper.py`
- **Terminal:** eigenes Konsole-Farbschema und Profil
- **Bootmenü:** eigenes GRUB-Theme mit goldenem Auswahlbalken (bei `install.sh` optional)
- **Name im Live-ISO:** Bootmenü und Installer zeigen „CiviOS“

## Installation

### Weg 1: Auf ein bestehendes Garuda (empfohlen für den Anfang)

1. [Garuda Linux](https://garudalinux.org) installieren, am besten die **Dr460nized Gaming**-Edition. Secure Boot im BIOS ausschalten, Garuda unterstützt es nicht offiziell.
2. Im Terminal:
   ```bash
   git clone https://github.com/TwentyOneNights/civios.git
   cd civios
   sudo ./install.sh
   civios theme apply
   ```
3. Das Skript fragt, ob auch das Bootmenü das CiviOS-Design bekommen soll.
4. Einmal ab- und wieder anmelden.

Rückgängig machen: `sudo ./install.sh --uninstall`. Überschriebene Dateien werden vorher nach `/var/backups/civios/` gesichert und beim Entfernen zurückgespielt.

### Weg 2: Eigenes CiviOS-ISO

Auf GitHub unter **Actions → CiviOS ISO bauen → Run workflow**. Nach 30 bis 90 Minuten liegt das ISO als Download im Workflow-Lauf. Mit [Ventoy](https://www.ventoy.net) oder dem KDE ISO Image Writer auf einen USB-Stick schreiben.

Lokal auf einem Linux-Rechner mit Docker:
```bash
sudo docker run --rm --privileged -v "$PWD":/work -w /work archlinux:latest bash iso/build-iso.sh
```

## CiviOS Center

Die eigene Systemsteuerung, zu finden im Dock und im Startmenü (`civios-center`):

- **Übersicht:** CiviOS-Version, Basis, Kernel, Prozessor, Arbeitsspeicher, Grafik, Secure Boot, Snapshots, Updates
- **Gaming:** Systemcheck (Vulkan, GameMode, MangoHud, Steam, Multilib, Chaotic-AUR, Snapshots) und Anti-Cheat-Suche
- **Updates:** Aktualisieren mit einem Klick, letzte Snapshots, Anleitung zur Wiederherstellung mit Btrfs Assistant
- **Apps:** Empfohlene Programme auswählen und installieren
- **Design:** Dunkel oder hell, Layout wiederherstellen

Aktionen mit Administratorrechten laufen sichtbar im Terminal. So siehst du immer, was passiert.

## Befehle

| Befehl | Was er macht |
|---|---|
| `civios status` | Version, Basis, Kernel, Secure Boot, Grafikkarte, Snapshots, offene Updates |
| `civios update` | Aktualisiert mit `garuda-update`, vorher entsteht automatisch ein Snapshot |
| `civios snapshots` | Zeigt die letzten Btrfs-Snapshots |
| `civios rollback` | Erklärt die Wiederherstellung und öffnet Btrfs Assistant |
| `civios compat <Spiel>` | Anti-Cheat-Status aus AreWeAntiCheatYet. Blockierte Spiele werden klar als blockiert angezeigt |
| `civios doctor` | Prüft Vulkan, GameMode, MangoHud, Steam, Multilib, Chaotic-AUR, Snapshots |
| `civios apps [Paket ...]` | Installiert optionale Programme aus `apps.list`, nur nach Bestätigung |
| `civios theme light` / `dark` | Wechselt zwischen hellem und dunklem Farbschema |
| `civios theme apply` | Wendet das CiviOS-Design neu an |

## Projektstruktur

```
civios/
├── install.sh                       CiviOS auf bestehendes Garuda installieren
├── overlay/                         Wird 1:1 ins System kopiert
│   ├── etc/xdg/kdeglobals           Standard-Design für alle Konten
│   ├── etc/xdg/autostart/           Design beim ersten Anmelden anwenden
│   ├── etc/sddm.conf.d/             Anmeldebildschirm
│   ├── etc/civios-release           Versionsinfo
│   └── usr/
│       ├── bin/civios               Systemwerkzeug
│       ├── bin/civios-firstrun
│       ├── bin/civios-center        Grafische Systemsteuerung (PySide6)
│       ├── lib/civios/civios_core.py  Gemeinsame Logik
│       └── share/
│           ├── plasma/look-and-feel/org.civios.desktop/   Global Theme + Layout
│           ├── color-schemes/       CiviOS, CiviOS Hell
│           ├── wallpapers/CiviOS/
│           ├── konsole/             Terminal-Design
│           ├── icons/               CiviOS-Logo
│           └── civios/apps.list
├── iso/
│   ├── build-iso.sh                 ISO mit garuda-tools bauen
│   ├── Packages-CiviOS              Zusätzliche Pakete im ISO
│   └── Packages-Remove              Garuda-Designpakete, die CiviOS ersetzt
├── tools/make-wallpaper.py
└── .github/workflows/
    ├── check.yml                    Prüft jeden Push
    └── iso.yml                      Baut das ISO
```

## Ehrlicher Stand

**Getestet:** `install.sh` (Installieren, erneut Installieren, Entfernen mit Wiederherstellung), alle `civios`-Befehle mit nachgebildeten Garuda-Werkzeugen, `civios compat` gegen die echte Datenbank, Syntax aller Skripte mit shellcheck, Layout-Skript und JSON-Dateien.

**Noch nicht getestet:** Ein echter Plasma-Desktop mit dem Theme und der ISO-Build. Beides kann ich in meiner Arbeitsumgebung nicht ausführen. Der ISO-Build nutzt die offiziellen Garuda-Werkzeuge, deren öffentliche Doku teilweise veraltet ist. Beim ersten Lauf auf GitHub sind deshalb Korrekturen wahrscheinlich. Das Skript gibt bei Fehlern genau aus, was fehlt.

**Bekannte Grenzen:**
- Secure Boot wird von Garuda nicht offiziell unterstützt.
- Die Grafiken im Installer (Calamares) stammen noch von Garuda.
- `/etc/os-release` bleibt Garuda, weil Garuda-Werkzeuge darauf prüfen. CiviOS steht in `/etc/civios-release`.
- Abgerundete Fensterecken gibt es in Plasma nicht ab Werk. Dafür braucht es einen zusätzlichen KWin-Effekt (geplant).
- Spiele mit Kernel-Anti-Cheat oder Linux-Sperre (z. B. Valorant, Fortnite) laufen nicht. CiviOS umgeht das nicht.

## Nächste Schritte

1. Ersten ISO-Build auf GitHub laufen lassen und Fehler beheben
2. Theme auf echter Hardware prüfen und Feinschliff (Abstände, Dock-Grösse, Transparenz)
3. Abgerundete Fenster und eigene Fensterdekoration
4. Eigenes Calamares- und GRUB-Branding
5. CiviOS Center erweitern (Treiber, Energieprofile, Hardware-Temperaturen)

## Lizenz

MIT für alle CiviOS-eigenen Dateien. Garuda Linux, KDE und alle Pakete stehen unter ihren eigenen Lizenzen.
