class_name SettingsPanel
extends VBoxContainer
# Панель настроек: графика, тени, дальность, сглаживание, анизотропия, bloom, лимит FPS + игровые.

signal back_pressed

var _vals: Dictionary = {}
var _show_back: bool = true

const ROWS_G: Array = [
    ["graphics", "Графика"], ["shadows", "Тени"], ["view", "Дальность прорисовки"],
    ["aa", "Сглаживание"], ["aniso", "Анизотропная фильтрация"], ["bloom", "Bloom"], ["fps", "Ограничение FPS"],
]
const ROWS_P: Array = [
    ["sens", "Чувствительность камеры"], ["fov", "Угол обзора (FOV)"], ["showfps", "Показывать FPS"],
]


func _init(show_back: bool = true) -> void:
    _show_back = show_back


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_theme_constant_override("separation", 8)
    alignment = BoxContainer.ALIGNMENT_CENTER
    add_child(UI.label("НАСТРОЙКИ", 34, UI.ACCENT))
    add_child(UI.label("Графика", 20, Color(0.7, 0.75, 0.85)))
    add_child(_grid(ROWS_G))
    add_child(UI.label("Игра", 20, Color(0.7, 0.75, 0.85)))
    add_child(_grid(ROWS_P))
    if _show_back:
        var b: Button = UI.button("Назад", Vector2(240, 56), 24)
        b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        b.pressed.connect(_on_back)
        add_child(b)
    _refresh()


func _on_back() -> void:
    Settings.save_settings()
    back_pressed.emit()


func _grid(rows: Array) -> GridContainer:
    var g := GridContainer.new()
    g.columns = 2
    g.add_theme_constant_override("h_separation", 28)
    g.add_theme_constant_override("v_separation", 6)
    for r in rows:
        g.add_child(_row(str(r[0]), str(r[1])))
    return g


func _row(id: String, title: String) -> Control:
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 6)
    var t: Label = UI.label(title, 19)
    t.custom_minimum_size = Vector2(250, 44)
    h.add_child(t)
    var l: Button = UI.button("<", Vector2(46, 44), 22)
    l.pressed.connect(_cycle.bind(id, -1))
    h.add_child(l)
    var v: Label = UI.label("", 19, UI.ACCENT)
    v.custom_minimum_size = Vector2(150, 44)
    v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    h.add_child(v)
    var r: Button = UI.button(">", Vector2(46, 44), 22)
    r.pressed.connect(_cycle.bind(id, 1))
    h.add_child(r)
    _vals[id] = v
    return h


func _cycle(id: String, dir: int) -> void:
    match id:
        "graphics":
            Settings.graphics = wrapi(Settings.graphics + dir, 0, 5)
        "shadows":
            Settings.shadows = wrapi(Settings.shadows + dir, 0, 5)
        "view":
            Settings.view_distance = wrapi(Settings.view_distance + dir, 0, 5)
        "aa":
            Settings.aa = wrapi(Settings.aa + dir, 0, 5)
        "aniso":
            Settings.aniso = wrapi(Settings.aniso + dir, 0, 5)
        "bloom":
            Settings.bloom = not Settings.bloom
        "fps":
            Settings.fps_idx = wrapi(Settings.fps_idx + dir, 0, Settings.FPS_VALUES.size())
        "sens":
            Settings.sensitivity = clampf(snappedf(Settings.sensitivity + 0.1 * float(dir), 0.1), 0.3, 2.5)
        "fov":
            Settings.fov = clampf(Settings.fov + 5.0 * float(dir), 60.0, 100.0)
        "showfps":
            Settings.show_fps = not Settings.show_fps
    Settings.apply_all()
    Settings.save_settings()
    Sfx.play2d("click", -6.0)
    _refresh()


func _text(id: String) -> String:
    match id:
        "graphics":
            return Settings.LEVELS[Settings.graphics]
        "shadows":
            return Settings.LEVELS[Settings.shadows]
        "view":
            return Settings.LEVELS[Settings.view_distance]
        "aa":
            return Settings.AA_NAMES[Settings.aa]
        "aniso":
            return Settings.ANISO_NAMES[Settings.aniso]
        "bloom":
            return "Вкл" if Settings.bloom else "Выкл"
        "fps":
            return Settings.FPS_NAMES[Settings.fps_idx]
        "sens":
            return "%.1f" % Settings.sensitivity
        "fov":
            return "%d" % int(Settings.fov)
        "showfps":
            return "Да" if Settings.show_fps else "Нет"
    return ""


func _refresh() -> void:
    for id in _vals.keys():
        (_vals[id] as Label).text = _text(str(id))
