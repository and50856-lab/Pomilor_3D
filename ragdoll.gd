class_name Ragdoll
extends Node3D
# Физическая тряпичная кукла: тело человека из 11 твёрдых сегментов, соединённых шарнирами.
# Машина отбрасывает его, он катится по капоту и земле. Либо остаётся лежать (смерть),
# либо через несколько секунд встаёт (нокдаун от удара машиной, взрыва, тяжёлого попадания).

static var count: int = 0

var rig: Humanoid = null
var owner_npc = null
var parts: Array = []
var pos_rest: Dictionary = {}
var t: float = 0.0
var getup_t: float = -1.0
var life: float = 25.0


static func can_spawn() -> bool:
    return count < int(Settings.RAGDOLL_CAP[Settings.graphics])


static func make(rig_: Humanoid, vel: Vector3, push: Vector3, getup_after: float, npc_ref) -> Ragdoll:
    var r := Ragdoll.new()
    Game.world.add_child(r)
    var gt: Transform3D = rig_.global_transform
    var old: Node = rig_.get_parent()
    if old != null:
        old.remove_child(rig_)
    r.add_child(rig_)
    rig_.global_transform = gt
    r.rig = rig_
    r.owner_npc = npc_ref
    r.getup_t = getup_after
    rig_.dead = true
    rig_.hands_up = false
    rig_.disable_lod()
    # [узел-шарнир, смещение центра сегмента, форма, размеры, масса, индекс родителя]
    var defs: Array = [
        [rig_.hips, Vector3(0, 0.0, 0), "box", Vector3(0.32, 0.2, 0.2), 12.0, -1],
        [rig_.torso, Vector3(0, 0.30, 0), "box", Vector3(0.38, 0.56, 0.22), 26.0, 0],
        [rig_.head, Vector3(0, 0.12, 0), "sphere", Vector3(0.12, 0, 0), 5.0, 1],
        [rig_.arm_l, Vector3(0, -0.15, 0), "cap", Vector3(0.055, 0.32, 0), 2.5, 1],
        [rig_.fore_l, Vector3(0, -0.14, 0), "cap", Vector3(0.048, 0.30, 0), 1.8, 3],
        [rig_.arm_r, Vector3(0, -0.15, 0), "cap", Vector3(0.055, 0.32, 0), 2.5, 1],
        [rig_.fore_r, Vector3(0, -0.14, 0), "cap", Vector3(0.048, 0.30, 0), 1.8, 5],
        [rig_.leg_l, Vector3(0, -0.22, 0), "cap", Vector3(0.08, 0.46, 0), 8.0, 0],
        [rig_.shin_l, Vector3(0, -0.22, 0), "cap", Vector3(0.065, 0.46, 0), 5.0, 7],
        [rig_.leg_r, Vector3(0, -0.22, 0), "cap", Vector3(0.08, 0.46, 0), 8.0, 0],
        [rig_.shin_r, Vector3(0, -0.22, 0), "cap", Vector3(0.065, 0.46, 0), 5.0, 9],
    ]
    for d in defs:
        var pv: Node3D = d[0]
        r.pos_rest[pv] = pv.position
        var rb := RigidBody3D.new()
        rb.collision_layer = Const.L_BODY
        rb.collision_mask = Const.L_WORLD | Const.L_VEH
        rb.mass = float(d[4])
        rb.linear_damp = 0.25
        rb.angular_damp = 3.0
        var cs := CollisionShape3D.new()
        var kind: String = str(d[2])
        var sz: Vector3 = d[3]
        if kind == "box":
            var bs := BoxShape3D.new()
            bs.size = sz
            cs.shape = bs
        elif kind == "sphere":
            var ss := SphereShape3D.new()
            ss.radius = sz.x
            cs.shape = ss
        else:
            var cp := CapsuleShape3D.new()
            cp.radius = sz.x
            cp.height = sz.y
            cs.shape = cp
        rb.add_child(cs)
        r.add_child(rb)
        rb.global_transform = pv.global_transform * Transform3D(Basis.IDENTITY, d[1])
        rb.linear_velocity = vel + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.4), randf_range(-0.3, 0.3))
        rb.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0), randf_range(-2.0, 2.0))
        r.parts.append({"pv": pv, "rb": rb, "off": d[1], "parent": int(d[5])})
    for i in range(1, r.parts.size()):
        var pp: Dictionary = r.parts[i]
        var pi_: int = int(pp["parent"])
        if pi_ < 0:
            continue
        var j := PinJoint3D.new()
        r.add_child(j)
        j.global_position = (pp["pv"] as Node3D).global_position
        j.node_a = j.get_path_to(r.parts[pi_]["rb"])
        j.node_b = j.get_path_to(pp["rb"])
    if push.length() > 0.1:
        ((r.parts[1] as Dictionary)["rb"] as RigidBody3D).apply_central_impulse(push)
    count += 1
    return r


func _exit_tree() -> void:
    count = maxi(0, count - 1)


func _physics_process(delta: float) -> void:
    t += delta
    for pp in parts:
        var rb: RigidBody3D = pp["rb"]
        var pv: Node3D = pp["pv"]
        pv.global_transform = rb.global_transform * Transform3D(Basis.IDENTITY, -(pp["off"] as Vector3))
    if getup_t > 0.0:
        if t >= getup_t:
            _get_up()
    elif t > life:
        queue_free()


func _get_up() -> void:
    var npc = owner_npc
    if npc == null or not is_instance_valid(npc):
        queue_free()
        return
    var hips_rb: RigidBody3D = parts[0]["rb"]
    var pos: Vector3 = hips_rb.global_position
    var tb: Basis = (parts[1]["rb"] as RigidBody3D).global_transform.basis
    var f: Vector3 = -tb.z
    f.y = 0.0
    var yaw: float = 0.0
    if f.length() > 0.2:
        yaw = atan2(-f.x, -f.z)
    var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1.0, 0), pos - Vector3(0, 4.0, 0), Const.L_WORLD)
    var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
    var gy: float = pos.y
    if not h.is_empty():
        var hp_: Vector3 = h["position"]
        gy = hp_.y
    var old: Node = rig.get_parent()
    if old != null:
        old.remove_child(rig)
    (npc as Node3D).add_child(rig)
    for pp in parts:
        var pv: Node3D = pp["pv"]
        pv.position = pos_rest[pv]
        pv.rotation = Vector3.ZERO
    rig.position = Vector3.ZERO
    rig.rotation = Vector3(0.0, yaw, 0.0)
    rig.dead = false
    npc.call("recovered", Vector3(pos.x, gy + 0.05, pos.z), yaw)
    queue_free()
