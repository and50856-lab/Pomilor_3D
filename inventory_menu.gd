class_name InventoryMenu
extends Control
# Меню предметов: Оружия / Машины / Настройки.

signal closed

var _content: VBoxContainer
var _tab_btns: Array = []
var _tab: int = 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    UI.full_rect(self)
    var dim := ColorRect.new()
    dim.color = Color(0.03, 0.03, 0.05, 0.93)
    UI.full_rect(dim)
    add_child(dim)
    var margin := MarginContainer.new()
    UI.full_rect(margin)
    margin.add_theme_constant_override("margin_left", 36)
    margin.add_theme_constant_override("margin_right", 36)
    margin.add_theme_constant_override("margin_top", 22)
    margin.add_theme_constant_override("margin_bottom", 22)
    add_child(margin)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 14)
    margin.add_child(root)

    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 10)
    root.add_child(top)
    var names: Array = ["Оружия", "Машины", "Настройки"]
    for i in names.size():
        var b: Button = UI.button(str(names[i]), Vector2(190, 56), 24)
        b.pressed.connect(_show_tab.bind(i))
        top.add_child(b)
        _tab_btns.append(b)
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(sp)
    var close: Button = UI.button("Закрыть", Vector2(170, 56), 24)
    close.pressed.connect(func() -> void: closed.emit())
    top.add_child(close)

    _content = VBoxContainer.new()
    _content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _content.alignment = BoxContainer.ALIGNMENT_CENTER
    _content.add_theme_constant_override("separation", 14)
    root.add_child(_content)
    _show_tab(0)


func open() -> void:
    _show_tab(_tab)


func _clear() -> void:
    for c in _content.get_children():
        c.queue_free()


func _show_tab(i: int) -> void:
    _tab = i
    for j in _tab_btns.size():
        (_tab_btns[j] as Button).modulate = Color(1, 1, 1) if j == i else Color(0.65, 0.65, 0.7)
    _clear()
    match i:
        0:
            _build_weapons()
        1:
            _build_cars()
        2:
            _build_settings()


func _hint(text: String) -> Label:
    var l: Label = UI.label(text, 19, Color(1, 1, 1, 0.6))
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return l


func _build_weapons() -> void:
    _content.add_child(_hint("Нажми на оружие, чтобы взять его. Переключать оружие в игре — кнопкой с иконкой сверху (круговое меню)."))
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 14)
    _content.add_child(row)
    for id in WeaponDefs.ORDER:
        var wd: Dictionary = WeaponDefs.get_def(str(id))
        var card := Card.new()
        card.kind = "weapon"
        card.item_id = str(id)
        card.title = str(wd["name"])
        card.custom_minimum_size = Vector2(214, 270)
        _update_weapon_card(card)
        card.pressed.connect(_on_weapon.bind(card))
        row.add_child(card)


func _update_weapon_card(card: Card) -> void:
    card.marked = Game.owned.has(card.item_id)
    card.sub = "В инвентаре" if card.marked else "Нажми, чтобы взять"
    card.refresh()


func _on_weapon(card: Card) -> void:
    Game.give_weapon(card.item_id)
    Game.equip(card.item_id)
    Sfx.play2d("pickup")
    _update_weapon_card(card)


func _build_cars() -> void:
    _content.add_child(_hint("Нажми на машину — она появится рядом с тобой, на земле."))
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 18)
    _content.add_child(row)
    for id in VehicleDefs.ORDER:
        var d: Dictionary = VehicleDefs.get_def(str(id))
        var card := Card.new()
        card.kind = "car"
        card.item_id = str(id)
        card.title = str(d["name"])
        card.sub = "Нажми, чтобы вызвать"
        card.custom_minimum_size = Vector2(320, 270)
        card.pressed.connect(_on_car.bind(str(id)))
        row.add_child(card)


func _on_car(id: String) -> void:
    if Game.player != null:
        Game.player.call("spawn_vehicle", id)
    closed.emit()


func _on_drop() -> void:
    Ctl.action.emit("drop")
    closed.emit()


func _build_settings() -> void:
    var sp := SettingsPanel.new(false)
    _content.add_child(sp)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 12)
    _content.add_child(row)
    var cam: Button = UI.button("Вид: 1-е / 3-е лицо", Vector2(300, 52), 21)
    cam.pressed.connect(func() -> void: Ctl.action.emit("cam"))
    row.add_child(cam)
    var drop: Button = UI.button("Выбросить оружие", Vector2(300, 52), 21)
    drop.pressed.connect(_on_drop)
    row.add_child(drop)
