# CiviOS Containerfile
#
# CiviOS ist ein bootc-Image. Das gesamte Betriebssystem wird wie ein
# Container gebaut, signiert und verteilt. Installierte Systeme holen
# Updates atomar aus der Registry und können jederzeit auf die vorherige
# Version zurückrollen.
#
# Basis: Bazzite (Universal Blue), selbst ein Fedora-Atomic-Derivat mit
# Gaming-Kernel, Mesa, Steam, Gamescope, HDR/VRR-Patches und Treibern.
#
# Varianten (Build-Argument BASE_IMAGE):
#   AMD / Intel:      ghcr.io/ublue-os/bazzite:stable
#   NVIDIA (RTX 20+): ghcr.io/ublue-os/bazzite-nvidia-open:stable
#   NVIDIA (älter):   ghcr.io/ublue-os/bazzite-nvidia:stable

ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite:stable

FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

FROM ${BASE_IMAGE}

ARG CIVIOS_VERSION=0.1.0
ENV CIVIOS_VERSION=${CIVIOS_VERSION}

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Prüft, ob das Ergebnis ein gültiges bootc-Image ist (Kernel, initramfs,
# keine verbotenen Inhalte in /var usw.). Schlägt der Lint fehl, bricht
# der Build ab.
RUN bootc container lint
