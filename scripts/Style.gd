class_name Style
extends RefCounted
## Borderlands-style material helpers: flat cel/toon shading plus a bold black
## ink outline (inverted-hull via a culled-front grown next_pass). Materials are
## cached by colour so the whole army can share a handful of resources.

static var _cache: Dictionary = {}

const OUTLINE_COLOR := Color(0.05, 0.05, 0.07)

## A toon-shaded material with an ink outline. `outline` is the hull grow width
## in world units (0 disables the outline).
static func toon(color: Color, outline: float = 0.03) -> StandardMaterial3D:
	var key := "%s|%f" % [color.to_html(true), outline]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic = 0.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	if outline > 0.0:
		m.next_pass = _outline(outline)
	_cache[key] = m
	return m

## A toon material with no outline (for large flat surfaces like the ground).
static func flat(color: Color) -> StandardMaterial3D:
	return toon(color, 0.0)

static func _outline(width: float) -> StandardMaterial3D:
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.albedo_color = OUTLINE_COLOR
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = width
	return o
