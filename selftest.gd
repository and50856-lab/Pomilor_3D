extends Node
# Запуск игры без экрана: проверяет, что все скрипты компилируются и основные сценарии не падают.
# Запуск: godot --headless --path . res://selftest.tscn

var _prog: Array = [0.0]


func _ready() -> void:
    get_tree().create_timer(200.0).timeout.connect(_watchdog)
    _run()


func _watchdog() -> void:
    print("SELFTEST_TIMEOUT")
    get_tree().quit(1)


func _wait(sec: float) -> void:
    await get_tree().create_timer(sec).timeout


func _on_progress(v: float, _t: String) -> void:
    _prog[0] = v


func _run() -> void:
    await get_tree().process_frame
    print("SELFTEST: старт, Godot ", Engine.get_version_info()["string"], ", рендер: ", RenderingServer.get_current_rendering_method())
    var bad: int = 0
    for f in DirAccess.get_files_at("res://"):
        if f.ends_with(".gd") and f != "selftest.gd":
            var s: Resource = load("res://" + f)
            if s == null or (s is GDScript and not (s as GDScript).can_instantiate()):
                print("SCRIPT ERROR: не компилируется ", f)
                bad += 1
    print("SELFTEST: скриптов с ошибками: ", bad)

    # настройки: все уровни графики
    for g in 5:
        Settings.graphics = g
        Settings.shadows = g
        Settings.view_distance = g
        Settings.aa = g
        Settings.aniso = g
        Settings.fps_idx = g
        Settings.apply_all()
    Settings.graphics = 2
    Settings.shadows = 2
    Settings.view_distance = 2
    Settings.aa = 1
    Settings.aniso = 2
    Settings.fps_idx = 7
    Settings.apply_all()
    print("SELFTEST: настройки применены")

    # меню
    var mm := MainMenu.new()
    add_child(mm)
    var ld := Loading.new()
    add_child(ld)
    ld.set_progress(0.5, "тест")
    await get_tree().process_frame
    mm.queue_free()
    ld.queue_free()
    print("SELFTEST: меню созданы")

    # мир
    var world := GameWorld.new()
    add_child(world)
    await world.build(_on_progress)
    world.start()
    print("SELFTEST: мир построен, прогресс=", _prog[0])
    await _wait(2.0)
    var p: Player = Game.player
    print("SELFTEST: NPC=", get_tree().get_nodes_in_group("npcs").size(), " машин=", get_tree().get_nodes_in_group("vehicles").size())

    # интерфейс
    var inv: InventoryMenu = world.inv_menu
    inv.visible = true
    for i in 3:
        inv._show_tab(i)
        await get_tree().process_frame
    inv.visible = false
    world._open_pause()
    await get_tree().process_frame
    world._resume()
    print("SELFTEST: меню предметов и пауза работают")
    print("SELFTEST: размер HUD: ", world.hud.size)
    if world.hud.size.x < 200.0 or world.hud.size.y < 100.0:
        print("SCRIPT ERROR: HUD имеет нулевой размер")

    # оружие
    for id in WeaponDefs.ORDER:
        Game.give_weapon(id)
        Game.equip(id)
        await _wait(0.2)
        Ctl.t_fire = true
        await _wait(0.5)
        Ctl.t_fire = false
        p.start_reload()
        await _wait(0.3)
    Game.equip("ak47")
    p.third = true
    p._apply_view_mode()
    Ctl.t_fire = true
    await _wait(0.4)
    Ctl.t_fire = false
    p.third = false
    p._apply_view_mode()
    Ctl.action.emit("drop")
    await _wait(1.0)
    print("SELFTEST: оружие и выбрасывание прошли")

    # круговое меню
    var hud: Hud = world.hud
    hud._open_wheel()
    await get_tree().process_frame
    hud.close_wheel()
    await get_tree().process_frame

    # реакции NPC
    var npcs: Array = get_tree().get_nodes_in_group("npcs")
    if npcs.size() >= 3:
        var n1: NPC = npcs[0]
        var n2: NPC = npcs[1]
        var n3: NPC = npcs[2]
        n1.take_hit("torso", 20.0, Vector3.FORWARD, p)
        n2.take_hit("leg", 20.0, Vector3.FORWARD, p)
        n3.take_hit("head", 60.0, Vector3.FORWARD, p)
        Game.gunshot.emit(p.global_position, 130.0)
    await _wait(2.0)
    Combat.explode(p.global_position + Vector3(8, 0, 8), 9.0, 260.0, p)
    await _wait(1.0)
    print("SELFTEST: реакции NPC и взрыв прошли")

    # машины
    for id in VehicleDefs.ORDER:
        p.spawn_vehicle(id)
        await _wait(1.0)
    p.spawn_vehicle("gallardo")
    await _wait(2.5)
    p._find_targets()
    p.interact()
    await _wait(2.8)
    print("SELFTEST: игрок в машине: ", p.in_vehicle != null)
    if p.in_vehicle != null:
        Ctl.t_gas = true
        await _wait(3.0)
        Ctl.t_left = true
        await _wait(1.5)
        Ctl.t_left = false
        Ctl.t_gas = false
        Ctl.t_rev = true
        await _wait(1.0)
        Ctl.t_rev = false
        print("SELFTEST: скорость машины=", p.in_vehicle.speed_ms)
        Ctl.action.emit("cam")
        await _wait(0.5)
        Ctl.action.emit("horn")
        Ctl.action.emit("interact")
        await _wait(2.0)
    print("SELFTEST: игрок вышел: ", p.in_vehicle == null)

    # угон у водителя
    var tr: TrafficManager = world.traffic
    if tr.cars.size() > 0:
        var car: Vehicle = tr.cars[0]
        p.global_position = car.global_position + Vector3(3.0, 0.3, 0.0)
        await _wait(0.6)
        p._find_targets()
        print("SELFTEST: подсказка: ", Game.prompt)
        p.interact()
        await _wait(3.0)
        print("SELFTEST: угнал: ", p.in_vehicle != null)
        Ctl.t_gas = true
        await _wait(2.0)
        Ctl.t_gas = false
        Ctl.action.emit("interact")
        await _wait(8.0)

    # повреждения машин, карта, спавн NPC
    p.spawn_vehicle("vaz")
    await _wait(2.0)
    var near_v: Vehicle = null
    var bd: float = 1e9
    for n in get_tree().get_nodes_in_group("vehicles"):
        var vv: Vehicle = n as Vehicle
        if vv != null and vv.mode == Vehicle.Mode.PARKED:
            var dd: float = vv.global_position.distance_to(p.global_position)
            if dd < bd:
                bd = dd
                near_v = vv
    if near_v != null:
        near_v.tire_hit(0, 100.0)
        near_v.shot(near_v.global_position + Vector3(0, 1.0, 0), Vector3.FORWARD, 60.0)
        near_v.ignite(0.4)
        await _wait(2.5)
        print("SELFTEST: машина взорвана: ", near_v.wrecked)
    p.spawn_npc("ordinary")
    hud._open_map()
    await get_tree().process_frame
    hud.close_map()
    var phys_n: int = 0
    for c in world.traffic.cars:
        if is_instance_valid(c) and (c as Vehicle).mode == Vehicle.Mode.AI_PHYS:
            phys_n += 1
    print("SELFTEST: повреждения, карта, спавн NPC прошли; физических машин трафика: ", phys_n)

    # админ-режимы, метание, нокдаун
    Game.admin_noclip = true
    p.set_noclip(true)
    Ctl.t_move = Vector2(0.0, -1.0)
    await _wait(0.6)
    Ctl.t_move = Vector2.ZERO
    Game.admin_noclip = false
    p.set_noclip(false)
    Game.admin_god = true
    Game.admin_inf = true
    Game.admin_noreload = true
    Game.give_weapon("ak47")
    Game.equip("ak47")
    Ctl.t_fire = true
    await _wait(0.5)
    Ctl.t_fire = false
    Game.admin_god = false
    Game.admin_inf = false
    Game.admin_noreload = false
    Game.give_weapon("bat")
    Game.equip("bat")
    p.throw_weapon(1.0)
    await _wait(1.5)
    var kn: Array = get_tree().get_nodes_in_group("npcs")
    if kn.size() > 0:
        (kn[0] as NPC).knock_down(Vector3(3, 2, 0), 1.5)
        await _wait(4.0)
    print("SELFTEST: админ-режимы, метание, нокдаун прошли")

    # просто идём и смотрим на мир
    Ctl.t_move = Vector2(0.0, -1.0)
    Ctl.t_run = true
    Ctl.look = Vector2(40.0, 10.0)
    Ctl.action.emit("jump")
    await _wait(3.0)
    Ctl.t_move = Vector2.ZERO
    Ctl.t_run = false
    await _wait(6.0)
    print("SELFTEST: NPC=", get_tree().get_nodes_in_group("npcs").size(), " машин трафика=", tr.cars.size(), " FPS=", Engine.get_frames_per_second())
    print("SELFTEST_OK")
    get_tree().quit(0)
