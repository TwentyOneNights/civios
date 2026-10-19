"""Gemeinsame Logik für das civios-Kommandozeilenwerkzeug und das CiviOS Center.

Alle Funktionen geben Daten zurück und drucken nichts. Sie werfen keine
Ausnahmen, wenn ein Werkzeug fehlt, sondern liefern None oder leere Werte.
Nur Python-Standardbibliothek.
"""
import json
import os
import shutil
import subprocess
import time
import urllib.request
from pathlib import Path

VERSION_FILE = Path("/etc/civios-release")
APPS_LIST = Path("/usr/share/civios/apps.list")
if not APPS_LIST.exists():  # Quellbaum: overlay/usr/lib/civios -> overlay/usr/share/civios
    APPS_LIST = Path(__file__).resolve().parents[2] / "share/civios/apps.list"
AWACY_URL = ("https://raw.githubusercontent.com/AreWeAntiCheatYet/"
             "AreWeAntiCheatYet/HEAD/games.json")
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "civios"
CACHE_MAX_AGE = 24 * 3600

GPU_VENDORS = {"0x1002": "AMD", "0x10de": "NVIDIA", "0x8086": "Intel"}

# Status aus AreWeAntiCheatYet: (Bezeichnung, Erklärung, Stufe)
# Stufe: good, warn, info, bad
ANTICHEAT_STATUS = {
    "Supported": ("Unterstützt", "Läuft offiziell mit Anti-Cheat unter Linux/Proton.", "good"),
    "Running": ("Läuft", "Startet, Anti-Cheat ist aber nicht offiziell freigegeben. Multiplayer kann eingeschränkt sein.", "warn"),
    "Planned": ("Geplant", "Der Hersteller hat Unterstützung angekündigt, sie ist aber noch nicht da.", "info"),
    "Broken": ("Defekt", "Startet nicht oder Multiplayer funktioniert nicht.", "bad"),
    "Denied": ("Blockiert", "Der Hersteller blockiert Linux absichtlich. CiviOS umgeht das nicht.", "bad"),
}


def run(cmd, timeout=30):
    """Führt einen Befehl aus und gibt (rc, stdout) zurück, ohne zu werfen."""
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, PermissionError):
        return 127, ""


def read_kv(path):
    data = {}
    try:
        for line in Path(path).read_text().splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                data[k.strip()] = v.strip().strip('"')
    except OSError:
        pass
    return data


# ---------- Systeminformationen ----------

def civios_version():
    rel = read_kv(VERSION_FILE)
    return rel.get("CIVIOS_NAME", "CiviOS"), rel.get("CIVIOS_VERSION", "")


def base_system():
    return read_kv("/etc/os-release").get("PRETTY_NAME", "unbekannt")


def kernel():
    return os.uname().release


def gpus():
    found = []
    for card in sorted(Path("/sys/class/drm").glob("card[0-9]*")):
        if "-" in card.name:
            continue
        try:
            vendor = (card / "device/vendor").read_text().strip()
            driver = Path(os.readlink(card / "device/driver")).name
        except OSError:
            continue
        found.append((GPU_VENDORS.get(vendor, vendor), driver))
    return found


def secure_boot():
    rc, out = run(["mokutil", "--sb-state"])
    if rc == 0 and out:
        return "aktiv" if "enabled" in out.lower() else "inaktiv"
    efivars = Path("/sys/firmware/efi/efivars")
    if not efivars.exists():
        return "kein UEFI"
    for f in efivars.glob("SecureBoot-*"):
        try:
            return "aktiv" if f.read_bytes()[-1] == 1 else "inaktiv"
        except OSError:
            break
    return "unbekannt"


def memory_gib():
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            if line.startswith("MemTotal:"):
                return round(int(line.split()[1]) / 1024 / 1024, 1)
    except OSError:
        pass
    return None


def cpu_name():
    try:
        for line in Path("/proc/cpuinfo").read_text().splitlines():
            if line.startswith("model name"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return None


# ---------- Snapshots und Updates ----------

def snapshots():
    """Root-Snapshots als Liste von Dicts, oder None, wenn snapper fehlt."""
    rc, out = run(["snapper", "-c", "root", "--jsonout", "list"])
    if rc != 0 or not out:
        return None
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return None
    items = data.get("root", []) if isinstance(data, dict) else data
    result = []
    for s in items:
        if s.get("number", 0) == 0:
            continue
        result.append({
            "number": s.get("number"),
            "date": s.get("date") or "",
            "type": s.get("type") or "",
            "description": s.get("description") or "",
            "important": (s.get("userdata") or {}).get("important") == "yes",
        })
    return result


def pending_updates():
    """Anzahl offener Updates, oder None, wenn checkupdates fehlt oder scheitert."""
    if not shutil.which("checkupdates"):
        return None
    rc, out = run(["checkupdates"], timeout=90)
    if rc == 2:
        return 0
    return len(out.splitlines()) if rc == 0 else None


# ---------- Gaming ----------

def doctor_checks():
    """Liste von (Name, ok, Detail)."""
    checks = []
    rc, out = run(["vulkaninfo", "--summary"])
    devs = [l.split("=", 1)[1].strip() for l in out.splitlines() if "deviceName" in l]
    checks.append(("Vulkan", rc == 0 and bool(devs),
                   ", ".join(devs) if devs else "vulkaninfo fehlt oder kein Vulkan-Gerät"))
    rc, out = run(["gamemoded", "-s"])
    checks.append(("GameMode", rc == 0, out or "gamemoded nicht gefunden"))
    checks.append(("MangoHud", shutil.which("mangohud") is not None,
                   "Leistungsanzeige im Spiel"))
    checks.append(("Steam", shutil.which("steam") is not None, "Steam-Client"))
    _, out = run(["pacman-conf", "--repo-list"])
    repos = out.split()
    checks.append(("Multilib", "multilib" in repos, "32-Bit-Bibliotheken für Steam und Wine"))
    checks.append(("Chaotic-AUR", "chaotic-aur" in repos, "Fertige AUR-Pakete"))
    rc, _ = run(["snapper", "-c", "root", "get-config"])
    checks.append(("Snapshots", rc == 0, "Automatische Sicherung vor Updates" if rc == 0
                   else "snapper-Konfiguration nicht gefunden oder nicht lesbar"))
    return checks


def load_anticheat_db(refresh=False):
    """Lädt die AreWeAntiCheatYet-Datenbank mit 24-Stunden-Cache.

    Gibt (Liste, Hinweis) zurück. Liste ist None, wenn weder online noch Cache.
    """
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache = CACHE_DIR / "awacy-games.json"
    fresh = cache.exists() and time.time() - cache.stat().st_mtime < CACHE_MAX_AGE
    note = ""
    if refresh or not fresh:
        try:
            req = urllib.request.Request(AWACY_URL, headers={"User-Agent": "civios"})
            with urllib.request.urlopen(req, timeout=15) as r:
                data = r.read()
            json.loads(data)
            cache.write_bytes(data)
        except Exception as e:  # noqa: BLE001
            if not cache.exists():
                return None, f"Datenbank nicht erreichbar ({e}) und kein Cache vorhanden."
            note = "Online-Aktualisierung fehlgeschlagen, es wird der Cache verwendet."
    try:
        return json.loads(cache.read_text()), note
    except (OSError, json.JSONDecodeError) as e:
        return None, f"Cache unlesbar: {e}"


def search_games(db, query, limit=10):
    q = query.casefold().strip()
    if not q:
        return []
    hits = [g for g in db if q in g.get("name", "").casefold()]
    hits.sort(key=lambda g: (g["name"].casefold() != q, len(g["name"])))
    result = []
    for g in hits[:limit]:
        status = g.get("status", "?")
        label, text, level = ANTICHEAT_STATUS.get(status, (status, "", "info"))
        notes = [n[0] for n in (g.get("notes") or []) if isinstance(n, list) and n]
        result.append({
            "name": g.get("name", "?"),
            "status": label,
            "explanation": text,
            "level": level,
            "native": bool(g.get("native")),
            "anticheats": g.get("anticheats") or [],
            "notes": notes[:3],
        })
    return result


# ---------- Anwendungen ----------

def app_catalog():
    """Liste von Dicts: name, description, installed, available."""
    if not APPS_LIST.exists():
        return []
    apps = []
    for line in APPS_LIST.read_text().splitlines():
        parts = line.split("#", 1)
        name = parts[0].strip()
        if not name:
            continue
        apps.append({
            "name": name,
            "description": parts[1].strip() if len(parts) > 1 else "",
            "installed": run(["pacman", "-Qq", name])[0] == 0,
            "available": None,  # erst bei Bedarf prüfen, pacman -Si ist langsam
        })
    return apps


def package_available(name):
    return run(["pacman", "-Si", name])[0] == 0
