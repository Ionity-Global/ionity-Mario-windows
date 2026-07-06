#!/usr/bin/env bash
# Ionity Mario Sound Theme — macOS uninstaller
set -uo pipefail
rm -f "$HOME/Library/Sounds/Mario "*.aiff "$HOME/Library/Sounds/Mario "*.wav 2>/dev/null || true
defaults delete -g com.apple.sound.beep.sound 2>/dev/null || true
echo "Mario alert sounds removed, default alert restored. · ionity.today"
