class_name PortalView
extends Node
## A doorway that looks into somewhere else. A SubViewport renders the world from where your eye would be if the
## place behind `src` (a frame in the doorway, +Z = through it) carried on as `dst` (the same frame somewhere else), and
## any surface given surface_material() shows that render at its own screen pixels — so what you see through the door
## is the other place, from exactly your point of view, with whatever stands in the doorway (the leaves) in front of it.
## Renders only while active (set_active).

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D view : source_color, filter_linear;
void fragment() {
	ALBEDO = texture(view, SCREEN_UV).rgb;
}
"""

var src: Transform3D
var dst: Transform3D
var eye: Camera3D
var _vp: SubViewport
var _cam: Camera3D
var _mat: ShaderMaterial


static func create(parent: Node, src_xf: Transform3D, dst_xf: Transform3D, eye_cam: Camera3D, env: Environment) -> PortalView:
	var pv := PortalView.new()
	pv.name = "PortalView"
	pv.src = src_xf
	pv.dst = dst_xf
	pv.eye = eye_cam
	pv.process_priority = 100                # after the player has placed its view this frame
	parent.add_child(pv)
	pv._build(env)
	pv.set_process(false)
	return pv


func _build(env: Environment) -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(get_viewport().get_visible_rect().size)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_vp.add_child(_cam)
	_cam.current = true
	if env:
		# the eye looking at the doorway grades the frame once more: no exposure, tonemapping, glow or grading here
		var e := env.duplicate() as Environment
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		e.tonemap_exposure = 1.0
		e.adjustment_enabled = false
		e.glow_enabled = false
		_cam.environment = e
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("view", _vp.get_texture())


func surface_material() -> ShaderMaterial:
	return _mat


func set_active(on: bool) -> void:
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	set_process(on)
	if on:
		_place()


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	if eye == null or not is_instance_valid(eye):
		return
	var size := Vector2i(get_viewport().get_visible_rect().size)
	if _vp.size != size:
		_vp.size = size
	_cam.fov = eye.fov
	_cam.near = eye.near
	_cam.far = eye.far
	_cam.global_transform = dst * src.affine_inverse() * eye.global_transform
