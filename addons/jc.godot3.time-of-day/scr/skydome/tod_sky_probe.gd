tool
class_name TOD_SkyProbe extends Spatial
# Description:
# - Render sky cubemap and set texture to enviroment.
# License:
# - J. Cuéllar 2022 MIT License
# - See: LICENSE File.

# Resources.
const sky_render_target: PackedScene = preload(
	"res://addons/jc.godot3.time-of-day/content/resources/sky_probe_rt.tscn"
)

var _pano_sky:= PanoramaSky.new()

var _init_properties_ok: bool = false

### Cubemap Viewports ###
var front_vp: Viewport = null
var right_vp: Viewport = null
var left_vp:  Viewport = null
var back_vp:  Viewport = null
var up_vp:    Viewport = null
var down_vp:  Viewport = null

# Out viewport 
var out_vp: Viewport = null

### Cameras ###
var camera_f: Camera = null
var camera_r: Camera = null
var camera_l: Camera = null
var camera_b: Camera = null
var camera_u: Camera = null
var camera_d: Camera = null

### Instances ###
var _instance: Spatial = null

### Params ###
var _enviro: Environment = null
var enviro_container: NodePath setget _set_enviro_container
func _set_enviro_container(value: NodePath) -> void:
	enviro_container = value
	if value != null:
		var container = get_node_or_null(value)
		if container is Camera || container is WorldEnvironment:
			_enviro = container.environment
			_enviro.background_mode = _enviro.BG_COLOR_SKY
			#if not _enviro.background_sky is PanoramaSky:
			_enviro.background_sky = _pano_sky

var linear_color: bool setget _set_linear_color
func _set_linear_color(value: bool) -> void:
	linear_color = value
	if check_viewports():
		front_vp.keep_3d_linear = value
		right_vp.keep_3d_linear = value
		left_vp.keep_3d_linear  = value
		back_vp.keep_3d_linear  = value
		up_vp.keep_3d_linear    = value
		down_vp.keep_3d_linear  = value
		out_vp.keep_3d_linear   = value

var layers: int = 4 setget _set_layers
func _set_layers(value: int) -> void:
	layers = value
	if _check_cameras():
		camera_f.cull_mask = value
		camera_r.cull_mask = value
		camera_l.cull_mask = value
		camera_b.cull_mask = value
		camera_u.cull_mask = value
		camera_d.cull_mask = value

var update_realtime: bool = true
var update_time: float = 1.0

var texture_size: int = TOD_Enums.Resolution.R64 setget _set_texture_size
func _set_texture_size(value: int) -> void:
	texture_size = value
	if !_init_properties_ok: return
	assert(_instance != null, "Instance not found")
	
	var r:= Vector2.ZERO
	match(value):
		TOD_Enums.Resolution.R64:   r = Vector2.ONE * 64
		TOD_Enums.Resolution.R128:  r = Vector2.ONE * 128
		TOD_Enums.Resolution.R256:  r = Vector2.ONE * 256
		TOD_Enums.Resolution.R512:  r = Vector2.ONE * 512
		TOD_Enums.Resolution.R1024: r = Vector2.ONE * 512
	
	# Set cubemap size.
	front_vp.size = r
	right_vp.size = r
	left_vp.size  = r 
	back_vp.size  = r
	up_vp.size    = r
	down_vp.size  = r
	
	# Set out texture size.
	out_vp.size.x = r.x 
	out_vp.size.y = r.y/2
	
	match(value):
		TOD_Enums.Resolution.R64:   _pano_sky.radiance_size = Sky.RADIANCE_SIZE_64
		TOD_Enums.Resolution.R128:  _pano_sky.radiance_size = Sky.RADIANCE_SIZE_128
		TOD_Enums.Resolution.R256:  _pano_sky.radiance_size = Sky.RADIANCE_SIZE_256
		TOD_Enums.Resolution.R512:  _pano_sky.radiance_size = Sky.RADIANCE_SIZE_512
		TOD_Enums.Resolution.R1024: _pano_sky.radiance_size = Sky.RADIANCE_SIZE_512
	
	_update_sky()

var _first_update: bool = false
var _update_timer: float = 0.0

func _init() -> void:
	if check_viewports():
		_init_properties_ok = true

func _enter_tree() -> void:
	_build_probe()
	_init_properties()

func _init_properties() -> void:
	_init_properties_ok = true
	_set_enviro_container(enviro_container)
	_set_texture_size(texture_size)
	_set_linear_color(linear_color)
	_set_layers(layers)

### Build ###
func _build_probe() -> void:
	var path:= "SkyProbeRT"
	_instance = get_node_or_null(path) as Spatial
	if _instance == null:
		_instance = sky_render_target.instance() as Spatial
		_instance.name = path
		self.add_child(_instance)
		#_instance.owner = self.get_tree().edited_scene_root
	_get_viewports()

func _get_viewports() -> void:
	var front_path := "Front"
	var right_path := "Right"
	var left_path  := "Left"
	var back_path  := "Back"
	var up_path    := "Up"
	var down_path  := "Down"
	var out_path   := "Out"
	
	front_vp = _instance.get_node_or_null(front_path)
	right_vp = _instance.get_node_or_null(right_path)
	left_vp  = _instance.get_node_or_null(left_path)
	back_vp  = _instance.get_node_or_null(back_path)
	up_vp    = _instance.get_node_or_null(up_path)
	down_vp  = _instance.get_node_or_null(down_path)
	out_vp   = _instance.get_node_or_null(out_path)
	
	_get_cameras()

func check_viewports() -> bool:
	if front_vp == null: return false
	if right_vp == null: return false
	if left_vp  == null: return false
	if back_vp  == null: return false
	if up_vp    == null: return false
	if down_vp  == null: return false
	if out_vp   == null: return false
	
	return true

func _get_cameras() -> void:
	if check_viewports():
		camera_f = front_vp.get_child(0)
		camera_r = right_vp.get_child(0)
		camera_l = left_vp.get_child(0)
		camera_b = back_vp.get_child(0)
		camera_u = up_vp.get_child(0)
		camera_d = down_vp.get_child(0)

func _check_cameras() -> bool:
	if camera_f == null: return false
	if camera_r == null: return false
	if camera_l == null: return false
	if camera_b == null: return false
	if camera_u == null: return false
	if camera_d == null: return false
	return true

func _process(delta) -> void:
	if _first_update && !update_realtime: 
		return
	
	_update_timer += delta;
	if _update_timer > update_time:
		_update_sky()
		if !update_realtime:
			_first_update = true
		else:
			_first_update = false
		_update_timer = 0.0

func _update_sky() -> void:
	if _enviro == null: return
	#var sky := _enviro.background_sky as PanoramaSky
	_pano_sky.set_panorama(null)
	_pano_sky.set_panorama(out_vp.get_texture())

func _get_property_list() -> Array:
	var ret: Array
	ret.push_back({name = "Sky Probe", type=TYPE_NIL, usage=PROPERTY_USAGE_CATEGORY})
	
	ret.push_back({name = "Target", type=TYPE_NIL, usage=PROPERTY_USAGE_GROUP})
	ret.push_back({name = "enviro_container", type=TYPE_NODE_PATH})
	
	ret.push_back({name = "Render", type=TYPE_NIL, usage=PROPERTY_USAGE_GROUP})
	ret.push_back({name = "linear_color", type=TYPE_BOOL})
	ret.push_back({name = "layers", type=TYPE_INT, hint=PROPERTY_HINT_LAYERS_3D_RENDER})
	
	ret.push_back({name = "Texture", type=TYPE_NIL, usage=PROPERTY_USAGE_GROUP})
	ret.push_back({name = "update_realtime", type=TYPE_BOOL})
	ret.push_back({name = "update_time", type=TYPE_REAL})
	ret.push_back({name = "texture_size", type=TYPE_INT, hint=PROPERTY_HINT_ENUM, hint_string="64, 128, 256, 512"})
	
	return ret
