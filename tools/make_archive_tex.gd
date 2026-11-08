extends SceneTree
## Cuts the archive room's textures out of the user's archive photo (user, 2026-11-05: "그 내부를 이렇게 만들어줘.
## 텍스처도 카피해"; then 2026-11-06, a second photo — an old records cellar, wooden shelves of yellowed folded paper and
## ledgers stacked spines out, a worn concrete floor: "자료실 이런 느낌으로해줘"; the crops below are from that one):
##   godot --headless --path . --script res://tools/make_archive_tex.gd -- <photo.png> [<preview.png>]
## then `godot --headless --path . --import`.
##   assets/textures/level/archive_bundles.png  the shelf contents: CROPS, each scaled into a 256 x 160 cell of a
##                                             4 x 2 atlas (ArchiveRoom.BUNDLES has each crop's own aspect)
##   assets/textures/level/archive_floor.png    the worn concrete floor, cross-faded into a seamless 512 x 512 tile
## and prints the average colour of the wall, the ceiling, the shelving's wood and its green steel.

## [x, y, w, h] in the photo (736 x 981): 0-3 bundles of yellowed folded paper (the wooden shelves on the left),
## 4-7 ledgers stacked flat, spines out (the bookcase in the middle). ArchiveRoom.BUNDLES = their aspects.
const CROPS := [
	[115, 268, 175, 95], [222, 548, 78, 92], [200, 688, 100, 118], [108, 412, 182, 76],
	[304, 252, 52, 62], [304, 322, 52, 60], [304, 395, 52, 70], [303, 575, 50, 75],
]
const FLOOR := [430, 720, 250, 240]
const SAMPLES := {"wall": [520, 100, 120, 60], "ceiling": [400, 30, 150, 60], "wood": [300, 600, 5, 250], "wood2": [356, 500, 5, 300], "steel": [690, 560, 20, 200]}
const CELL := Vector2i(256, 160)
const OUT := "res://assets/textures/level/"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src := Image.load_from_file(args[0])
	src.convert(Image.FORMAT_RGB8)
	# the shelf contents atlas
	var atlas := Image.create(CELL.x * 4, CELL.y * 2, false, Image.FORMAT_RGB8)
	for i in CROPS.size():
		var c: Array = CROPS[i]
		var part := src.get_region(Rect2i(c[0], c[1], c[2], c[3]))
		part.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(part, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % 4) * CELL.x, (i / 4) * CELL.y))
		print("bundle %d aspect %.3f" % [i, float(c[2]) / c[3]])
	atlas.save_png(OUT + "archive_bundles.png")
	# the floor: the patch with its brightness levelled (the photo darkens toward the bottom and the side), made
	# seamless by cross-fading it with itself shifted half a tile (a mirror made chevrons of its grain)
	var f := src.get_region(Rect2i(FLOOR[0], FLOOR[1], FLOOR[2], FLOOR[3]))
	f.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	_level(f)
	f.rotate_90(CLOCKWISE)
	_level(f)
	f.rotate_90(COUNTERCLOCKWISE)
	# four copies (as is, shifted half a tile in x, in y, in both): each is weighted by how far the point is from that
	# copy's own seams, so every point takes a copy with no seam there
	var tile := Image.create(512, 512, false, Image.FORMAT_RGB8)
	for y in 512:
		for x in 512:
			var bx := sin(PI * (x + 0.5) / 512.0)          # 0 at the tile's border, 1 in its middle
			var by := sin(PI * (y + 0.5) / 512.0)
			var cx := absf(cos(PI * (x + 0.5) / 512.0))    # 0 in the middle (a shifted copy's seam), 1 at the border
			var cy := absf(cos(PI * (y + 0.5) / 512.0))
			var ws := [pow(bx * by, 2.0), pow(cx * by, 2.0), pow(bx * cy, 2.0), pow(cx * cy, 2.0)]
			var cs := [f.get_pixel(x, y), f.get_pixel((x + 256) % 512, y), f.get_pixel(x, (y + 256) % 512),
				f.get_pixel((x + 256) % 512, (y + 256) % 512)]
			var sum := Color(0, 0, 0)
			var wsum := 0.0
			for k in 4:
				sum += cs[k] * ws[k]
				wsum += ws[k]
			tile.set_pixel(x, y, Color(sum.r / wsum, sum.g / wsum, sum.b / wsum))
	tile.save_png(OUT + "archive_floor.png")
	for k: String in SAMPLES:
		var s: Array = SAMPLES[k]
		var sum := Color(0, 0, 0)
		for y in range(s[1], s[1] + s[3]):
			for x in range(s[0], s[0] + s[2]):
				sum += src.get_pixel(x, y)
		var n := float(s[2] * s[3])
		print("%s Color(%.3f, %.3f, %.3f)" % [k, sum.r / n, sum.g / n, sum.b / n])
	if args.size() > 1:
		var prev := Image.create(1024, 320 + 128 + 512, false, Image.FORMAT_RGB8)
		prev.blit_rect(atlas, Rect2i(0, 0, 1024, 320), Vector2i(0, 0))
		prev.blit_rect(tile, Rect2i(0, 0, 512, 512), Vector2i(0, 448))
		prev.save_png(args[1])
	quit()


## Evens out a slow brightness gradient across `img` (each row and column scaled to the patch's mean).
func _level(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var mean := 0.0
	var rows: Array[float] = []
	for y in h:
		var s := 0.0
		for x in w:
			s += img.get_pixel(x, y).get_luminance()
		rows.append(s / w)
		mean += s / w
	mean /= h
	for y in h:
		var k := mean / maxf(rows[y], 0.01)
		for x in w:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k))
