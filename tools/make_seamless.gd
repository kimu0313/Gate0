extends SceneTree
## Makes a photo tile without seams (for floors and walls the user hands over as pictures):
##   godot --headless --path . --script res://tools/make_seamless.gd -- <in.png> <out.png>
##   godot --headless --path . --import          (then set the .import to VRAM compression + mipmaps)
## Four copies of the picture — as it is, shifted half its size in x, in y, in both — are blended, each weighted by how
## far the pixel is from that copy's own seams, so every pixel takes a copy with no seam there (a mirror makes
## chevrons of any grain; a single cross-fade leaves a seam through the middle). Size and colours are kept.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var f := Image.load_from_file(args[0])
	f.convert(Image.FORMAT_RGB8)
	var w := f.get_width()
	var h := f.get_height()
	var hw := w / 2
	var hh := h / 2
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var by := sin(PI * (y + 0.5) / h)              # 0 at the picture's border, 1 in its middle
		var cy := absf(cos(PI * (y + 0.5) / h))        # 0 in the middle (a shifted copy's seam), 1 at the border
		for x in w:
			var bx := sin(PI * (x + 0.5) / w)
			var cx := absf(cos(PI * (x + 0.5) / w))
			var ws := [pow(bx * by, 2.0), pow(cx * by, 2.0), pow(bx * cy, 2.0), pow(cx * cy, 2.0)]
			var cs := [f.get_pixel(x, y), f.get_pixel((x + hw) % w, y), f.get_pixel(x, (y + hh) % h),
				f.get_pixel((x + hw) % w, (y + hh) % h)]
			var sum := Color(0, 0, 0)
			var wsum := 0.0
			for k in 4:
				sum += cs[k] * ws[k]
				wsum += ws[k]
			out.set_pixel(x, y, Color(sum.r / wsum, sum.g / wsum, sum.b / wsum))
	var err := out.save_png(ProjectSettings.globalize_path(args[1]) if args[1].begins_with("res://") else args[1])
	print("%s: %dx%d %s" % [args[1], w, h, "ok" if err == OK else "error %d" % err])
	quit()
