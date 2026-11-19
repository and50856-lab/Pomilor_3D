extends Node
# Звук (автозагрузка "Sfx"). Все звуки синтезируются кодом; потом можно заменить на свои файлы.

const RATE: int = 22050
const NAMES: Array = [
    "step", "jump", "land", "door_open", "door_close", "deagle", "rifle", "shotgun", "pump",
    "rpg", "explosion", "reload", "empty", "swing", "punch", "bat_hit", "pain", "scream",
    "horn", "crash", "pickup", "click", "engine", "skid",
]

var sounds: Dictionary = {}
var _gen_i: int = 0
var _pool3d: Array = []
var _pool2d: Array = []
var _i3: int = 0
var _i2: int = 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for i in 18:
        var p := AudioStreamPlayer3D.new()
        p.unit_size = 8.0
        p.max_distance = 90.0
        add_child(p)
        _pool3d.append(p)
    for i in 6:
        var q := AudioStreamPlayer.new()
        add_child(q)
        _pool2d.append(q)


func total() -> int:
    return NAMES.size()


func progress() -> float:
    return float(_gen_i) / float(NAMES.size())


# Генерирует по одному звуку за вызов. true — всё готово.
func generate_next() -> bool:
    if _gen_i >= NAMES.size():
        return true
    var n: String = NAMES[_gen_i]
    sounds[n] = _synth(n)
    _gen_i += 1
    return _gen_i >= NAMES.size()


func play2d(n: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
    if not sounds.has(n) or _pool2d.is_empty():
        return
    var p: AudioStreamPlayer = _pool2d[_i2]
    _i2 = (_i2 + 1) % _pool2d.size()
    p.stream = sounds[n]
    p.volume_db = vol_db
    p.pitch_scale = pitch
    p.play()


func play3d(n: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0, max_dist: float = 90.0) -> void:
    if not sounds.has(n) or _pool3d.is_empty():
        return
    var p: AudioStreamPlayer3D = _pool3d[_i3]
    _i3 = (_i3 + 1) % _pool3d.size()
    p.stream = sounds[n]
    p.global_position = pos
    p.volume_db = vol_db
    p.pitch_scale = pitch
    p.max_distance = max_dist
    p.unit_size = 8.0 + max_dist * 0.06
    p.play()


func make_loop_player(n: String, parent: Node, max_dist: float = 60.0) -> AudioStreamPlayer3D:
    var p := AudioStreamPlayer3D.new()
    if sounds.has(n):
        p.stream = sounds[n]
    p.max_distance = max_dist
    p.unit_size = 6.0
    parent.add_child(p)
    return p


# ---------- синтез ----------

func _buf(dur: float) -> PackedFloat32Array:
    var a := PackedFloat32Array()
    a.resize(int(dur * float(RATE)))
    return a


func _noise(buf: PackedFloat32Array, start: float, dur: float, amp: float, decay: float, lp: float, window: bool = false) -> PackedFloat32Array:
    var s0: int = int(start * float(RATE))
    var n: int = int(dur * float(RATE))
    var y: float = 0.0
    for i in n:
        if s0 + i >= buf.size():
            break
        var t: float = float(i) / float(RATE)
        y += lp * (randf_range(-1.0, 1.0) - y)
        var env: float = sin(PI * t / dur) if window else exp(-t * decay)
        buf[s0 + i] += y * amp * env
    return buf


func _tone(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float, decay: float, shape: int = 0) -> PackedFloat32Array:
    var s0: int = int(start * float(RATE))
    var n: int = int(dur * float(RATE))
    var ph: float = 0.0
    for i in n:
        if s0 + i >= buf.size():
            break
        var t: float = float(i) / float(RATE)
        var f: float = lerpf(f0, f1, t / dur)
        ph += TAU * f / float(RATE)
        var v: float = 0.0
        if shape == 0:
            v = sin(ph)
        elif shape == 1:
            v = fposmod(ph / TAU, 1.0) * 2.0 - 1.0
        else:
            v = signf(sin(ph))
        var fade: float = minf(1.0, (dur - t) * 40.0)
        buf[s0 + i] += v * amp * exp(-t * decay) * fade
    return buf


func _to_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
    var bytes := PackedByteArray()
    bytes.resize(samples.size() * 2)
    for i in samples.size():
        var v: int = clampi(int(samples[i] * 30000.0), -32768, 32767)
        bytes.encode_s16(i * 2, v)
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = RATE
    w.stereo = false
    w.data = bytes
    if loop:
        w.loop_mode = AudioStreamWAV.LOOP_FORWARD
        w.loop_begin = 0
        w.loop_end = samples.size()
    return w


func _synth(n: String) -> AudioStreamWAV:
    var b: PackedFloat32Array
    match n:
        "step":
            b = _buf(0.12)
            b = _noise(b, 0.0, 0.11, 0.9, 26.0, 0.18)
        "jump":
            b = _buf(0.2)
            b = _tone(b, 0.0, 0.16, 180.0, 320.0, 0.3, 6.0, 1)
            b = _noise(b, 0.0, 0.12, 0.2, 18.0, 0.3)
        "land":
            b = _buf(0.24)
            b = _tone(b, 0.0, 0.2, 100.0, 45.0, 0.7, 14.0)
            b = _noise(b, 0.0, 0.12, 0.5, 25.0, 0.12)
        "door_open":
            b = _buf(0.4)
            b = _noise(b, 0.0, 0.06, 0.5, 30.0, 0.5)
            b = _tone(b, 0.05, 0.25, 260.0, 200.0, 0.2, 8.0, 1)
            b = _noise(b, 0.2, 0.05, 0.4, 40.0, 0.5)
        "door_close":
            b = _buf(0.32)
            b = _tone(b, 0.0, 0.28, 130.0, 70.0, 0.8, 16.0)
            b = _noise(b, 0.0, 0.08, 0.6, 40.0, 0.4)
        "deagle":
            b = _buf(0.55)
            b = _noise(b, 0.0, 0.5, 1.0, 12.0, 0.55)
            b = _tone(b, 0.0, 0.3, 160.0, 45.0, 0.9, 10.0)
        "rifle":
            b = _buf(0.32)
            b = _noise(b, 0.0, 0.3, 0.9, 20.0, 0.5)
            b = _tone(b, 0.0, 0.15, 200.0, 70.0, 0.7, 18.0)
        "shotgun":
            b = _buf(0.85)
            b = _noise(b, 0.0, 0.8, 1.0, 7.0, 0.4)
            b = _tone(b, 0.0, 0.4, 120.0, 35.0, 1.0, 6.0)
        "pump":
            b = _buf(0.35)
            b = _noise(b, 0.0, 0.05, 0.6, 40.0, 0.6)
            b = _noise(b, 0.2, 0.06, 0.7, 35.0, 0.6)
        "rpg":
            b = _buf(1.0)
            b = _noise(b, 0.0, 0.9, 0.7, 3.5, 0.25)
            b = _tone(b, 0.0, 0.5, 90.0, 40.0, 0.8, 5.0)
        "explosion":
            b = _buf(2.0)
            b = _noise(b, 0.0, 1.8, 1.0, 2.4, 0.07)
            b = _tone(b, 0.0, 1.2, 70.0, 25.0, 1.0, 2.5)
        "reload":
            b = _buf(0.5)
            b = _tone(b, 0.05, 0.05, 2200.0, 1800.0, 0.5, 40.0, 2)
            b = _noise(b, 0.05, 0.04, 0.5, 60.0, 0.6)
            b = _tone(b, 0.35, 0.05, 1500.0, 1200.0, 0.55, 40.0, 2)
            b = _noise(b, 0.35, 0.05, 0.6, 60.0, 0.6)
        "empty":
            b = _buf(0.08)
            b = _tone(b, 0.0, 0.05, 1800.0, 1500.0, 0.5, 60.0, 2)
        "swing":
            b = _buf(0.3)
            b = _noise(b, 0.0, 0.28, 0.5, 0.0, 0.35, true)
        "punch":
            b = _buf(0.16)
            b = _tone(b, 0.0, 0.12, 140.0, 60.0, 0.9, 22.0)
            b = _noise(b, 0.0, 0.08, 0.5, 40.0, 0.3)
        "bat_hit":
            b = _buf(0.22)
            b = _tone(b, 0.0, 0.15, 320.0, 120.0, 0.7, 25.0, 1)
            b = _noise(b, 0.0, 0.06, 0.7, 50.0, 0.6)
        "pain":
            b = _buf(0.4)
            b = _tone(b, 0.0, 0.35, 150.0, 95.0, 0.4, 5.0, 1)
            b = _noise(b, 0.0, 0.3, 0.12, 6.0, 0.15)
        "scream":
            b = _buf(0.75)
            b = _tone(b, 0.0, 0.7, 620.0, 520.0, 0.35, 1.8, 1)
            b = _tone(b, 0.0, 0.7, 790.0, 640.0, 0.2, 1.8, 1)
        "horn":
            b = _buf(0.5)
            b = _tone(b, 0.0, 0.48, 420.0, 420.0, 0.35, 1.5, 2)
            b = _tone(b, 0.0, 0.48, 525.0, 525.0, 0.3, 1.5, 2)
        "crash":
            b = _buf(0.55)
            b = _noise(b, 0.0, 0.5, 1.0, 9.0, 0.3)
            b = _tone(b, 0.0, 0.3, 90.0, 40.0, 0.9, 10.0)
        "pickup":
            b = _buf(0.18)
            b = _tone(b, 0.0, 0.14, 500.0, 900.0, 0.5, 12.0)
        "click":
            b = _buf(0.06)
            b = _tone(b, 0.0, 0.04, 1200.0, 900.0, 0.5, 60.0)
        "engine":
            return _to_wav(_engine_loop(), true)
        "skid":
            b = _buf(0.4)
            b = _noise(b, 0.0, 0.4, 0.35, 0.0, 0.6)
            return _to_wav(b, true)
        _:
            b = _buf(0.05)
    return _to_wav(b)


func _engine_loop() -> PackedFloat32Array:
    var cycles: int = 6
    var per: int = RATE / 50
    var n: int = per * cycles
    var a := PackedFloat32Array()
    a.resize(n)
    for i in n:
        var ph: float = TAU * float(i) / float(per)
        var v: float = sin(ph) * 0.5 + sin(ph * 2.0) * 0.3 + sin(ph * 3.0) * 0.22
        v += sin(ph * 5.0) * 0.12 + sin(ph * 7.0) * 0.08
        v += (fposmod(ph / TAU, 1.0) * 2.0 - 1.0) * 0.18
        a[i] = v * 0.55
    return a
