#!/usr/bin/env python3
"""Ionity watermark — bottom-right desktop overlay (Linux, tkinter).
(c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd · ionity.today
Toggle on/off:  python3 watermark.py --toggle
"""
import json, os, sys, signal

BASE = os.path.dirname(os.path.abspath(__file__))
CFG = os.path.join(BASE, "settings.json")
LOGO = os.path.join(BASE, "ionity_logo.png")

def load():
    try:
        with open(CFG) as f: return json.load(f)
    except Exception:
        return {"watermark": True, "width": 150, "margin": 16, "alpha": 0.55}

def save(c):
    with open(CFG, "w") as f: json.dump(c, f, indent=2)

cfg = load()

if "--toggle" in sys.argv:
    cfg["watermark"] = not cfg.get("watermark", True)
    save(cfg)
    os.system("pkill -f 'ionity-mario/watermark.py' 2>/dev/null")
    if cfg["watermark"]:
        os.system(f"nohup python3 '{os.path.abspath(__file__)}' >/dev/null 2>&1 &")
    print("watermark:", "ON" if cfg["watermark"] else "OFF")
    sys.exit(0)

if not cfg.get("watermark", True):
    sys.exit(0)

import tkinter as tk

root = tk.Tk()
root.overrideredirect(True)          # borderless
root.attributes("-topmost", True)
try: root.attributes("-type", "utility")
except Exception: pass
root.attributes("-alpha", cfg.get("alpha", 0.55))

img = tk.PhotoImage(file=LOGO)
w = cfg.get("width", 150)
factor = max(1, round(img.width() / w))
img = img.subsample(factor, factor)

lbl = tk.Label(root, image=img, bg="black", bd=0)
lbl.pack()
try:  # make black transparent where supported (compositing WMs)
    root.wm_attributes("-transparentcolor", "black")
except Exception:
    pass

m = cfg.get("margin", 16)
root.update_idletasks()
sw, sh = root.winfo_screenwidth(), root.winfo_screenheight()
root.geometry(f"+{sw - img.width() - m}+{sh - img.height() - m - 40}")

signal.signal(signal.SIGTERM, lambda *_: root.destroy())

def keep_top():
    root.attributes("-topmost", True)
    root.after(15000, keep_top)
keep_top()
root.mainloop()
