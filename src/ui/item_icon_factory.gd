class_name ItemIconFactory
extends RefCounted

static var cache: Dictionary[StringName, Texture2D] = {}


static func create(item: ItemDefinition) -> Texture2D:
	if cache.has(item.id):
		return cache[item.id]
	var symbol := symbol_path(item.id)
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'><circle cx='32' cy='32' r='29' fill='#17120e' stroke='%s' stroke-width='4'/><path d='%s' fill='%s' stroke='#fff4cf' stroke-width='3' stroke-linejoin='round'/></svg>" % [item.color.to_html(false), symbol, item.color.to_html(false)]
	var image := Image.new()
	image.load_svg_from_string(svg, 1.0)
	var texture := ImageTexture.create_from_image(image)
	cache[item.id] = texture
	return texture


static func symbol_path(item_id: StringName) -> String:
	var paths := {
		&"peach": "M32 15 C49 13 54 31 46 44 C39 55 25 55 18 44 C10 31 15 15 32 15 Z M32 15 Q38 7 46 10",
		&"wine": "M22 15 H42 L39 24 V49 H25 V24 Z M24 32 H40",
		&"elixir": "M32 13 L48 25 L43 46 L32 53 L21 46 L16 25 Z",
		&"life_hair": "M18 47 Q29 8 46 17 Q30 24 44 50",
		&"fire_spear": "M13 36 L45 18 L50 13 L47 24 L52 29 L43 30 L20 49 Z",
		&"cosmic_ring": "M32 14 A18 18 0 1 1 31.9 14 M32 23 A9 9 0 1 0 32.1 23",
		&"fire_wheels": "M18 38 A14 14 0 1 1 45 38 A14 14 0 1 1 18 38 M32 9 L38 24 L26 24 Z",
		&"purple_bell": "M20 42 Q23 16 32 15 Q41 16 44 42 Z M26 48 H38",
		&"monkey_hair": "M17 49 Q26 10 34 17 Q42 24 48 12 Q43 35 31 50",
		&"binding_rope": "M18 23 C18 10 46 10 46 23 C46 36 18 28 18 41 C18 54 46 54 46 41",
		&"heaven_seal": "M16 20 H48 V47 H16 Z M23 13 H41 V20 M24 29 H40 V39 H24 Z",
	}
	return paths.get(item_id, "M18 18 H46 V46 H18 Z")
