extends Control

signal resume_requested
signal settings_requested
signal menu_requested
signal quit_requested

const UI := preload("res://scripts/ui_utils.gd")

func _ready() -> void:
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build()

var _open_frame := -1

func notify_opened() -> void:
    _open_frame = Engine.get_process_frames()

func _unhandled_input(e: InputEvent) -> void:
    if visible and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
        # ignore the same Esc event that opened us
        if Engine.get_process_frames() <= _open_frame:
            return
        get_viewport().set_input_as_handled()
        resume_requested.emit()

func _build() -> void:
    add_child(UI.dim(Color(0.02, 0.03, 0.05, 0.62)))

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(340, 0)
    panel.add_theme_stylebox_override("panel", UI.panel_style())
    center.add_child(panel)

    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 14)
    panel.add_child(v)

    var title := UI.label("PAUSED", 28, Color(0.88, 0.92, 1.0))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(title)

    var sep := HSeparator.new()
    sep.modulate = Color(1, 1, 1, 0.35)
    v.add_child(sep)

    var specs: Array = [
        ["RESUME", resume_requested],
        ["SETTINGS", settings_requested],
        ["MAIN MENU", menu_requested],
        ["QUIT", quit_requested],
    ]
    for spec in specs:
        var b := Button.new()
        b.text = spec[0]
        b.custom_minimum_size = Vector2(0, 46)
        UI.style_button(b, 18)
        b.pressed.connect((spec[1] as Signal).emit)
        v.add_child(b)
