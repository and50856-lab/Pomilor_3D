class_name InventoryMenu
extends Control
# Меню предметов: Оружия / Машины / Настройки.

signal closed

var _content: VBoxContainer
var _tab_btns: Array = []
var _tab: int = 0
var _opened_at: int = 0
var _fly_label: Label = null


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
    var names: Array = ["Оружия", "Машины", "NPC", "Админ панель", "Настройки"]
    for i in names.size():
        var b: Button = UI.button(str(names[i]), Vector2(190, 56), 24)
        b.pressed.connect(_show_tab.bind(i))
        top.add_child(b)
        _tab_btns.append(b)
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(sp)
    var close: Button = UI.button("Закрыть", Vector2(170, 56), 24)
    close.pressed.connect(_try_close)
    top.add_child(close)

    _content = VBoxContainer.new()
    _content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _content.alignment = BoxContainer.ALIGNMENT_CENTER
    _content.add_theme_constant_override("separation", 14)
    root.add_child(_content)
    _show_tab(0)


func open() -> void:
    _opened_at = Time.get_ticks_msec()
    _show_tab(_tab)


# Палец, нажавший «ВЕЩИ», отпускается уже над меню: первые доли секунды нажатия игнорируем.
func _just_opened() -> bool:
    return Time.get_ticks_msec() - _opened_at < 450


func _try_close() -> void:
    if _just_opened():
        return
    closed.emit()


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
            _build_npc()
        3:
            _build_admin()
        4:
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
    if _just_opened():
        return
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


func _admin_row(title: String, value: bool, cb: Callable) -> void:
    var h := HBoxContainer.new()
    h.alignment = BoxContainer.ALIGNMENT_CENTER
    h.add_theme_constant_override("separation", 20)
    var l: Label = UI.label(title, 24)
    l.custom_minimum_size = Vector2(430, 44)
    h.add_child(l)
    var sw := ToggleSwitch.new()
    sw.on = value
    sw.toggled.connect(cb)
    h.add_child(sw)
    _content.add_child(h)


func _build_admin() -> void:
    var t: Label = UI.label("АДМИН ПАНЕЛЬ", 30, UI.ACCENT)
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _content.add_child(t)
    _admin_row("Бессмертие", Game.admin_god, _on_god)
    _admin_row("Noclip (полёт сквозь всё)", Game.admin_noclip, _on_noclip)
    _admin_row("Бесконечные патроны", Game.admin_inf, _on_inf)
    _admin_row("Без перезарядки", Game.admin_noreload, _on_noreload)
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 4)
    _fly_label = UI.label("", 22, UI.ACCENT)
    _fly_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(_fly_label)
    var sl := HSlider.new()
    sl.min_value = 3.6
    sl.max_value = 66.0
    sl.step = 0.1
    sl.value = Game.fly_speed
    sl.custom_minimum_size = Vector2(620, 36)
    sl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    sl.value_changed.connect(_on_fly)
    box.add_child(sl)
    var cap: Label = UI.label("скорость полёта: от шага до 10× бега", 15, Color(1, 1, 1, 0.5))
    cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(cap)
    _content.add_child(box)
    _on_fly(Game.fly_speed)


func _on_god(on: bool) -> void:
    Game.admin_god = on
    if Game.player != null:
        Game.player.hp = 100.0


func _on_noclip(on: bool) -> void:
    Game.admin_noclip = on
    if Game.player != null:
        Game.player.call("set_noclip", on)


func _on_inf(on: bool) -> void:
    Game.admin_inf = on


func _on_noreload(on: bool) -> void:
    Game.admin_noreload = on


func _on_fly(v: float) -> void:
    Game.fly_speed = v
    if _fly_label != null:
        _fly_label.text = "%.1f м/с  (%d км/ч)" % [v, int(v * 3.6)]


func _build_npc() -> void:
    _content.add_child(_hint("Нажми на человека: он появится перед тобой и пойдёт по своим делам."))
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 18)
    _content.add_child(row)
    var card := Card.new()
    card.kind = "npc"
    card.item_id = "ordinary"
    card.title = "Ordinary NPC"
    card.sub = "Обычный прохожий"
    card.custom_minimum_size = Vector2(280, 270)
    card.pressed.connect(_on_npc.bind("ordinary"))
    row.add_child(card)


func _on_npc(kind: String) -> void:
    if _just_opened():
        return
    if Game.player != null:
        Game.player.call("spawn_npc", kind)
    closed.emit()


func _on_car(id: String) -> void:
    if _just_opened():
        return
    if Game.player != null:
        Game.player.call("spawn_vehicle", id)
    closed.emit()


func _on_drop() -> void:
    if _just_opened():
        return
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
