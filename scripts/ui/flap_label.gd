class_name FlapLabel
extends Label
## Label whose text changes like a split-flap departure board: every changed character cycles through
## random glyphs, then settles left to right with a soft mechanical tick.

const LATIN := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const HANGUL := "가나다라마바사아자차카타파하거너더러머버서어저처커터퍼허고노도로모보소오조초코토포호"

@export var flip_time := 0.045
@export var stagger := 0.028
@export var flips := 4
var tick_sound := true
var _target := ""
var _from := ""
var _settle: Array[float] = []
var _t := 0.0
var _anim := false
static var _last_tick := 0


static func make(txt: String, size := 20, color := Color("e8eaed"), kind := "sans", weight := 400) -> FlapLabel:
	var l := FlapLabel.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = UiKit.t(txt)
	l._target = l.text
	l.add_theme_font_override("font", UiKit.font(kind, weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _ready() -> void:
	set_process(_anim)


## Changes the text with the split-flap animation (or instantly).
func flap_to(new_text: String, animate := true, delay := 0.0) -> void:
	new_text = UiKit.t(new_text)
	if new_text == _target and (_anim or text == new_text):
		return
	_from = text if not _anim else _target
	_target = new_text
	if not animate or not is_inside_tree() or not is_visible_in_tree():
		_anim = false
		text = new_text
		set_process(false)
		return
	_settle.clear()
	var k := 0
	for i in new_text.length():
		var same := i < _from.length() and _from[i] == new_text[i]
		if same or new_text[i] == " ":
			_settle.append(-1.0)
		else:
			_settle.append(delay + k * stagger + flips * flip_time)
			k += 1
	_t = 0.0
	_anim = true
	set_process(true)


## Final text (what the label is settling on).
func target_text() -> String:
	return _target


func _process(delta: float) -> void:
	if not _anim:
		set_process(false)
		return
	_t += delta
	var out := ""
	var done := true
	for i in _target.length():
		var ch := _target[i]
		var st: float = _settle[i]
		if st >= 0.0 and _t < st:
			done = false
			if _t < st - flips * flip_time:
				ch = _from[i] if i < _from.length() else " "
			else:
				ch = _glyph_like(ch)
		out += ch
	text = out
	if tick_sound and not done:
		var now := Time.get_ticks_msec()
		if now - _last_tick > 55:
			_last_tick = now
			Snd.play("keypad_beep", -31.0, randf_range(2.3, 2.7))
	if done:
		_anim = false
		text = _target
		set_process(false)


static func _glyph_like(ch: String) -> String:
	var code := ch.unicode_at(0)
	if code >= 0xAC00 and code <= 0xD7A3:
		return HANGUL[randi() % HANGUL.length()]
	if code >= 48 and code <= 57:
		return str(randi() % 10)
	if (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
		return LATIN[randi() % LATIN.length()]
	return ch
