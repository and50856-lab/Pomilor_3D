class_name NPCManager
extends Node
# Пешеходы вокруг игрока: появляются рядом (вне поля зрения), далёкие исчезают.

var target: int = 18
var _t: float = 0.0


func _process(delta: float) -> void:
    if not Game.running:
        return
    _t -= delta
    if _t > 0.0:
        return
    _t = 0.5
    var pl: Node3D = Game.player as Node3D
    if pl == null:
        return
    var cam: Camera3D = pl.get_viewport().get_camera_3d()
    var near: int = 0
    for p in get_tree().get_nodes_in_group("peds"):
        var n3: Node3D = p as Node3D
        if n3 == null or not is_instance_valid(n3):
            continue
        var dd: float = Vector2(n3.global_position.x - pl.global_position.x, n3.global_position.z - pl.global_position.z).length()
        if dd > 250.0 and (cam == null or not cam.is_position_in_frustum(n3.global_position)):
            n3.queue_free()
            continue
        if dd < 200.0:
            near += 1
    var need: int = mini(target - near, 3)
    for i in maxi(need, 0):
        spawn_one(true)


func spawn_one(away: bool) -> bool:
    var net: PedNet = Game.ped_net
    if net == null or net.pts.is_empty():
        return false
    var pl: Node3D = Game.player as Node3D
    var cam: Camera3D = null
    if pl != null:
        cam = pl.get_viewport().get_camera_3d()
    var dmin: float = 45.0 if away else 12.0
    for attempt in 40:
        var a: int = randi() % net.pts.size()
        var adj: Array = net.adj[a]
        if adj.is_empty():
            continue
        var b: int = adj[randi() % adj.size()]
        if net.edge_cross(a, b) >= 0:
            continue
        var t: float = randf()
        var p: Vector3 = (net.pts[a] as Vector3).lerp(net.pts[b], t)
        if pl != null:
            var dist: float = Vector2(p.x - pl.global_position.x, p.z - pl.global_position.z).length()
            if dist < dmin or dist > 170.0:
                continue
            if away and dist < 110.0 and cam != null and cam.is_position_in_frustum(p + Vector3(0, 1, 0)):
                continue
        var npc: NPC = NPC.create()
        Game.world.add_child(npc)
        npc.start_on_edge(a, b, t)
        return true
    return false
