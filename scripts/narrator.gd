extends Node

var subtitle_label: Label
var queue: Array = []
var current := ""
var shown := 0.0
var hold := 0.0
var typing := false
var _fade_tw: Tween

func say(t: String) -> void:
    if not Settings.subtitles:
        return
    queue.append(t)

func _start_line() -> void:
    if _fade_tw != null and _fade_tw.is_valid():
        _fade_tw.kill()
    subtitle_label.modulate.a = 1.0
    current = str(queue.pop_front())
    shown = 0.0
    hold = 0.0
    typing = true

func _finish_line() -> void:
    typing = false
    if _fade_tw != null and _fade_tw.is_valid():
        _fade_tw.kill()
    _fade_tw = subtitle_label.create_tween()
    _fade_tw.tween_property(subtitle_label, "modulate:a", 0.0, 0.5)
    _fade_tw.tween_callback(_clear)

func _clear() -> void:
    subtitle_label.text = ""

func _process(delta: float) -> void:
    if subtitle_label == null:
        return
    if typing:
        if shown < current.length():
            shown += delta * 42.0
            var n := int(min(shown, current.length()))
            subtitle_label.text = current.substr(0, n)
        else:
            hold += delta
            if hold > 2.6:
                _finish_line()
    elif queue.size() > 0:
        _start_line()
