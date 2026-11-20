extends Node
# Настройки (автозагрузка "Settings"): графика, тени, дальность, сглаживание и т.д.

const PATH: String = "user://pomilor_settings.cfg"
const LEVELS: Array = ["Очень низко", "Низко", "Средне", "Высоко", "Ультра"]
const AA_NAMES: Array = ["Выключено", "FXAA", "MSAA 2x", "MSAA 4x", "MSAA 4x + SSAA"]
const ANISO_NAMES: Array = ["Выкл", "2x", "4x", "8x", "16x"]
const FPS_VALUES: Array = [15, 20, 30, 45, 60, 120, 144, 0]
const FPS_NAMES: Array = ["15", "20", "30", "45", "60", "120", "144", "Без лимита"]

const RENDER_SCALE: Array = [0.5, 0.66, 0.8, 1.0, 1.0]
const VIEW_FAR: Array = [140.0, 220.0, 340.0, 520.0, 900.0]
const SHADOW_ATLAS: Array = [1024, 2048, 2048, 4096, 8192]
const SHADOW_DIST: Array = [45.0, 75.0, 110.0, 160.0, 240.0]
const NPC_COUNT: Array = [8, 12, 20, 32, 50]
const TRAFFIC_COUNT: Array = [5, 8, 12, 20, 30]
# Детализация по пресету графики (индекс 0 = очень низко ... 4 = ультра)
const LOD_PEOPLE: Array = [60.0, 90.0, 140.0, 220.0, 400.0]
const LOD_LIMBS: Array = [25.0, 40.0, 65.0, 110.0, 220.0]
const LOD_SMALL: Array = [15.0, 25.0, 40.0, 70.0, 140.0]
const ANIM_DIST: Array = [40.0, 60.0, 90.0, 140.0, 250.0]
const SEG_RADIAL: Array = [6, 8, 10, 12, 16]
const SEG_RINGS: Array = [2, 3, 4, 5, 6]
const LAMP_SEG: Array = [4, 6, 8, 12, 16]
const TEX_SIZE: Array = [128, 256, 256, 512, 1024]
const PART_SCALE: Array = [0.3, 0.5, 0.8, 1.0, 1.4]

signal changed

var graphics: int = 2
var shadows: int = 2
var view_distance: int = 2
var aa: int = 1
var aniso: int = 2
var bloom: bool = true
var fps_idx: int = 4
var sensitivity: float = 1.0
var fov: float = 75.0
var show_fps: bool = true

var env: Environment = null
var sun: DirectionalLight3D = null
var sky: Sky = null
var sky_low: Material = null
var sky_high: Material = null
var cams: Array = []


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    load_settings()
    apply_all()


func load_settings() -> void:
    var cf := ConfigFile.new()
    if cf.load(PATH) != OK:
        _auto_defaults()
        save_settings()
        return
    graphics = clampi(int(cf.get_value("g", "graphics", graphics)), 0, 4)
    shadows = clampi(int(cf.get_value("g", "shadows", shadows)), 0, 4)
    view_distance = clampi(int(cf.get_value("g", "view", view_distance)), 0, 4)
    aa = clampi(int(cf.get_value("g", "aa", aa)), 0, 4)
    aniso = clampi(int(cf.get_value("g", "aniso", aniso)), 0, 4)
    bloom = bool(cf.get_value("g", "bloom", bloom))
    fps_idx = clampi(int(cf.get_value("g", "fps", fps_idx)), 0, FPS_VALUES.size() - 1)
    sensitivity = clampf(float(cf.get_value("p", "sens", sensitivity)), 0.3, 2.5)
    fov = clampf(float(cf.get_value("p", "fov", fov)), 60.0, 100.0)
    show_fps = bool(cf.get_value("p", "show_fps", show_fps))


func _auto_defaults() -> void:
    # Первый запуск: на слабых мобильных GPU сразу ставим лёгкие настройки.
    if not OS.has_feature("mobile"):
        return
    var gpu: String = RenderingServer.get_video_adapter_name().to_lower()
    var weak: Array = ["adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 5", "adreno (tm) 60", "adreno (tm) 61", "mali-4", "mali-t", "mali-g31", "mali-g51", "mali-g52", "powervr", "videocore"]
    for key in weak:
        if gpu.contains(str(key)):
            graphics = 1
            shadows = 0
            view_distance = 1
            aa = 0
            aniso = 1
            bloom = false
            return


func save_settings() -> void:
    var cf := ConfigFile.new()
    cf.set_value("g", "graphics", graphics)
    cf.set_value("g", "shadows", shadows)
    cf.set_value("g", "view", view_distance)
    cf.set_value("g", "aa", aa)
    cf.set_value("g", "aniso", aniso)
    cf.set_value("g", "bloom", bloom)
    cf.set_value("g", "fps", fps_idx)
    cf.set_value("p", "sens", sensitivity)
    cf.set_value("p", "fov", fov)
    cf.set_value("p", "show_fps", show_fps)
    cf.save(PATH)


func view_far() -> float:
    return VIEW_FAR[view_distance]


func npc_count() -> int:
    return NPC_COUNT[graphics]


func traffic_count() -> int:
    return TRAFFIC_COUNT[graphics]


func particle_scale() -> float:
    return PART_SCALE[graphics]


func is_forward_plus() -> bool:
    return RenderingServer.get_current_rendering_method() == "forward_plus"


func is_compat() -> bool:
    return RenderingServer.get_current_rendering_method() == "gl_compatibility"


func bind_world(e: Environment, s: DirectionalLight3D, sk: Sky, lo: Material, hi: Material) -> void:
    env = e
    sun = s
    sky = sk
    sky_low = lo
    sky_high = hi
    cams.clear()
    apply_all()


func register_camera(c: Camera3D) -> void:
    if not cams.has(c):
        cams.append(c)
    c.far = view_far()


func apply_all() -> void:
    _apply_viewport()
    _apply_fps()
    _apply_shadows()
    _apply_environment()
    _apply_view_distance()
    changed.emit()


func _apply_fps() -> void:
    var lim: int = FPS_VALUES[fps_idx]
    Engine.max_fps = lim
    if lim == 0:
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    else:
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)


func _apply_viewport() -> void:
    var vp: Viewport = get_viewport()
    if vp == null:
        return
    var scale: float = RENDER_SCALE[graphics]
    vp.msaa_3d = Viewport.MSAA_DISABLED
    vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
    match aa:
        1:
            vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
        2:
            vp.msaa_3d = Viewport.MSAA_2X
        3:
            vp.msaa_3d = Viewport.MSAA_4X
        4:
            vp.msaa_3d = Viewport.MSAA_4X
            scale = minf(scale * 2.0, 2.0)
    if scale > 1.001:
        vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
    elif scale < 0.999:
        if graphics >= 1 and is_forward_plus():
            vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
        else:
            vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
    else:
        vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
    vp.scaling_3d_scale = scale
    match aniso:
        0:
            vp.anisotropic_filtering_level = Viewport.ANISOTROPY_DISABLED
        1:
            vp.anisotropic_filtering_level = Viewport.ANISOTROPY_2X
        2:
            vp.anisotropic_filtering_level = Viewport.ANISOTROPY_4X
        3:
            vp.anisotropic_filtering_level = Viewport.ANISOTROPY_8X
        4:
            vp.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
    vp.use_debanding = graphics >= 2
    vp.positional_shadow_atlas_size = [1024, 2048, 2048, 4096, 4096][shadows]


func _apply_shadows() -> void:
    RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[shadows], shadows < 3)
    var q: Array = [
        RenderingServer.SHADOW_QUALITY_HARD,
        RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
        RenderingServer.SHADOW_QUALITY_SOFT_LOW,
        RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
        RenderingServer.SHADOW_QUALITY_SOFT_ULTRA,
    ]
    RenderingServer.directional_soft_shadow_filter_set_quality(q[shadows])
    RenderingServer.positional_soft_shadow_filter_set_quality(q[shadows])
    if sun == null:
        return
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = SHADOW_DIST[shadows]
    if shadows == 0:
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    elif shadows <= 2:
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    else:
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    sun.directional_shadow_blend_splits = shadows >= 3
    sun.shadow_bias = 0.03 if shadows < 3 else 0.02
    sun.shadow_normal_bias = 1.6 if shadows < 3 else 1.2
    sun.light_angular_distance = 0.4 if shadows == 4 else 0.0


func _apply_environment() -> void:
    if env == null:
        return
    var fp: bool = is_forward_plus()
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 1.0
    env.tonemap_white = 6.0
    env.glow_enabled = bloom and graphics >= 1
    env.glow_intensity = 0.45 + 0.12 * float(graphics)
    env.glow_strength = 1.0
    env.glow_bloom = 0.03 + 0.012 * float(graphics)
    env.glow_hdr_threshold = 1.0
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
    for i in range(7):
        env.set_glow_level(i, 1.0 if i < 2 + graphics else 0.0)
    env.adjustment_enabled = graphics >= 3
    env.adjustment_contrast = 1.06
    env.adjustment_saturation = 1.1
    env.fog_enabled = true
    env.fog_density = 2.6 / view_far()
    env.fog_sky_affect = 0.25
    env.fog_light_color = Color(0.72, 0.8, 0.9)
    env.ssao_enabled = fp and graphics >= 2
    env.ssil_enabled = fp and graphics >= 4
    env.ssr_enabled = fp and graphics >= 3
    if fp:
        env.ssao_radius = 1.6
        env.ssao_intensity = 2.0
        env.volumetric_fog_enabled = graphics >= 4
        env.volumetric_fog_density = 0.004
        _env_set("sdfgi_enabled", graphics >= 4)
        if graphics >= 4:
            _env_set("sdfgi_use_occlusion", true)
            _env_set("sdfgi_bounce_feedback", 0.5)
            _env_set("sdfgi_energy", 1.0)
            _env_set("sdfgi_cascades", 4)
    if sky != null:
        sky.radiance_size = [Sky.RADIANCE_SIZE_32, Sky.RADIANCE_SIZE_64, Sky.RADIANCE_SIZE_128, Sky.RADIANCE_SIZE_256, Sky.RADIANCE_SIZE_512][graphics]
        if sky_high != null and sky_low != null:
            sky.sky_material = sky_high if graphics >= 4 else sky_low


func _env_set(prop: String, value) -> void:
    if env != null and prop in env:
        env.set(prop, value)


func _apply_view_distance() -> void:
    var far: float = view_far()
    for c in cams:
        if is_instance_valid(c):
            (c as Camera3D).far = far
    if is_inside_tree():
        get_tree().call_group("vis_range", "set", "visibility_range_end", far)
        if env != null:
            env.fog_density = 2.6 / far
