extends Node
# Точка входа: главное меню -> загрузка -> игра.

var _layer: CanvasLayer
var _menu: MainMenu = null
var _loading: Loading = null
var _world: GameWorld = null


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _layer = CanvasLayer.new()
    _layer.layer = 50
    add_child(_layer)
    _show_menu()


func _show_menu() -> void:
    Game.reset()
    _menu = MainMenu.new()
    _menu.play_pressed.connect(_start_game)
    _menu.quit_pressed.connect(func() -> void: get_tree().quit())
    _layer.add_child(_menu)


func _start_game() -> void:
    if _menu != null:
        _menu.queue_free()
        _menu = null
    _loading = Loading.new()
    _layer.add_child(_loading)
    _world = GameWorld.new()
    _world.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(_world)
    _world.exit_requested.connect(_back_to_menu)
    await get_tree().process_frame
    await _world.build(_loading.set_progress)
    _loading.queue_free()
    _loading = null
    _world.start()


func _back_to_menu() -> void:
    if _world != null:
        _world.queue_free()
        _world = null
    Game.reset()
    await get_tree().process_frame
    _show_menu()
