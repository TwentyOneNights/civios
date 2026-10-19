# CiviOS

Gaming- und Desktop-Linux auf Basis von Bazzite (Fedora Atomic, KDE Plasma, bootc).
Stand: Meilenstein 1, Version 0.1.0.

## 1. Ehrliche Einordnung vorab

CiviOS ist in diesem Stand ein **eigenes, signiertes Systemimage auf Basis von Bazzite** mit eigenem Branding, eigenem Farbschema und einem eigenen Systemwerkzeug (`civios`). Der grösste Teil der Gaming-Integration (Kernel-Patches, Mesa, Steam, Gamescope, HDR/VRR, Treiber, Controller-Unterstützung) kommt von Bazzite und Fedora. Das ist Absicht: Diese Arbeit selbst nachzubauen wäre langsamer, unsicherer und schlechter gewartet.

Was im Prompt verlangt wird (eigenes Control Center, App Center, Installer, Apple-ähnliche Oberfläche, Benchmarks gegen Windows), ist die Arbeit eines Teams über Monate. Dieses Repository liefert das Fundament, auf dem das aufbaut, und markiert klar, was schon funktioniert und was noch nicht.

## 2. Wahl der Basis

| Kriterium | Bazzite (gewählt) | Fedora Kinoite pur | Arch / CachyOS | Nobara |
|---|---|---|---|---|
| Gaming ab Werk | Sehr gut (Steam, Gamescope, HDR/VRR, Handheld-Patches) | Muss alles selbst integriert werden | Gut, Pakete aktuell | Gut |
| Atomare Updates und Rollback | Ja (bootc) | Ja (bootc/rpm-ostree) | Nein, nur über Btrfs-Snapshots nachrüstbar | Nein |
| NVIDIA | Eigene Images mit vorgebauten, signierten Modulen | akmods selbst bauen und signieren | DKMS, bricht gelegentlich bei Kernel-Updates | RPM-Pakete |
| Eigenes Derivat bauen | Containerfile + CI, offiziell vorgesehen | Containerfile + CI | archiso, eigene Repos nötig | Kein offizieller Weg |
| Wartungsaufwand für ein kleines Team | Niedrig | Mittel | Hoch | Hoch |
| Abhängigkeit von Dritten | Hoch (Universal Blue) | Niedrig | Niedrig | Hoch (Einzelperson) |

**Begründung:** Für ein kleines Team ist der Wartungsaufwand das entscheidende Kriterium. Ein Image-basiertes System mit automatischem Rollback verhindert die häufigste Ursache kaputter Gaming-Systeme (ein fehlgeschlagenes Update). Bazzite löst die schwierigsten Gaming-Probleme bereits und ist offiziell dafür gedacht, dass man eigene Images darauf aufbaut.

**Fallback:** Sollte Universal Blue eingestellt werden, lässt sich der `FROM`-Eintrag auf `quay.io/fedora/fedora-bootc` oder Fedora Kinoite umstellen. Dann müssen Gaming-Pakete und NVIDIA-Module selbst übernommen werden. Die übrige Projektstruktur bleibt gleich.

**Kernel:** Es wird kein eigener Kernel entwickelt. CiviOS nutzt den Kernel aus dem Bazzite-Image (Fedora-Kernel mit Gaming-Patches). Fedora 45 ist Stand 19.10.2026 noch nicht veröffentlicht, der erste Termin wurde verschoben. CiviOS folgt dem `stable`-Kanal von Bazzite und wechselt automatisch, sobald Bazzite umstellt.

## 3. Systemarchitektur

```
 ┌─────────────────────────────────────────────────────────────┐
 │  Ebene 5  CiviOS-Werkzeuge                                  │
 │           civios CLI (heute) · Control Center · App Center  │
 ├─────────────────────────────────────────────────────────────┤
 │  Ebene 4  CiviOS Design                                     │
 │           Farbschema, Schriften, KDE-Standards (heute)      │
 │           Plasma-Theme, Icons, SDDM, Plymouth (später)      │
 ├─────────────────────────────────────────────────────────────┤
 │  Ebene 3  Anwendungen                                       │
 │           Flatpak (Flathub) · Distrobox · Podman            │
 ├─────────────────────────────────────────────────────────────┤
 │  Ebene 2  Bazzite                                           │
 │           Steam, Gamescope, GameMode, MangoHud, Mesa,       │
 │           NVIDIA-Module, HDR/VRR, Controller, ujust         │
 ├─────────────────────────────────────────────────────────────┤
 │  Ebene 1  Fedora Atomic (bootc)                             │
 │           Kernel, systemd, KDE Plasma, SELinux, firewalld   │
 └─────────────────────────────────────────────────────────────┘

 Lieferkette:
 GitHub-Repo ──► GitHub Actions ──► OCI-Image (ghcr.io, cosign-signiert)
                                        │
                     ┌──────────────────┼───────────────────┐
                     ▼                  ▼                   ▼
          bootc-image-builder    installierte Systeme    bootc switch
          (ISO / qcow2)          holen Updates atomar    (von Bazzite aus)
```

**Update-Modell:** Jedes Update ist ein komplettes, getestetes Systemimage. Es wird im Hintergrund geladen und beim Neustart aktiv. Die vorherige Version bleibt im Bootmenü und lässt sich mit `civios rollback` wieder aktivieren. `/usr` ist schreibgeschützt, `/etc` wird beim Update zusammengeführt, `/var` und `/home` bleiben unangetastet.

**Software:** Grafische Anwendungen kommen als Flatpak (Sandbox, Berechtigungen sichtbar). Entwicklungswerkzeuge laufen in Distrobox- oder Podman-Containern. Systempakete werden nur im Image selbst ergänzt, nicht auf dem laufenden System. Das vermeidet Paketkonflikte grundsätzlich.

## 4. Projektstruktur

```
civios/
├── Containerfile                 Image-Definition (Basis + Build-Schritt + Lint)
├── build_files/
│   └── build.sh                  Branding, Pakete, Dienste
├── system_files/                 Wird 1:1 ins Image kopiert
│   ├── etc/xdg/kdeglobals        KDE-Standards für neue Konten
│   └── usr/
│       ├── bin/civios            Systemwerkzeug (Python, nur Standardbibliothek)
│       └── share/
│           ├── civios/flatpaks.list
│           └── color-schemes/CiviOS.colors
├── disk_config/
│   ├── iso.toml                  Anaconda-Installer-ISO
│   └── disk.toml                 qcow2/raw für VMs
├── image-template.env            Name, Registry, Beschreibung
├── Justfile                      Lokale Build-Befehle
└── .github/workflows/
    ├── build.yml                 Image bauen, signieren, veröffentlichen (täglich)
    └── build-disk.yml            ISO und VM-Image erzeugen
```

Grundgerüst, Justfile und Workflows stammen aus dem offiziellen `ublue-os/image-template` (Apache-2.0). Alles unter `build_files/`, `system_files/` sowie `Containerfile`, `disk_config/iso.toml` und diese README sind CiviOS-spezifisch.

## 5. Das Werkzeug `civios`

| Befehl | Funktion |
|---|---|
| `civios status` | Version, Kernel, Secure Boot, GPU und Treiber, aktives Image, vorgemerktes Update, Rollback-Ziel |
| `civios update` | `bootc upgrade`, aktiv nach Neustart |
| `civios rollback` | Prüft, ob eine vorherige Version existiert, fragt nach und merkt sie vor |
| `civios compat <Spiel>` | Anti-Cheat-Status aus der AreWeAntiCheatYet-Datenbank, 24 h Cache, offline nutzbar |
| `civios doctor` | Prüft Vulkan, GameMode, MangoHud, Steam, Flathub |
| `civios setup-apps` | Zeigt die Flatpak-Liste und installiert erst nach Bestätigung |

`civios compat` zeigt blockierte Spiele offen als **Blockiert** an (zum Beispiel Valorant, Fortnite, Apex Legends) und umgeht keinen Anti-Cheat. Getestet gegen die Live-Datenbank am 19.10.2026.

## 6. Bauen

### Weg A: GitHub (empfohlen, kein Linux-Rechner nötig)

1. Neues Repository **mit dem Namen `civios`** anlegen und diese Dateien hochladen. Der Name muss stimmen, weil der ISO-Workflow den Repo-Namen als Image-Namen verwendet.
2. Platzhalter ersetzen (GitHub-Name in Kleinbuchstaben):
   ```bash
   grep -rl REPO_OWNER . | xargs sed -i 's/REPO_OWNER/deinname/g'
   ```
3. Signaturschlüssel erzeugen und den öffentlichen Teil einchecken:
   ```bash
   cosign generate-key-pair      # leeres Passwort verwenden
   git add cosign.pub && git commit -m "Signaturschlüssel" && git push
   ```
   Inhalt von `cosign.key` als Repository-Secret `SIGNING_SECRET` hinterlegen. `cosign.key` niemals einchecken.
4. Unter *Settings → Actions → General* Lese- und Schreibrechte für Workflows erlauben.
5. Der Workflow *Build container image* läuft beim Push und danach täglich. Ergebnis: `ghcr.io/deinname/civios:latest`. Das Paket auf GitHub anschliessend auf *public* stellen, sonst kann der Installer es nicht laden.
6. *Actions → Build disk images → Run workflow*, Plattform `amd64`. Das ISO liegt danach als Artefakt im Workflow-Lauf.

### Weg B: Lokal (Fedora, Bazzite oder anderes Linux mit Podman)

```bash
sudo dnf install -y podman just          # auf Bazzite bereits vorhanden
just build                               # baut localhost/civios:latest
just build-iso                           # ISO nach output/
just build-vm && just run-vm             # qcow2 bauen und in QEMU starten
```

NVIDIA-Variante lokal:
```bash
podman build --build-arg BASE_IMAGE=ghcr.io/ublue-os/bazzite-nvidia-open:stable -t localhost/civios-nvidia .
```

### Bestehendes Bazzite-System umstellen (schnellster Test)

```bash
sudo bootc switch ghcr.io/deinname/civios:latest
systemctl reboot
civios status
```

## 7. Meilenstein 1: Abnahmekriterien

Meilenstein 1 gilt als erreicht, wenn alle Punkte nachweisbar sind:

- [ ] `build.yml` läuft grün, inklusive `bootc container lint`
- [ ] `cosign verify --key cosign.pub ghcr.io/deinname/civios:latest` ist erfolgreich
- [ ] `build-disk.yml` erzeugt ein ISO
- [ ] Das ISO bootet in QEMU/UEFI und auf echter Hardware in den Installer
- [ ] Installation mit LUKS-Verschlüsselung läuft durch
- [ ] Nach dem Start: `cat /etc/os-release` zeigt CiviOS, `civios status` zeigt das CiviOS-Image
- [ ] Neue Benutzer erhalten das CiviOS-Farbschema
- [ ] `civios doctor` meldet OK auf AMD- und NVIDIA-Testsystem
- [ ] Update und `civios rollback` funktionieren einmal vollständig hin und zurück

**Wichtig:** Ich konnte das ISO in meiner Umgebung nicht bauen, weil dort der Zugriff auf ghcr.io und quay.io gesperrt ist. Geprüft habe ich die Syntax von `build.sh` und `civios`, alle Befehle von `civios` gegen echte Daten sowie das Parsen von `bootc status`. Der erste echte Image-Build ist deshalb der erste Test, und kleinere Korrekturen danach sind wahrscheinlich.

## 8. Technische Risiken

| Risiko | Auswirkung | Gegenmassnahme |
|---|---|---|
| **Secure Boot** | Bazzite-Kernel und NVIDIA-Module sind mit dem Universal-Blue-Schlüssel signiert, nicht von Microsoft. Mit aktivem Secure Boot muss dieser Schlüssel einmalig per MOK registriert werden. | Ablauf aus der Bazzite-Doku übernehmen und im Installer erklären. Eigener Schlüssel erst, wenn CiviOS eigene Module baut. |
| **Anti-Cheat** | Spiele mit Kernel-Anti-Cheat (Vanguard u. a.) oder Linux-Blockade laufen nicht. Das ist eine Herstellerentscheidung und technisch nicht lösbar, ohne Regeln zu brechen. | Transparente Anzeige über `civios compat`, keine Umgehung. |
| **Abhängigkeit von Universal Blue** | Ändert Bazzite Pfade, Pakete oder Kanäle, kann der Build brechen. | Täglicher CI-Build bemerkt Brüche sofort. Fallback auf `fedora-bootc` dokumentiert. |
| **ISO braucht Netz** | Der Installer zieht das endgültige Image nach der Installation aus der Registry. | Später ein Offline-ISO mit eingebettetem Image (Bazzite nutzt dafür ein eigenes Werkzeug). |
| **TPM** | LUKS-Entsperrung per TPM ist nicht Standard und kann bei Firmware-Updates zum Passwort-Prompt führen. | Opt-in über `systemd-cryptenroll`, Passwort bleibt immer als Rückfallebene. |
| **Design-Umfang** | Eine wirklich eigenständige Oberfläche (Fensterdekoration, Plasma-Theme, Icons, abgerundete Fenster, Dock) ist der grösste Einzelaufwand. | Schrittweise: zuerst Farben und Schriften, dann Plasma-Theme, dann eigene Komponenten. |
| **Markenrechte** | „Bazzite“ und Fedora-Marken dürfen nicht für ein fremdes Produkt verwendet werden. | Sichtbares Branding vollständig ersetzen, Herkunft in der Doku korrekt nennen. |
| **Windows-Vergleich** | Linux ist je nach Spiel schneller, gleich oder langsamer. Pauschale Aussagen wären falsch. | Messungen mit fester Methodik (siehe Phase 8), Ergebnisse auch dann veröffentlichen, wenn Windows vorne liegt. |

## 9. Roadmap

| Phase | Inhalt | Stand |
|---|---|---|
| 1 | Basis, Architektur, signiertes Image, ISO | **Code fertig, erster Build ausstehend** |
| 2 | Installer: Branding in Anaconda, Dual-Boot-Test, Offline-ISO | offen |
| 3 | Design: Plasma Global Theme, Fensterdekoration, SDDM, Plymouth, Hintergründe, heller Modus | Farbschema und Schriften fertig |
| 4 | Control Center: Qt/QML-Anwendung als Oberfläche über `civios` (gleiche Logik, grafisch) | CLI-Kern fertig |
| 5 | Gaming: NVIDIA-Variante in CI, Kompatibilitätsanzeige in Steam-nahen Oberflächen, Profile | `civios compat` fertig |
| 6 | App Center: KDE Discover anpassen statt neu bauen, kuratierte Kategorien | Flatpak-Liste fertig |
| 7 | Sicherheit: Signaturprüfung erzwingen (`policy.json`), Firewall-Profile, TPM-Opt-in | Image-Signierung fertig |
| 8 | Tests: openQA oder QEMU-Bootstest in CI, Benchmark-Methodik mit MangoHud-Logs (Durchschnitt, 1 % Lows, Frametime-Varianz) | offen |
| 9 | Release: Versionierung, Kanäle `stable`/`testing`, Changelog | Tageskanal läuft über CI |
