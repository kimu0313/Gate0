class_name UiArt
extends RefCounted
## Generated UI art in assets/ui/ (tablet bezel, binder cover and rings, paper, stamp ink, clip, keypad,
## staff card). Every caller keeps a code-drawn fallback, so a missing texture never breaks a screen.

const DIR := "res://assets/ui/"
static var _cache := {}


static func tex(name_id: String) -> Texture2D:
	if _cache.has(name_id):
		return _cache[name_id]
	var t: Texture2D = null
	for ext in [".png", ".jpg"]:
		var path: String = DIR + name_id + ext
		if ResourceLoader.exists(path):
			t = load(path)
			break
	_cache[name_id] = t
	return t
