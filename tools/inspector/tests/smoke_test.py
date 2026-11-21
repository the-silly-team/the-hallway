"""Open every sample format in a real Tk window, cycle all tabs, then exit."""

import os
import sys
import tkinter as tk

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hallway_inspector as d

SAMPLES = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "samples")
)
FILES = [
    "menu.sltx",
    "tone.slau",
    "collision.slcl",
    "level.sllv",
    "scene.slsc",
    "manifest.slmf",
]

root = tk.Tk()
app = d.InspectorApp(root)
for name in FILES:
    app.open_file(os.path.join(SAMPLES, name))
    for tab in range(4):
        app.nb.select(tab)
        root.update()
root.after(150, root.destroy)
root.mainloop()
print("GUI SMOKE OK", len(app.files), "files")
