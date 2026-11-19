class_name PauseMenu
extends Control
# Пауза: вернуться в игру / настройки / выход.

signal resume_pressed
signal exit_pressed

var _box: VBoxContainer
var _settings: SettingsPanel


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    UI.full_rect(self)
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.72)
    UI.full_rect(dim)
    add_child(dim)
    var center := CenterContainer.new()
    UI.full_rect(center)
    add_child(center)
    _box = VBoxContainer.new()
    _box.add_theme_constant_override("separation", 16)
    center.add_child(_box)
    var t: Label = UI.label("ПАУЗА", 52)
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _box.add_child(t)
    var b1: Button = UI.button("Вернуться в игру", Vector2(380, 70), 28)
    b1.pressed.connect(func() -> void: resume_pressed.emit())
    _box.add_child(b1)
    var b2: Button = UI.button("Настройки", Vector2(380, 70), 28)
    b2.pressed.connect(_on_settings)
    _box.add_child(b2)
    var b3: Button = UI.button("Выход", Vector2(380, 70), 28)
    b3.pressed.connect(func() -> void: exit_pressed.emit())
    _box.add_child(b3)
    _settings = SettingsPanel.new(true)
    _settings.visible = false
    _settings.back_pressed.connect(reset_view)
    center.add_child(_settings)


func _on_settings() -> void:
    _box.visible = false
    _settings.visible = true


func reset_view() -> void:
    _box.visible = true
    _settings.visible = false
