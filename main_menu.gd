class_name MainMenu
extends Control
# Главное меню: Играть / Настройки / Выход.

signal play_pressed
signal quit_pressed

var _menu_box: VBoxContainer
var _settings: SettingsPanel


func _ready() -> void:
    UI.full_rect(self)
    var bg := ColorRect.new()
    bg.color = UI.BG
    UI.full_rect(bg)
    add_child(bg)
    var grad := Gradient.new()
    grad.colors = PackedColorArray([Color(0.1, 0.12, 0.18), Color(0.03, 0.03, 0.05)])
    var gt := GradientTexture2D.new()
    gt.gradient = grad
    gt.fill_from = Vector2(0.5, 0.0)
    gt.fill_to = Vector2(0.5, 1.0)
    var tr := TextureRect.new()
    tr.texture = gt
    tr.stretch_mode = TextureRect.STRETCH_SCALE
    UI.full_rect(tr)
    add_child(tr)

    var center := CenterContainer.new()
    UI.full_rect(center)
    add_child(center)
    _menu_box = VBoxContainer.new()
    _menu_box.add_theme_constant_override("separation", 16)
    _menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
    center.add_child(_menu_box)
    var title: Label = UI.label("POMILOR 3D", 72)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _menu_box.add_child(title)
    var sub: Label = UI.label("бета", 22, UI.ACCENT)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _menu_box.add_child(sub)
    _menu_box.add_child(Control.new())
    var b1: Button = UI.button("Играть", Vector2(360, 76), 30)
    b1.pressed.connect(_on_play)
    _menu_box.add_child(b1)
    var b2: Button = UI.button("Настройки", Vector2(360, 76), 30)
    b2.pressed.connect(_open_settings)
    _menu_box.add_child(b2)
    var b3: Button = UI.button("Выход", Vector2(360, 76), 30)
    b3.pressed.connect(func() -> void: quit_pressed.emit())
    _menu_box.add_child(b3)

    _settings = SettingsPanel.new(true)
    _settings.visible = false
    _settings.back_pressed.connect(_close_settings)
    center.add_child(_settings)


func _on_play() -> void:
    Sfx.play2d("click", -4.0)
    play_pressed.emit()


func _open_settings() -> void:
    Sfx.play2d("click", -4.0)
    _menu_box.visible = false
    _settings.visible = true


func _close_settings() -> void:
    _settings.visible = false
    _menu_box.visible = true
