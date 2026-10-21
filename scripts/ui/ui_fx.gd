class_name UiFx
extends RefCounted
## Motion vocabulary for every UI screen. Entries ease out (180–280 ms), exits ease in (120–160 ms),
## emphasis uses back-out. All tweens are bound to the animated node, so they die with it.

const IN := 0.24
const OUT := 0.14


## Scale + fade in around the control's center.
static func pop_in(c: Control, dur := IN, from_scale := 0.94, delay := 0.0) -> Tween:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * from_scale
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.6).set_delay(delay)
	return tw


## Slides from `offset` back to the current position while fading in. Free-positioned controls only
## (containers re-layout their children).
static func slide_in(c: Control, offset: Vector2, dur := IN, delay := 0.0, trans := Tween.TRANS_CUBIC) -> Tween:
	var target := c.position
	c.position = target + offset
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "position", target, dur).set_trans(trans).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.7).set_delay(delay)
	return tw


static func fade(c: CanvasItem, to: float, dur := IN, delay := 0.0) -> Tween:
	var tw := c.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", to, dur)
	return tw


## Fluorescent tube start: a few uneven flickers, then steady.
static func flicker_on(c: CanvasItem, delay := 0.0, sound := true) -> Tween:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	if sound:
		tw.tween_callback(func(): Snd.play("flicker_zap", -20.0, randf_range(1.1, 1.3)))
	if Game.settings.reduce_motion:
		# accessibility: a plain fade instead of strobing
		tw.tween_property(c, "modulate:a", 1.0, 0.25)
		return tw
	for step in [[0.85, 0.03], [0.1, 0.05], [0.0, 0.07], [0.7, 0.03], [0.25, 0.06], [1.0, 0.04], [0.6, 0.03], [1.0, 0.05]]:
		tw.tween_property(c, "modulate:a", step[0], step[1])
	return tw


## Short positional shake (impacts, errors). Works on free-positioned controls.
## Skipped when the player asked for calmer UI (Settings › 자막·접근성).
static func shake(c: Control, amp := 8.0, dur := 0.28) -> Tween:
	if Game.settings.reduce_motion:
		amp *= 0.0
	var base := c.position
	var tw := c.create_tween()
	var steps := 7
	for i in steps:
		var k := 1.0 - float(i) / steps
		tw.tween_property(c, "position", base + Vector2(randf_range(-1, 1), randf_range(-0.6, 0.6)) * amp * k, dur / steps)
	tw.tween_property(c, "position", base, dur / steps)
	return tw


## Staggered fade-in for container children (modulate only, so layout is never fought).
static func stagger(nodes: Array, step := 0.035, dur := 0.2, delay := 0.0) -> void:
	for i in nodes.size():
		var n: CanvasItem = nodes[i]
		if n == null or not is_instance_valid(n):
			continue
		n.modulate.a = 0.0
		var tw := n.create_tween()
		tw.tween_interval(delay + i * step)
		tw.tween_property(n, "modulate:a", 1.0, dur)


## Staggered slide for container children: x offset applied after the container has laid them out.
static func stagger_slide(nodes: Array, offset := Vector2(-18, 0), step := 0.04, dur := 0.24, delay := 0.0) -> void:
	for i in nodes.size():
		var n: Control = nodes[i]
		if n == null or not is_instance_valid(n):
			continue
		n.modulate.a = 0.0
		var tw := n.create_tween()
		tw.tween_interval(delay + i * step)
		tw.tween_callback(func():
			var target := n.position
			n.position = target + offset
			var t2 := n.create_tween().set_parallel(true)
			t2.tween_property(n, "position", target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t2.tween_property(n, "modulate:a", 1.0, dur * 0.7))


## Counts a label up to `to` (e.g. report numbers).
static func count_up(l: Label, to: int, dur := 0.5, fmt := "%02d", delay := 0.0, tick := true) -> Tween:
	l.text = fmt % 0
	var tw := l.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	var last := [-1]
	var step := func(v: float):
		var n := int(round(v))
		l.text = fmt % n
		if tick and n != last[0] and n > 0:
			Snd.play("keypad_beep", -24.0, 1.6 + n * 0.02)
		last[0] = n
	var t := maxf(dur * minf(1.0, to / 4.0), 0.12) if to > 0 else 0.01
	tw.tween_method(step, 0.0, float(to), t)
	return tw


## Reveals text character by character via visible_ratio.
static func typewrite(c: Control, dur := 0.6, delay := 0.0) -> Tween:
	c.set("visible_ratio", 0.0)
	var tw := c.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(c, "visible_ratio", 1.0, dur)
	return tw


## Animates a backdrop made by UiKit.backdrop().
static func backdrop_to(bd: Control, amount: float, dur := 0.22) -> Tween:
	var rect := bd.get_node_or_null("Blur") as ColorRect
	if rect == null:
		return null
	var mat := rect.material as ShaderMaterial
	var tw := bd.create_tween()
	var setter := func(v: float): mat.set_shader_parameter("amount", v)
	tw.tween_method(setter, float(mat.get_shader_parameter("amount")), amount, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw


## Stamp impact: drops from large scale, squashes slightly, settles.
static func slam(c: Control, dur := 0.26) -> Tween:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * 1.8
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE * 0.94, dur * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.3)
	tw.set_parallel(false)
	tw.tween_property(c, "scale", Vector2.ONE, dur * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw
