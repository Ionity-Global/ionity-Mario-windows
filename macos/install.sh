#!/usr/bin/env bash
# =====================================================================
#  Ionity Mario Sound Theme — macOS installer
#  (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd · ionity.today
#  Sounds (c) Nintendo — non-commercial fan sound-theme, personal use.
#
#  macOS only allows custom *alert* sounds (System Settings > Sound).
#  This installs all 23 Mario sounds as selectable alert sounds and
#  sets the Coin as your active alert. Startup chime is firmware-locked.
# =====================================================================
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SND_SRC="$DIR/../sounds"
DST="$HOME/Library/Sounds"

echo ""
echo "  IONITY x SUPER MARIO — macOS alert sounds"
echo "  Building Tomorrow, Today.  ·  ionity.today"
echo ""

mkdir -p "$DST"
i=0
for f in "$SND_SRC"/smb_*.wav; do
  base="$(basename "$f" .wav)"
  nice="$(echo "${base#smb_}" | tr '_-' '  ' | awk '{for(j=1;j<=NF;j++) $j=toupper(substr($j,1,1)) substr($j,2)}1')"
  out="$DST/Mario $nice.aiff"
  if command -v afconvert >/dev/null 2>&1; then
    afconvert -f AIFF -d BEI16 "$f" "$out" && i=$((i+1))
  else
    cp "$f" "$DST/Mario $nice.wav" && i=$((i+1))   # modern macOS accepts wav too
  fi
done
echo "  [1/2] $i Mario alert sounds installed -> ~/Library/Sounds"

# set coin as the active alert sound
COIN="$DST/Mario Coin.aiff"; [ -f "$COIN" ] || COIN="$DST/Mario Coin.wav"
defaults write -g com.apple.sound.beep.sound -string "$COIN"
echo "  [2/2] Alert sound set to Mario Coin (log out/in if not immediate)."
afplay "$COIN" 2>/dev/null || true

echo ""
echo "  Pick other Mario sounds: System Settings > Sound > Alert sound."
echo "  Uninstall: ./uninstall.sh"
echo ""
