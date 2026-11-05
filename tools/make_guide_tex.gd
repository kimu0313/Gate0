extends SceneTree
## Makes the guidelines folder's picture (the user's image: a kraft file folder with a paper clip, CONFIDENTIAL and
## TOP SECRET stamps, an orange tab; on white) into a cut-out with alpha:
##   godot --headless --path . --script res://tools/make_guide_tex.gd -- <image.png>
##   godot --headless --path . --import
## The white round it (flood-filled in from the border) goes transparent, its edge softened; the hidden pixels take
## the folder's kraft so no white fringe shows when it is mipmapped. Writes assets/textures/level/guide_folder.png and
## prints the folder body's rectangle in the image (rows mostly opaque), for Shift1's backing board.

const OUT := "res://assets/textures/level/guide_folder.png"
const KRAFT := Color(0.79, 0.63, 0.44)


func _init() -> void:
	var src := Image.load_from_file(OS.get_cmdline_user_args()[0])
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if bg[i] == 1:
			continue
		var c := src.get_pixel(i % w, i / w)
		if minf(c.r, minf(c.g, c.b)) < 0.86 or maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) > 0.08:
			continue
		bg[i] = 1
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := y * w + x
			var c := src.get_pixel(x, y)
			if bg[i] == 1:
				out.set_pixel(x, y, Color(KRAFT, 0.0))
				continue
			# an opaque pixel on the edge: as see-through as it is close to white
			var edge := (x > 0 and bg[i - 1] == 1) or (x < w - 1 and bg[i + 1] == 1) or (y > 0 and bg[i - w] == 1) or (y < h - 1 and bg[i + w] == 1)
			var a := 1.0
			if edge:
				a = clampf((1.0 - c.get_luminance()) / 0.25, 0.35, 1.0)
			out.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	out.save_png(OUT)
	# the body: rows where most of the width is opaque
	var y0 := h
	var y1 := 0
	var x0 := w
	var x1 := 0
	for y in h:
		var n := 0
		var first := -1
		var last := -1
		for x in w:
			if bg[y * w + x] == 0:
				n += 1
				if first < 0:
					first = x
				last = x
		if n > w * 0.6:
			y0 = mini(y0, y)
			y1 = maxi(y1, y)
			x0 = mini(x0, first)
			x1 = maxi(x1, last)
	print("size %d x %d; body x %d..%d y %d..%d" % [w, h, x0, x1, y0, y1])
	quit()
