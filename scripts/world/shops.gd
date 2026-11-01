class_name Shops
extends RefCounted
## The lounge's 2F shop units (user request: the 2F's walls are where the shops go, every one a different size, eight
## for now; then "간판이랑 안에 있는 것 모두 빼, 공간만": no signs, no fronts, nothing inside — empty rooms to be fitted
## out later). Each unit is a room behind one of the 2F's three walls — nothing else stands there at that height: the
## west and east walls are the building's ends, the north units sit over open ground or, the big one (n2, facing the
## escalators' tops), a floor above the strip, the storage room and security, so its lights reach no further than its
## own floor (no light casts shadows here). Its opening is cut into the wall (Terminal._build_upper_floor asks
## openings()); the room is a floor, walls, a ceiling with its fittings and a threshold strip in the opening, lit by
## the "shops" zone (ch1 turns it on with the hall).
##
## A unit's frame: x across its front (-w/2..w/2), y up from the 2F floor, z from its back wall (-depth) to the wall
## line (0), +z toward the gallery.

const H := 3.6               # a unit's ceiling over the 2F floor
const FRONT_H := 3.4         # its opening
const PIER := 0.35           # wall kept either side of the opening
const TALL_H := 4.6          # the big unit's (n2)
const TALL_FRONT_H := 4.0
const TALL_PIER := 0.6

## wall "n" = the 2F's north wall (z -2.5; a..b along x), "w" / "e" = the west (x -20) / east (x 44) wall (a..b along
## z); the unit runs `depth` back from it; `tall` = the big unit's height and opening.
const UNITS := [
	{"id": "n1", "wall": "n", "a": -19.4, "b": -12.8, "depth": 6.0},
	{"id": "n2", "wall": "n", "a": 2.6, "b": 22.6, "depth": 14.0, "tall": true},
	{"id": "n3", "wall": "n", "a": 35.4, "b": 43.6, "depth": 7.5},
	{"id": "w1", "wall": "w", "a": 0.6, "b": 5.6, "depth": 4.5},
	{"id": "w2", "wall": "w", "a": 34.0, "b": 38.5, "depth": 3.5},
	{"id": "e1", "wall": "e", "a": 1.0, "b": 10.0, "depth": 6.5},
	{"id": "e2", "wall": "e", "a": 13.5, "b": 20.5, "depth": 5.5},
	{"id": "e3", "wall": "e", "a": 25.0, "b": 39.0, "depth": 10.0},
]

static var _rects: Array = []


static func width(u: Dictionary) -> float:
	return float(u["b"]) - float(u["a"])


static func height(u: Dictionary) -> float:
	return TALL_H if u.get("tall", false) else H


static func front_h(u: Dictionary) -> float:
	return TALL_FRONT_H if u.get("tall", false) else FRONT_H


static func pier(u: Dictionary) -> float:
	return TALL_PIER if u.get("tall", false) else PIER


## The unit's frame on the 2F floor (see the class notes).
static func frame(u: Dictionary) -> Transform3D:
	var mid := (float(u["a"]) + float(u["b"])) * 0.5
	match u["wall"]:
		"n":
			return Transform3D(Basis(), Vector3(mid, Terminal.MEZZ_Y, -2.5))
		"w":
			return Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-20.0, Terminal.MEZZ_Y, mid))
		_:
			return Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(Terminal.HALL_E, Terminal.MEZZ_Y, mid))


## The openings to cut into `wall` ("n", "w" or "e") for Geo.wall: offsets from the wall's start (x -20 for the north
## wall, z -2.5 for the others), the top over its base (MEZZ_Y - 0.1).
static func openings(wall: String) -> Array:
	var out := []
	var start := -20.0 if wall == "n" else -2.5
	for u: Dictionary in UNITS:
		if u["wall"] == wall:
			out.append([float(u["a"]) + pier(u) - start, float(u["b"]) - pier(u) - start, front_h(u) + 0.1])
	return out


## The units' floor footprints (world, up on the 2F).
static func rects() -> Array:
	if _rects.is_empty():
		for u: Dictionary in UNITS:
			_rects.append(_rect(frame(u), Vector2(-width(u) * 0.5, -float(u["depth"])), Vector2(width(u) * 0.5, 0.0)))
	return _rects


## The floor rect lo..hi of a frame `xf`, as an axis-aligned Rect2 round all four corners.
static func _rect(xf: Transform3D, lo: Vector2, hi: Vector2) -> Rect2:
	var r := Rect2()
	for i in 4:
		var p := xf * Vector3(lo.x if i % 2 == 0 else hi.x, 0, lo.y if i < 2 else hi.y)
		r = Rect2(p.x, p.z, 0, 0) if i == 0 else r.expand(Vector2(p.x, p.z))
	return r


## Every unit: floor, side and back walls, ceiling, a threshold strip in the opening; troffers about 4 m apart (every
## other one, chequerwise, throwing light, reaching only a little past the unit's floor); the lounge's smoke.
static func build(t: Terminal) -> void:
	var wall_m := Mats.shader_mat("res://shaders/wall_panel.gdshader", {"color": Color(0.72, 0.72, 0.7),
			"seam_color": Color(0.54, 0.54, 0.52), "panel_w": 1.2, "panel_h": 3.0, "base_height": Terminal.MEZZ_Y})
	var floor_m := Mats.shader_mat("res://shaders/floor_tile.gdshader", {"color_a": Color(0.5, 0.5, 0.49),
			"color_b": Color(0.46, 0.46, 0.45), "grout_color": Color(0.34, 0.34, 0.33), "tile_size": 0.6,
			"roughness_base": 0.25, "roughness_var": 0.2})
	var zone: LightZone = t.zones.shops
	for u: Dictionary in UNITS:
		var root := Node3D.new()
		root.name = "Shop_" + str(u["id"])
		t.add_child(root)
		root.transform = frame(u)
		var w := width(u)
		var d: float = u["depth"]
		var ht := height(u)
		Geo.box(root, Vector3(0, -0.05, -(d + 0.3) * 0.5), Vector3(w + 0.2, 0.1, d - 0.1), floor_m)
		Geo.box(root, Vector3(0, -0.05, -0.05), Vector3(w - 2.0 * pier(u), 0.1, 0.3), Mats.get_mat("metal_dark"))
		for sx in [-1.0, 1.0]:
			Geo.wall(root, Vector2(sx * w * 0.5, -0.2), Vector2(sx * w * 0.5, -d - 0.1), ht + 0.3, wall_m, 0.2, [], -0.1)
		Geo.wall(root, Vector2(-w * 0.5 - 0.1, -d), Vector2(w * 0.5 + 0.1, -d), ht + 0.3, wall_m, 0.2, [], -0.1)
		Geo.box(root, Vector3(0, ht + 0.103, -(d + 0.2) * 0.5), Vector3(w, 0.2, d - 0.2), Mats.get_mat("ceiling"), false)
		t._ceilings.append([_rect(root.transform, Vector2(-w * 0.5, -d), Vector2(w * 0.5, -0.2)), Terminal.MEZZ_Y + ht])
		var turned := absf(root.transform.basis.x.x) < 0.5
		var nx := maxi(1, roundi(w / 4.0))
		var nz := maxi(1, roundi((d - 0.2) / 4.0))
		for ix in nx:
			for iz in nz:
				var p := Vector3(-w * 0.5 + (ix + 0.5) * w / nx, ht - 0.04, -d + (iz + 0.5) * (d - 0.2) / nz)
				zone.add_panel(root.transform * p, Vector2(0.3, 1.2) if turned else Vector2(1.2, 0.3), (ix + iz) % 2 == 0, 1.2, ht + 1.6)
		var r := _rect(root.transform, Vector2(-w * 0.5, -d), Vector2(w * 0.5, -0.2))
		t._smoke(AABB(Vector3(r.position.x, Terminal.MEZZ_Y, r.position.y), Vector3(r.size.x, ht, r.size.y)), hash(u["id"]) % 97)
