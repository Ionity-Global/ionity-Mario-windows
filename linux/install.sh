#!/usr/bin/env bash
# =====================================================================
#  Ionity Mario Sound Theme — Linux installer (freedesktop/GNOME)
#  (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd · ionity.today
#  Sounds (c) Nintendo — non-commercial fan sound-theme, personal use.
# =====================================================================
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_SRC="$DIR/theme/ionity-mario"
THEME_DST="$HOME/.local/share/sounds/ionity-mario"
APP_DST="$HOME/.local/share/ionity-mario"

echo ""
echo "  ============================================"
echo "   IONITY x SUPER MARIO SOUND THEME — Linux"
echo "   Building Tomorrow, Today.  ·  ionity.today"
echo "  ============================================"
echo ""

# 1. sound theme (freedesktop sound-theme-spec)
echo "  [1/3] Installing sound theme -> $THEME_DST"
mkdir -p "$THEME_DST"
cp -r "$THEME_SRC/." "$THEME_DST/"
cat > "$THEME_DST/index.theme" <<'EOF'
[Sound Theme]
Name=Ionity Mario
Comment=Super Mario system sounds by Ionity — ionity.today
Directories=stereo

[stereo]
OutputProfile=stereo
EOF

# 2. apply (GNOME / Cinnamon / MATE; KDE users: System Settings > Notifications)
echo "  [2/3] Applying theme"
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.sound theme-name 'ionity-mario' 2>/dev/null || true
  gsettings set org.gnome.desktop.sound event-sounds true 2>/dev/null || true
  gsettings set org.gnome.desktop.sound input-feedback-sounds true 2>/dev/null || true
  echo "        GNOME sound theme set to 'ionity-mario'."
else
  echo "        gsettings not found — select 'Ionity Mario' manually in your DE sound settings."
fi

# 3. watermark (optional, python3 + tkinter)
echo "  [3/3] Ionity watermark (bottom-right overlay)"
mkdir -p "$APP_DST"
cp "$DIR/watermark.py" "$APP_DST/" 2>/dev/null || true
cp "$DIR/../assets/ionity_logo.png" "$APP_DST/" 2>/dev/null || true
if python3 -c 'import tkinter' 2>/dev/null; then
  mkdir -p "$HOME/.config/autostart"
  cat > "$HOME/.config/autostart/ionity-watermark.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ionity Watermark
Exec=python3 $APP_DST/watermark.py
X-GNOME-Autostart-enabled=true
EOF
  (nohup python3 "$APP_DST/watermark.py" >/dev/null 2>&1 &) || true
  echo "        Watermark started + autostart enabled."
  echo "        Toggle: python3 $APP_DST/watermark.py --toggle"
else
  echo "        python3-tk not found — watermark skipped (sudo apt install python3-tk)."
fi

# test sound
command -v canberra-gtk-play >/dev/null 2>&1 && canberra-gtk-play -i bell -d "Ionity Mario test" 2>/dev/null || \
  command -v paplay >/dev/null 2>&1 && paplay "$THEME_DST/stereo/bell.oga" 2>/dev/null || true

echo ""
echo "  Done! Coin = alerts, Bowser = errors, pipe = logout."
echo "  Uninstall: ./uninstall.sh"
echo ""
