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
		&"freeze_talisman": "M22 12 H42 V52 H22 Z M26 20 H38 M26 30 H38 M26 40 H38",
		&"invisibility_talisman": "M12 32 C20 17 44 17 52 32 C44 47 20 47 12 32 M32 24 A8 8 0 1 1 31.9 24",
		&"samadhi_fire": "M32 12 C45 26 44 37 32 53 C18 39 18 27 32 12 M32 29 C38 36 35 42 32 46 C28 42 26 36 32 29",
		&"banana_fan": "M32 51 C12 42 13 17 28 12 C45 9 54 28 42 45 Z M31 18 L34 45",
		&"purple_bell": "M20 42 Q23 16 32 15 Q41 16 44 42 Z M26 48 H38",
	}
	return paths.get(item_id, "M18 18 H46 V46 H18 Z")
