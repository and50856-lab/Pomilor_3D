class_name NPCManager
extends Node
# Поддерживает нужное количество пешеходов на тротуарах.

var target: int = 18
var _t: float = 0.0


func _process(delta: float) -> void:
    if not Game.running:
        return
    _t -= delta
    if _t <= 0.0:
        _t = 1.5
        if get_tree().get_nodes_in_group("peds").size() < target:
            spawn_one(true)


func spawn_one(away: bool) -> bool:
    var net: PedNet = Game.ped_net
    if net == null or net.pts.is_empty():
        return false
    var pl: Node3D = Game.player as Node3D
    for attempt in 12:
        var a: int = randi() % net.pts.size()
        var adj: Array = net.adj[a]
        if adj.is_empty():
            continue
        var b: int = adj[randi() % adj.size()]
        if net.edge_cross(a, b) >= 0:
            continue
        var t: float = randf()
        var p: Vector3 = (net.pts[a] as Vector3).lerp(net.pts[b], t)
        if pl != null and away and pl.global_position.distance_to(p) < 30.0:
            continue
        var npc: NPC = NPC.create()
        Game.world.add_child(npc)
        npc.start_on_edge(a, b, t)
        return true
    return false
