extends SceneTree
## Recolours the generated UI art from the old signal yellow to the deep-blue accent (UiKit.SIGNAL).
## usage (from the project root):
##   godot --headless --path . --script res://tools/recolor_ui_art.gd -- [icon_out_dir]
## Yellow-hued pixels keep their texture (value, grain, wear) and move to the accent hue. On the app icon
## the dark 0 is turned light so it still reads on the blue tile. With `icon_out_dir`, the icon is also
## written there at the Windows .ico sizes (tools/pack_ico.py packs them into icon.ico).

const ACCENT_H := 0.627          # hue of UiKit.SIGNAL (#1e40af, deep blue)
const ACCENT_S := 0.83
const VALUE_K := 0.72            # yellow is much brighter than the blue; keep the art about as dark as the UI accent
const FILES := ["res://assets/ui/tablet_bezel.png", "res://assets/ui/staff_card.png", "res://assets/ui/app_icon.png"]
const ICON := "res://assets/ui/app_icon.png"
const ICON_GLYPH := Rect2i(132, 64, 248, 390)   # the 0 on the 512 px icon
const ICO_SIZES := [16, 24, 32, 48, 64, 128, 256]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var ico_dir: String = args[0] if args.size() > 0 else ""
	for path in FILES:
		var abs_path := ProjectSettings.globalize_path(path)
		var img := Image.load_from_file(abs_path)
		if img == null:
			push_error("cannot load " + path)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var changed := _recolor(img, path == ICON)
		img.save_png(abs_path)
		print("%s  %d px recoloured" % [path, changed])
		if path == ICON and ico_dir != "":
			DirAccess.make_dir_recursive_absolute(ico_dir)
			for s in ICO_SIZES:
				var small := img.duplicate() as Image
				small.resize(s, s, Image.INTERPOLATE_LANCZOS)
				small.save_png("%s/icon_%d.png" % [ico_dir, s])
	quit()


func _recolor(img: Image, icon: bool) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			# transparent pixels too: their colour still bleeds into the edges when the texture is filtered
			var c := img.get_pixel(x, y)
			var out := _shift(c)
			if icon and ICON_GLYPH.has_point(Vector2i(x, y)) and c.v < 0.4 and c.s < 0.55:
				# the black 0 becomes a light 0 (dark grain stays as faint wear)
				var k := clampf((0.4 - c.v) / 0.28, 0.0, 1.0)
				out = c.lerp(Color(0.95, 0.96, 0.99, c.a), k)
			if out != c:
				img.set_pixel(x, y, out)
				n += 1
	return n


## Yellow (about 30°–70°) moves to the accent hue; edges of the range blend so anti-aliasing stays smooth.
func _shift(c: Color) -> Color:
	var h := c.h
	if c.s < 0.22 or c.v < 0.12 or h < 0.075 or h > 0.205:
		return c
	var t := clampf(minf((h - 0.075) / 0.03, (0.205 - h) / 0.03), 0.0, 1.0) * clampf((c.s - 0.22) / 0.15, 0.0, 1.0)
	var blue := Color.from_hsv(ACCENT_H, clampf(c.s * ACCENT_S / 0.85, 0.0, 1.0), c.v * VALUE_K, c.a)
	return c.lerp(blue, t)
