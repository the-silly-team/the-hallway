#!/usr/bin/env python3
"""SILLYSOFT HALLWAY INSPECTOR - standalone viewer for the .sl* asset family.

Zero external dependencies. Python 3.8+ with tkinter (stdlib).

    python hallway_inspector.py [file.sltx ...]

Shows the decoded field layout with offsets, previews images, plays audio,
resolves cross-file references, and dumps raw bytes. Nothing here is a text
file: every format is parsed from its binary envelope.
"""

import base64
import json
import math
import os
import struct
import sys
import tempfile
import tkinter as tk
import wave
import zlib
from pathlib import Path
from tkinter import ttk, filedialog, messagebox

try:
    import winsound
except ImportError:  # non-windows: playback disabled, everything else works
    winsound = None


# ---------------------------------------------------------------- palette
BG = "#0c0e13"
PANEL = "#121722"
PANEL2 = "#171d2b"
EDGE = "#252d3d"
TEXT = "#d8e0ee"
DIM = "#78839a"
ACCENT = "#6ff0c0"
ACCENT2 = "#c39aff"
OK = "#5ad49a"
BAD = "#ff6b7d"
WARN = "#ffc36b"

EXTS = [
    (".sltx", "SILLYSOFT texture"),
    (".slau", "SILLYSOFT audio"),
    (".slcl", "SILLYSOFT collision"),
    (".sllv", "SILLYSOFT level"),
    (".slsc", "SILLYSOFT scene"),
    (".slmf", "SILLYSOFT manifest"),
]
KNOWN_EXT = {e for e, _ in EXTS}

MAGIC_LABEL = {
    "SLTX": ("TEXTURE", ACCENT),
    "SLAU": ("AUDIO", ACCENT2),
    "SLCL": ("COLLISION", WARN),
    "SLLV": ("LEVEL SOURCE", "#7ec8ff"),
    "SLSC": ("COMPILED SCENE", "#ffa8d0"),
    "SLMF": ("PACKAGE MANIFEST", "#ffd98a"),
}


# ---------------------------------------------------------------- binary reader
class Reader:
    """Tracks every read as a structured field with its byte offset."""

    def __init__(self, data, fields):
        self.d = data
        self.p = 0
        self.f = fields

    def _add(self, off, label, kind, value, size):
        self.f.append((off, label, kind, value, size))

    def ascii(self, n, label, kind="char[]"):
        off = self.p
        v = self.d[self.p:self.p + n].decode("ascii", errors="replace")
        self.p += n
        self._add(off, label, kind, repr(v), n)
        return v

    def u8(self, label):
        off = self.p
        v = self.d[self.p]
        self.p += 1
        self._add(off, label, "u8", str(v), 1)
        return v

    def u16(self, label):
        off = self.p
        v = struct.unpack_from("<H", self.d, self.p)[0]
        self.p += 2
        self._add(off, label, "u16", str(v), 2)
        return v

    def u32(self, label):
        off = self.p
        v = struct.unpack_from("<I", self.d, self.p)[0]
        self.p += 4
        self._add(off, label, "u32", str(v), 4)
        return v

    def f32(self, label):
        off = self.p
        v = struct.unpack_from("<f", self.d, self.p)[0]
        self.p += 4
        self._add(off, label, "f32", "%.6g" % v, 4)
        return v

    def vec3(self, label):
        off = self.p
        v = struct.unpack_from("<fff", self.d, self.p)
        self.p += 12
        self._add(off, label, "vec3<f32>", "(%.3f, %.3f, %.3f)" % v, 12)
        return v

    def cstr(self, label):
        off = self.p
        n = self.d[self.p]
        self.p += 1
        v = self.d[self.p:self.p + n].decode("utf-8", errors="replace")
        self.p += n
        self._add(off, label, "cstr", repr(v), 1 + n)
        return v

    def blob(self, label, n, summary):
        off = self.p
        v = self.d[self.p:self.p + n]
        if len(v) != n:
            raise ValueError("truncated blob at %d (wanted %d, got %d)" % (off, n, len(v)))
        self.p += n
        self._add(off, label, "raw[%d]" % n, summary, n)
        return v


# ---------------------------------------------------------------- parsers
def _vec(v):
    return [round(float(x), 6) for x in v]


def parse_sltx(r, res):
    w = r.u16("width")
    h = r.u16("height")
    flags = r.u8("flags")
    ch = r.u8("channels")
    name = r.cstr("name")
    n = w * h * ch
    rgba = r.blob("albedo pixels", n, "%dx%d RGBA8" % (w, h))
    normal = None
    if flags & 1:
        normal = r.blob("normal pixels", n, "%dx%d RGBA8" % (w, h))
    res.update({
        "name": name, "width": w, "height": h, "flags": flags,
        "channels": ch, "rgba": rgba, "normal": normal,
    })


def parse_slau(r, res):
    rate = r.u32("sample_rate")
    ch = r.u8("channels")
    flags = r.u8("flags")
    name = r.cstr("name")
    frames = r.u32("frames")
    pcm = r.blob("pcm16 payload", frames * 2 * ch, "%d frames" % frames)
    loop = None
    if flags & 1:
        loop = (r.u32("loop_begin"), r.u32("loop_end"))
    res.update({
        "name": name, "rate": rate, "channels": ch, "frames": frames,
        "flags": flags, "pcm": pcm, "loop": loop,
    })


def parse_slcl(r, res):
    count = r.u16("box_count")
    name = r.cstr("collision_name")
    boxes = []
    for i in range(count):
        c = r.vec3("box[%d].center" % i)
        h = r.vec3("box[%d].half" % i)
        t = r.u8("box[%d].type" % i)
        boxes.append({"center": _vec(c), "half": _vec(h), "type": t})
    res.update({"name": name, "boxes": boxes})


def parse_sllv(r, res):
    name = r.cstr("level_name")
    spawn = r.vec3("spawn")
    amb = (r.f32("ambient.r"), r.f32("ambient.g"), r.f32("ambient.b"))
    count = r.u16("object_count")
    objs = []
    for i in range(count):
        typ = r.cstr("obj[%d].type" % i)
        oname = r.cstr("obj[%d].name" % i)
        pos = r.vec3("obj[%d].position" % i)
        rot = r.vec3("obj[%d].rotation" % i)
        scl = r.vec3("obj[%d].scale" % i)
        pn = r.u16("obj[%d].prop_count" % i)
        props = {}
        for j in range(pn):
            k = r.cstr("obj[%d].prop[%d].key" % (i, j))
            v = r.cstr("obj[%d].prop[%d].value" % (i, j))
            props[k] = v
            if _looks_like_path(v):
                res["refs"].append(("file", "%s.%s" % (oname, k), v))
            else:
                res["refs"].append(("object", "%s.%s" % (oname, k), v))
        objs.append({
            "type": typ, "name": oname, "position": _vec(pos),
            "rotation": _vec(rot), "scale": _vec(scl), "props": props,
        })
    res.update({
        "name": name, "spawn": _vec(spawn), "ambient": _vec(amb), "objects": objs,
    })


def parse_slsc(r, res):
    name = r.cstr("scene_name")
    source = r.cstr("source_level")
    res["refs"].append(("file", "source level", source))
    count = r.u16("instance_count")
    inst = []
    for i in range(count):
        oid = r.u32("inst[%d].id" % i)
        tmpl = r.cstr("inst[%d].template" % i)
        pos = r.vec3("inst[%d].position" % i)
        rot = r.vec3("inst[%d].rotation" % i)
        scl = r.vec3("inst[%d].scale" % i)
        flags = r.u16("inst[%d].flags" % i)
        an = r.u16("inst[%d].asset_count" % i)
        assets = []
        for j in range(an):
            a = r.cstr("inst[%d].asset[%d]" % (i, j))
            assets.append(a)
            res["refs"].append(("file", "inst[%d].asset[%d]" % (i, j), a))
        if _looks_like_path(tmpl):
            res["refs"].append(("file", "inst[%d].template" % i, tmpl))
        inst.append({
            "id": oid, "template": tmpl, "position": _vec(pos),
            "rotation": _vec(rot), "scale": _vec(scl),
            "flags": flags, "assets": assets,
        })
    res.update({"name": name, "source": source, "instances": inst})


def parse_slmf(r, res):
    title = r.cstr("title")
    author = r.cstr("author")
    count = r.u16("entry_count")
    entries = []
    for i in range(count):
        path = r.cstr("entry[%d].path" % i)
        magic = r.cstr("entry[%d].magic" % i)
        size = r.u32("entry[%d].size" % i)
        crc = r.u32("entry[%d].crc" % i)
        dn = r.u16("entry[%d].dep_count" % i)
        deps = []
        for j in range(dn):
            dep = r.cstr("entry[%d].dep[%d]" % (i, j))
            deps.append(dep)
            res["refs"].append(("file", "entry[%d].dep[%d]" % (i, j), dep))
        res["refs"].append(("file", "entry[%d].path" % i, path))
        entries.append({
            "path": path, "magic": magic, "size": size,
            "crc": "0x%08X" % crc, "deps": deps,
        })
    res.update({"title": title, "author": author, "entries": entries})


PARSERS = {
    "SLTX": parse_sltx,
    "SLAU": parse_slau,
    "SLCL": parse_slcl,
    "SLLV": parse_sllv,
    "SLSC": parse_slsc,
    "SLMF": parse_slmf,
}


def _looks_like_path(s):
    s = str(s).strip().lower().replace("\\", "/")
    return any(s.endswith(ext) for ext in KNOWN_EXT) or "/" in s


def parse_file(path):
    path = os.path.normpath(os.path.abspath(str(path)))
    data = Path(path).read_bytes()
    res = {
        "path": path, "name": os.path.basename(path), "size": len(data),
        "data": data, "fields": [], "refs": [], "error": None,
        "crc_ok": False, "stored_crc": 0, "calc_crc": 0,
    }
    if len(data) < 16:
        res["error"] = "file too short to contain a SILLYSOFT envelope"
        return res

    r = Reader(data, res["fields"])
    magic = r.ascii(4, "magic")
    vendor = r.ascii(6, "vendor")
    version = r.u16("version")
    res["magic"] = magic
    res["vendor"] = vendor
    res["version"] = version

    stored = struct.unpack_from("<I", data, len(data) - 4)[0]
    calc = zlib.crc32(data[:-4]) & 0xFFFFFFFF
    res["stored_crc"] = stored
    res["calc_crc"] = calc
    res["crc_ok"] = stored == calc
    res["fields"].append((
        len(data) - 4, "crc32", "u32",
        "0x%08X %s" % (stored, "OK" if res["crc_ok"] else "MISMATCH"), 4,
    ))

    if vendor != "SILLY!":
        res["error"] = "vendor is %r, expected 'SILLY!'" % vendor
        return res
    if magic not in PARSERS:
        res["error"] = "unknown magic %r" % magic
        return res
    try:
        PARSERS[magic](r, res)
    except Exception as e:
        res["error"] = "%s: %s" % (type(e).__name__, e)
    return res


# ---------------------------------------------------------------- image helpers
def rgba_to_png(rgba, w, h):
    stride = w * 4
    raw = bytearray()
    for y in range(h):
        raw.append(0)  # PNG filter: none
        raw.extend(rgba[y * stride:(y + 1) * stride])

    def chunk(tag, payload):
        return (struct.pack(">I", len(payload)) + tag + payload
                + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF))

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))


def make_photo(res, rgba, w, h):
    png = rgba_to_png(rgba, w, h)
    photo = tk.PhotoImage(data=base64.b64encode(png).decode("ascii"))
    factor = max(1, math.ceil(max(w / 520.0, h / 330.0)))
    shown = photo.subsample(factor, factor) if factor > 1 else photo
    res.setdefault("_photos", []).extend([photo, shown])
    return shown


def clean_text(widget, state="disabled"):
    widget.configure(state="normal")
    widget.delete("1.0", "end")
    return widget


def lock_text(widget):
    widget.configure(state="disabled")


# ---------------------------------------------------------------- app
class InspectorApp:
    def __init__(self, root, initial=None):
        self.root = root
        self.files = {}          # path -> parsed dict
        self.current = None
        self.ref_targets = {}    # treeview item -> resolved path
        self.auto_resolve = tk.BooleanVar(value=True)
        self.playing = False
        self.play_start = 0.0
        self.play_dur = 0.0
        self.play_canvas = None
        self.playhead = None
        self.after_id = None
        self.temp_wav = None
        self._build_ui()
        if initial:
            for p in initial:
                self.open_file(p)

    # ------------------------------------------------------------ ui
    def _build_ui(self):
        self.root.title("SILLYSOFT HALLWAY INSPECTOR // proprietary binary viewer")
        self.root.geometry("1200x780")
        self.root.minsize(920, 620)
        self.root.configure(bg=BG)

        style = ttk.Style()
        style.theme_use("clam")
        style.configure(".", background=PANEL, foreground=TEXT,
                        font=("Segoe UI", 10), borderwidth=0)
        style.configure("TFrame", background=PANEL)
        style.configure("TLabel", background=PANEL, foreground=TEXT)
        style.configure("Dim.TLabel", foreground=DIM)
        style.configure("Title.TLabel", background=BG, foreground=ACCENT,
                        font=("Consolas", 15, "bold"))
        style.configure("Head.TLabel", background=PANEL2, foreground=TEXT,
                        font=("Consolas", 10, "bold"))
        style.configure("TButton", background=PANEL2, foreground=TEXT,
                        padding=(10, 5), borderwidth=1,
                        bordercolor=EDGE, focuscolor=PANEL2)
        style.map("TButton", background=[("active", "#202a3d")])
        style.configure("TCheckbutton", background=PANEL, foreground=DIM)
        style.configure("Treeview", background=PANEL2, fieldbackground=PANEL2,
                        foreground=TEXT, rowheight=22, bordercolor=EDGE)
        style.configure("Treeview.Heading", background="#1b2231",
                        foreground=ACCENT, font=("Consolas", 9, "bold"))
        style.map("Treeview", background=[("selected", "#26374d")])
        style.configure("TNotebook", background=BG, borderwidth=0)
        style.configure("TNotebook.Tab", background=PANEL, foreground=DIM,
                        padding=(14, 6), font=("Consolas", 10))
        style.map("TNotebook.Tab", background=[("selected", PANEL2)],
                  foreground=[("selected", ACCENT)])

        top = tk.Frame(self.root, bg=BG, height=58)
        top.pack(fill="x", side="top")
        tk.Label(top, text="SILLYSOFT // HALLWAY INSPECTOR", bg=BG, fg=ACCENT,
                 font=("Consolas", 15, "bold")).pack(side="left", padx=(16, 18))
        ttk.Button(top, text="  OPEN FILE  ", command=self.pick_file).pack(side="left")
        ttk.Checkbutton(top, text="resolve references", variable=self.auto_resolve,
                        style="TCheckbutton").pack(side="left", padx=18)
        self.path_label = tk.Label(top, text="no file loaded", bg=BG, fg=DIM,
                                   font=("Consolas", 9), anchor="w")
        self.path_label.pack(side="left", fill="x", expand=True, padx=10)

        main = ttk.PanedWindow(self.root, orient="horizontal")
        main.pack(fill="both", expand=True, padx=8, pady=(0, 6))

        left = ttk.Frame(main, width=230)
        main.add(left, weight=0)
        ttk.Label(left, text="WORKSPACE", style="Head.TLabel").pack(
            fill="x", padx=8, pady=(8, 4))
        self.files_tree = ttk.Treeview(left, show="tree", selectmode="browse")
        self.files_tree.pack(fill="both", expand=True, padx=8, pady=(0, 8))
        self.files_tree.bind("<<TreeviewSelect>>", self._on_pick_file)
        ttk.Button(left, text="Close file", command=self.close_selected).pack(
            fill="x", padx=8, pady=(0, 8))

        right = ttk.Frame(main)
        main.add(right, weight=1)

        self.head = tk.Frame(right, bg=PANEL2, height=46)
        self.head.pack(fill="x", pady=(0, 6))
        self.head_labels = {}
        for key, label in [("magic", "MAGIC"), ("vendor", "VENDOR"),
                           ("version", "VERSION"), ("size", "SIZE")]:
            box = tk.Frame(self.head, bg=PANEL2)
            box.pack(side="left", padx=(14, 4), pady=8)
            tk.Label(box, text=label, bg=PANEL2, fg=DIM,
                     font=("Consolas", 8)).pack(anchor="w")
            v = tk.Label(box, text="-", bg=PANEL2, fg=TEXT,
                         font=("Consolas", 11, "bold"))
            v.pack(anchor="w")
            self.head_labels[key] = v
        self.crc_badge = tk.Label(self.head, text="CRC --", bg=PANEL2, fg=DIM,
                                  font=("Consolas", 10, "bold"), padx=14)
        self.crc_badge.pack(side="right", padx=12)

        self.nb = ttk.Notebook(right)
        self.nb.pack(fill="both", expand=True)

        self.struct_tree = ttk.Treeview(
            self.nb, columns=("off", "field", "type", "value"), show="headings")
        for col, text, w in [("off", "OFFSET", 90), ("field", "FIELD", 210),
                             ("type", "TYPE", 130), ("value", "VALUE", 520)]:
            self.struct_tree.heading(col, text=text)
            self.struct_tree.column(col, width=w, anchor="w")
        self.nb.add(self.struct_tree, text=" STRUCTURE ")

        self.preview = ttk.Frame(self.nb)
        self.nb.add(self.preview, text=" PREVIEW ")

        self.refs_tree = ttk.Treeview(
            self.nb, columns=("kind", "label", "target", "status"),
            show="headings")
        for col, text, w in [("kind", "KIND", 90), ("label", "SOURCE FIELD", 220),
                             ("target", "POINTS TO", 400), ("status", "STATUS", 100)]:
            self.refs_tree.heading(col, text=text)
            self.refs_tree.column(col, width=w, anchor="w")
        self.refs_tree.bind("<Double-1>", self._follow_ref)
        self.nb.add(self.refs_tree, text=" REFERENCES ")

        hexwrap = ttk.Frame(self.nb)
        self.hex_text = tk.Text(hexwrap, bg=BG, fg=DIM, insertbackground=ACCENT,
                                font=("Consolas", 10), wrap="none",
                                borderwidth=0, highlightthickness=0)
        sb = ttk.Scrollbar(hexwrap, orient="vertical", command=self.hex_text.yview)
        self.hex_text.configure(yscrollcommand=sb.set)
        sb.pack(side="right", fill="y")
        self.hex_text.pack(fill="both", expand=True)
        self.hex_text.tag_configure("hdr", foreground=ACCENT)
        self.hex_text.tag_configure("crc", foreground=WARN)
        self.nb.add(hexwrap, text=" HEX ")

        self.status = tk.Label(self.root, text="SILLY! // ready", bg=BG, fg=DIM,
                               font=("Consolas", 9), anchor="w")
        self.status.pack(fill="x", side="bottom", padx=12, pady=(0, 6))

        self.root.bind("<Control-o>", lambda e: self.pick_file())

    # ------------------------------------------------------------ files
    def pick_file(self):
        patterns = " ".join("*%s" % e for e, _ in EXTS)
        p = filedialog.askopenfilename(
            title="Open SILLYSOFT file",
            filetypes=[("SILLYSOFT assets", patterns), ("All files", "*.*")],
        )
        if p:
            self.open_file(p)

    def open_file(self, path, depth=0, seen=None):
        path = os.path.normpath(os.path.abspath(str(path)))
        if seen is None:
            seen = set()
        if path in seen or depth > 3:
            return
        seen.add(path)
        if path in self.files:
            self.current = path
            self.render()
            self._sync_tree()
            return
        try:
            res = parse_file(path)
        except Exception as e:
            messagebox.showerror("Open failed", "%s\n\n%s" % (path, e))
            return
        self.files[path] = res
        self.files_tree.insert("", "end", iid=path, text=res["name"],
                               tags=(res.get("magic", "BAD"),))
        for magic, (_, color) in MAGIC_LABEL.items():
            self.files_tree.tag_configure(magic, foreground=color)
        self.current = path
        self.render()
        self._sync_tree()

        if self.auto_resolve.get() and depth < 3:
            for kind, _label, target in list(res["refs"]):
                if kind != "file" or not target:
                    continue
                candidate = os.path.normpath(
                    os.path.join(os.path.dirname(path), target))
                if os.path.isfile(candidate) and candidate not in self.files:
                    self.open_file(candidate, depth + 1, seen)

    def close_selected(self):
        sel = self.files_tree.selection()
        if not sel:
            return
        path = sel[0]
        self._stop_audio()
        self.files.pop(path, None)
        self.files_tree.delete(path)
        if self.current == path:
            self.current = next(iter(self.files), None)
            self.render()

    def _on_pick_file(self, _event):
        sel = self.files_tree.selection()
        if sel and sel[0] in self.files:
            self._stop_audio()
            self.current = sel[0]
            self.render()

    def _sync_tree(self):
        if self.current and self.files_tree.exists(self.current):
            self.files_tree.selection_set(self.current)
            self.files_tree.see(self.current)

    def _follow_ref(self, _event):
        sel = self.refs_tree.selection()
        if not sel:
            return
        path = self.ref_targets.get(sel[0])
        if path and os.path.isfile(path):
            self.open_file(path)
        else:
            self.status.configure(text="SILLY! // reference target not found")

    # ------------------------------------------------------------ render
    def render(self):
        res = self.files.get(self.current) if self.current else None
        self._clear_all()
        if not res:
            self.path_label.configure(text="no file loaded")
            self.head_labels["magic"].configure(text="-")
            self.status.configure(text="SILLY! // ready")
            return

        self.path_label.configure(text=res["path"], fg=DIM)
        magic = res.get("magic", "----")
        label, color = MAGIC_LABEL.get(magic, ("UNKNOWN", BAD))
        self.head_labels["magic"].configure(text="%s  %s" % (magic, label), fg=color)
        self.head_labels["vendor"].configure(text=res.get("vendor", "?"))
        self.head_labels["version"].configure(text=str(res.get("version", "?")))
        self.head_labels["size"].configure(text="%s B" % format(res["size"], ","))
        ok = res["crc_ok"]
        self.crc_badge.configure(
            text="CRC %s  0x%08X" % ("OK" if ok else "BAD", res["stored_crc"]),
            fg=OK if ok else BAD)
        self.status.configure(
            text="SILLY! // %s // %s // %d fields // %d references"
                 % (res["name"], label, len(res["fields"]), len(res["refs"])))

        self._render_structure(res)
        self._render_preview(res)
        self._render_refs(res)
        self._render_hex(res)

    def _clear_all(self):
        for item in self.struct_tree.get_children():
            self.struct_tree.delete(item)
        for item in self.refs_tree.get_children():
            self.refs_tree.delete(item)
        self.ref_targets.clear()
        for w in list(self.preview.winfo_children()):
            w.destroy()
        clean_text(self.hex_text).delete("1.0", "end")

    def _render_structure(self, res):
        for off, label, kind, value, size in res["fields"]:
            self.struct_tree.insert(
                "", "end",
                values=("0x%04X" % off, label, kind, value))

    def _render_refs(self, res):
        base = os.path.dirname(res["path"])
        for kind, label, target in res["refs"]:
            resolved = ""
            status = "IN-FILE"
            if kind == "file" and target:
                resolved = os.path.normpath(os.path.join(base, target))
                status = "FOUND" if os.path.isfile(resolved) else "MISSING"
            elif kind == "file":
                status = "EMPTY"
            item = self.refs_tree.insert("", "end", values=(kind.upper(), label, target, status))
            self.ref_targets[item] = resolved

    def _render_hex(self, res):
        data = res["data"]
        limit = min(len(data), 8192)
        for off in range(0, limit, 16):
            chunk = data[off:off + 16]
            hx = " ".join("%02X" % b for b in chunk)
            asc = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
            tag = "hdr" if off < 12 else ("crc" if off >= len(data) - 4 else ())
            line = "%08X  %-47s  |%s|\n" % (off, hx, asc)
            if tag:
                self.hex_text.insert("end", line, tag)
            else:
                self.hex_text.insert("end", line)
        if limit < len(data):
            self.hex_text.insert("end", "\n... %s more bytes (hex view capped) ...\n"
                                 % format(len(data) - limit, ","))
        lock_text(self.hex_text)

    # ------------------------------------------------------------ previews
    def _render_preview(self, res):
        magic = res.get("magic")
        if res.get("error"):
            self._banner("PARSE ERROR", res["error"], BAD)
            return
        if magic == "SLTX":
            self._preview_texture(res)
        elif magic == "SLAU":
            self._preview_audio(res)
        elif magic == "SLCL":
            self._preview_collision(res)
        elif magic == "SLLV":
            self._preview_json(res, {
                "name": res["name"], "spawn": res["spawn"],
                "ambient": res["ambient"], "objects": res["objects"]})
        elif magic == "SLSC":
            self._preview_json(res, {
                "name": res["name"], "source": res["source"],
                "instances": res["instances"]})
        elif magic == "SLMF":
            self._preview_json(res, {
                "title": res["title"], "author": res["author"],
                "entries": res["entries"]})
        else:
            self._banner("UNKNOWN FORMAT", "magic %r" % magic, WARN)

    def _banner(self, title, text, color):
        box = ttk.Frame(self.preview)
        box.pack(expand=True)
        tk.Label(box, text=title, bg=PANEL, fg=color,
                 font=("Consolas", 18, "bold")).pack(pady=(0, 10))
        tk.Label(box, text=text, bg=PANEL, fg=TEXT,
                 font=("Consolas", 11), wraplength=620).pack()

    def _meta_row(self, parent, pairs):
        row = ttk.Frame(parent)
        row.pack(fill="x", padx=12, pady=(10, 6))
        for k, v in pairs:
            cell = tk.Frame(row, bg=PANEL2)
            cell.pack(side="left", padx=(0, 18))
            tk.Label(cell, text=k, bg=PANEL2, fg=DIM,
                     font=("Consolas", 8)).pack(anchor="w")
            tk.Label(cell, text=str(v), bg=PANEL2, fg=TEXT,
                     font=("Consolas", 11, "bold")).pack(anchor="w")

    def _preview_texture(self, res):
        self._meta_row(self.preview, [
            ("NAME", res["name"]), ("SIZE", "%dx%d" % (res["width"], res["height"])),
            ("CHANNELS", res["channels"]), ("FLAGS", res["flags"]),
        ])
        strip = ttk.Frame(self.preview)
        strip.pack(fill="both", expand=True, padx=12, pady=8)
        for title, pixels in [("ALBEDO / RGBA8", res["rgba"]),
                              ("NORMAL / RGBA8", res["normal"])]:
            col = tk.Frame(strip, bg=PANEL2, highlightbackground=EDGE,
                           highlightthickness=1)
            col.pack(side="left", fill="both", expand=True, padx=(0, 8))
            tk.Label(col, text=title, bg=PANEL2, fg=ACCENT,
                     font=("Consolas", 10, "bold")).pack(pady=(8, 6))
            if pixels is None:
                tk.Label(col, text="no embedded normal map", bg=PANEL2, fg=DIM,
                         font=("Consolas", 10)).pack(expand=True)
            else:
                photo = make_photo(res, pixels, res["width"], res["height"])
                tk.Label(col, image=photo, bg=PANEL2).pack(expand=True, pady=6)

    def _preview_audio(self, res):
        self._meta_row(self.preview, [
            ("NAME", res["name"]), ("RATE", "%d Hz" % res["rate"]),
            ("CHANNELS", res["channels"]), ("FRAMES", format(res["frames"], ",")),
            ("DURATION", "%.3f s" % (res["frames"] / max(1, res["rate"]))),
            ("LOOP", "%s" % (res["loop"] if res["loop"] else "off")),
        ])
        holder = tk.Frame(self.preview, bg=PANEL2, highlightbackground=EDGE,
                          highlightthickness=1)
        holder.pack(fill="both", expand=True, padx=12, pady=8)
        canvas = tk.Canvas(holder, bg=BG, highlightthickness=0)
        canvas.pack(fill="both", expand=True, padx=8, pady=8)
        self.play_canvas = canvas
        self._draw_waveform(canvas, res)

        bar = ttk.Frame(self.preview)
        bar.pack(fill="x", padx=12, pady=(0, 12))
        if winsound is None:
            ttk.Label(bar, text="audio playback unavailable on this platform").pack(side="left")
        else:
            ttk.Button(bar, text="PLAY", command=lambda: self._play_audio(res)).pack(side="left")
            ttk.Button(bar, text="STOP", command=self._stop_audio).pack(side="left", padx=8)
        ttk.Button(bar, text="EXPORT WAV...",
                   command=lambda: self._export_wav(res)).pack(side="left", padx=8)

    def _draw_waveform(self, canvas, res):
        canvas.update_idletasks()
        w = max(100, canvas.winfo_width() - 4)
        h = max(80, canvas.winfo_height() - 4)
        cy = h // 2
        canvas.delete("all")
        canvas.create_line(0, cy, w, cy, fill=EDGE)

        pcm = res["pcm"]
        n = len(pcm) // 2
        if n == 0:
            return
        samples = struct.unpack("<%dh" % n, pcm[:n * 2])
        step = max(1, len(samples) // w)
        amp = (h / 2 - 10) / 32768.0
        color = ACCENT2 if res["channels"] == 1 else ACCENT
        for x in range(w):
            a = x * len(samples) // w
            b = min(len(samples), a + step)
            seg = samples[a:b]
            if not seg:
                continue
            lo, hi = min(seg), max(seg)
            canvas.create_line(x, cy - hi * amp, x, cy - lo * amp, fill=color)

        if res["loop"]:
            lb, le = res["loop"]
            for frame, col in [(lb, WARN), (le, WARN)]:
                x = int(frame / max(1, res["frames"]) * w)
                canvas.create_line(x, 4, x, h - 4, fill=col, dash=(3, 3))
        self.playhead = canvas.create_line(0, 0, 0, h, fill=OK, width=2)

    def _write_wav(self, res, path):
        with wave.open(path, "wb") as f:
            f.setnchannels(res["channels"])
            f.setsampwidth(2)
            f.setframerate(res["rate"])
            f.writeframes(res["pcm"])

    def _play_audio(self, res):
        if winsound is None:
            return
        self._stop_audio()
        fd, path = tempfile.mkstemp(suffix=".wav", prefix="hallway_")
        os.close(fd)
        try:
            self._write_wav(res, path)
            winsound.PlaySound(path, winsound.SND_FILENAME | winsound.SND_ASYNC)
            self.temp_wav = path
            self.playing = True
            self.play_start = __import__("time").monotonic()
            self.play_dur = res["frames"] / max(1, res["rate"])
            self._tick()
        except Exception as e:
            messagebox.showerror("Playback failed", str(e))

    def _stop_audio(self):
        if winsound is not None:
            try:
                winsound.PlaySound(None, winsound.SND_PURGE)
            except Exception:
                pass
        self.playing = False
        if self.after_id:
            try:
                self.root.after_cancel(self.after_id)
            except Exception:
                pass
            self.after_id = None
        if self.temp_wav and os.path.isfile(self.temp_wav):
            try:
                os.remove(self.temp_wav)
            except OSError:
                pass
        self.temp_wav = None
        if self.play_canvas and self.playhead:
            try:
                w = self.play_canvas.winfo_width()
                self.play_canvas.coords(self.playhead, 0, 0, 0, 0)
            except Exception:
                pass

    def _tick(self):
        if not self.playing or not self.play_canvas:
            return
        elapsed = __import__("time").monotonic() - self.play_start
        if elapsed >= self.play_dur:
            self._stop_audio()
            return
        w = self.play_canvas.winfo_width()
        x = int(elapsed / self.play_dur * w)
        h = self.play_canvas.winfo_height()
        self.play_canvas.coords(self.playhead, x, 0, x, h)
        self.after_id = self.root.after(40, self._tick)

    def _export_wav(self, res):
        p = filedialog.asksaveasfilename(
            title="Export PCM as WAV", defaultextension=".wav",
            initialfile=res["name"] + ".wav", filetypes=[("WAV", "*.wav")])
        if p:
            try:
                self._write_wav(res, p)
                self.status.configure(text="SILLY! // exported %s" % p)
            except Exception as e:
                messagebox.showerror("Export failed", str(e))

    def _preview_collision(self, res):
        self._meta_row(self.preview, [
            ("NAME", res["name"]), ("BOXES", len(res["boxes"])),
        ])
        wrap = ttk.Frame(self.preview)
        wrap.pack(fill="both", expand=True, padx=12, pady=8)
        canvas = tk.Canvas(wrap, bg=BG, highlightbackground=EDGE,
                           highlightthickness=1)
        canvas.pack(side="left", fill="both", expand=True)
        tree = ttk.Treeview(wrap, columns=("idx", "center", "half", "type"),
                            show="headings")
        for col, text, w in [("idx", "#", 40), ("center", "CENTER", 140),
                             ("half", "HALF", 140), ("type", "TYPE", 60)]:
            tree.heading(col, text=text)
            tree.column(col, width=w, anchor="w")
        tree.pack(side="left", fill="y")

        for i, b in enumerate(res["boxes"]):
            tree.insert("", "end", values=(i, str(b["center"]), str(b["half"]), b["type"]))

        boxes = res["boxes"]
        canvas.update_idletasks()
        w = max(200, canvas.winfo_width() - 20)
        h = max(200, canvas.winfo_height() - 20)
        if boxes:
            xs = [p["center"][0] for p in boxes]
            zs = [p["center"][2] for p in boxes]
            minx, maxx = min(xs), max(xs)
            minz, maxz = min(zs), max(zs)
            spanx = max(1.0, maxx - minx)
            spanz = max(1.0, maxz - minz)
            scale = min((w - 60) / spanx, (h - 60) / spanz)
            def px(x): return w / 2 + (x - (minx + maxx) / 2) * scale
            def py(z): return h / 2 + (z - (minz + maxz) / 2) * scale
            colors = [ACCENT, WARN, ACCENT2, "#7ec8ff"]
            for b in boxes:
                c, hf = b["center"], b["half"]
                x1, y1 = px(c[0] - hf[0]), py(c[2] - hf[2])
                x2, y2 = px(c[0] + hf[0]), py(c[2] + hf[2])
                col = colors[b["type"] % len(colors)]
                canvas.create_rectangle(x1, y1, x2, y2, outline=col, width=2)
                canvas.create_text((x1 + x2) / 2, (y1 + y2) / 2,
                                   text="t%d" % b["type"], fill=col,
                                   font=("Consolas", 9))
        else:
            canvas.create_text(w / 2, h / 2, text="no collision boxes",
                               fill=DIM, font=("Consolas", 11))

    def _preview_json(self, res, obj):
        clean_state = True
        text = tk.Text(self.preview, bg=BG, fg=TEXT, font=("Consolas", 10),
                       wrap="none", borderwidth=0, highlightthickness=0)
        text.pack(fill="both", expand=True, padx=12, pady=10)
        text.insert("end", json.dumps(obj, indent=2, ensure_ascii=False))
        text.configure(state="disabled")


# ---------------------------------------------------------------- entry
def main():
    root = tk.Tk()
    InspectorApp(root, sys.argv[1:])
    root.mainloop()


if __name__ == "__main__":
    main()
