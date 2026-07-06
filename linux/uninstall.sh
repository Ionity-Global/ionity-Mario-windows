#!/usr/bin/env bash
# Ionity Mario Sound Theme — Linux uninstaller
set -uo pipefail
echo "Restoring default sounds..."
if command -v gsettings >/dev/null 2>&1; then
  gsettings reset org.gnome.desktop.sound theme-name 2>/dev/null || true
  gsettings reset org.gnome.desktop.sound input-feedback-sounds 2>/dev/null || true
fi
pkill -f "ionity-mario/watermark.py" 2>/dev/null || true
pkill -f "ionity-mario.*watermark" 2>/dev/null || true
rm -rf "$HOME/.local/share/sounds/ionity-mario" \
       "$HOME/.local/share/ionity-mario" \
       "$HOME/.config/autostart/ionity-watermark.desktop"
echo "Done — thanks for playing!  · ionity.today"
