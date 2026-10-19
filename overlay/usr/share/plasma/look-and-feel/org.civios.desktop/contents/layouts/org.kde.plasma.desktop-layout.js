// CiviOS Desktop-Layout (Plasma 6)
// Oben: schlanke Systemleiste mit Launcher, Fenstermenü, Uhr in der Mitte
// und Systembereich. Unten: schwebendes Dock, nur so breit wie nötig.
// Läuft, wenn das Global Theme mit "Desktop-Layout übernehmen" angewendet wird.

var wallpaperPath = "file:///usr/share/wallpapers/CiviOS/contents/images/3840x2160.png";

// ---------- Systemleiste oben ----------
var top = new Panel;
top.location = "top";
top.height = Math.round(gridUnit * 1.8);
top.floating = false;

var launcher = top.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "civios-logo");

top.addWidget("org.kde.plasma.appmenu");
top.addWidget("org.kde.plasma.panelspacer");

var clock = top.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", "true");
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d. MMM");

top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.kde.plasma.systemtray");

// ---------- Dock unten ----------
var dock = new Panel;
dock.location = "bottom";
dock.height = Math.round(gridUnit * 3.4);
dock.floating = true;
dock.lengthMode = "fit";
dock.alignment = "center";
dock.hiding = "dodgewindows";

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "preferred://filemanager",
    "preferred://browser",
    "applications:steam.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:civios-center.desktop",
    "applications:systemsettings.desktop"
]);
tasks.writeConfig("showOnlyCurrentDesktop", "false");
tasks.writeConfig("indicateAudioStreams", "true");

// ---------- Hintergrund ----------
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", wallpaperPath);
    d.writeConfig("FillMode", "2");
}
