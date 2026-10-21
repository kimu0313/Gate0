class_name PostFx
extends CanvasLayer
## Full-screen post-processing driven by erosion, eyelids, glitch pulses and flashes.

var erosion := 0.0
var eyes := 0.0
var _glitch := 0.0
var _flash := 0.0
var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 1
	_rect = ColorRect.new()
	UiKit.full_rect(_rect)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/post_fx.gdshader")
	_rect.material = _mat
	add_child(_rect)


func pulse_glitch(amount := 0.6) -> void:
	_glitch = maxf(_glitch, amount)


func flash(amount := 1.0, color := Color.WHITE) -> void:
	_flash = amount
	_mat.set_shader_parameter("flash_color", color)


func _process(delta: float) -> void:
	_glitch = move_toward(_glitch, 0.0, delta * 1.6)
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	_mat.set_shader_parameter("erosion", erosion)
	_mat.set_shader_parameter("eyes", eyes)
	_mat.set_shader_parameter("glitch", _glitch)
	_mat.set_shader_parameter("flash", _flash)
