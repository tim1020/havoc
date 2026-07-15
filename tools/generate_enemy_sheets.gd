extends SceneTree

const OUTPUT_DIR := "res://assets/vector/characters/campaign"
const FRAME_SIZE := 128

const PROFILES := [
	["staff_wukong", "monkey", "#9b5b34", "#773b2d", "staff"],
	["shrimp_soldier", "shrimp", "#d85c45", "#41677a", "spear"],
	["crab_general", "crab", "#c84f3f", "#744035", "claws"],
	["electric_jellyfish", "jellyfish", "#69cde1", "#4167a8", "spark"],
	["dragon_maiden", "maiden", "#61b9a8", "#c75f8d", "bubble"],
	["turtle_chancellor", "turtle", "#6a9a62", "#855f38", "staff"],
	["dragon_king", "dragon", "#3d9aaa", "#d2a43b", "staff"],
	["wandering_soul", "soul", "#a6b9dc", "#56628a", "wisp"],
	["skeleton_guard", "skeleton", "#ddd3b9", "#6b5743", "shield"],
	["soul_reaper", "reaper", "#39354f", "#8a334d", "chain"],
	["mengpo_attendant", "attendant", "#c8c0b5", "#705d79", "bowl"],
	["ox_guard", "ox", "#866b58", "#4e5965", "axe"],
	["horse_guard", "horse", "#9b6648", "#586b70", "spear"],
	["yanluo_king", "yanluo", "#72445e", "#ba8e35", "brush"],
	["garden_guardian", "guardian", "#c49b5d", "#59804d", "tree"],
	["flower_fairy", "flower_fairy", "#efb0c7", "#7c6ac3", "basket"],
	["peach_demon", "peach_demon", "#855f3d", "#5f8b4f", "branch"],
	["peach_child", "peach_child", "#f1d4ad", "#dc6d6d", "bomb"],
	["fairy_leader", "fairy_leader", "#f0c4dc", "#8c62c5", "ribbon"],
	["peach_land_god", "land_god", "#d3b58b", "#706442", "vine"],
]

const POSES := [
	[0, 0, -2, 2, -18, 18, 0],
	[0, -2, -1, 1, -14, 14, 0],
	[2, 0, -14, 14, 20, -20, -4],
	[1, -1, 14, -14, -20, 20, 4],
	[0, 0, -4, 4, -55, 12, -8],
	[4, 1, -10, 10, 18, -70, 10],
	[-4, 2, -5, 5, 38, -36, -15],
	[-7, 4, -8, 8, 45, -42, -23],
	[12, 15, -8, 8, 25, -25, 58],
	[18, 19, -5, 5, 20, -20, 88],
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for profile in PROFILES:
		var path := "%s/%s_frames.svg" % [OUTPUT_DIR, profile[0]]
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write %s" % path)
			quit(1)
			return
		file.store_string(build_sheet(profile))
	print("GENERATED ", PROFILES.size(), " CHARACTER FRAME SHEETS")
	quit(0)


func build_sheet(profile: Array) -> String:
	var content := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1280\" height=\"128\" viewBox=\"0 0 1280 128\">\n"
	content += "<rect width=\"1280\" height=\"128\" fill=\"none\"/>\n"
	for index in POSES.size():
		content += build_frame(index, POSES[index], profile)
	content += "</svg>\n"
	return content


func build_frame(index: int, pose: Array, profile: Array) -> String:
	var x := index * FRAME_SIZE + 64
	var body_y: int = 68 + pose[1]
	var head_y: int = 35 + pose[0]
	var rotation: int = pose[6]
	var transform := "translate(%d 0) rotate(%d 0 82)" % [x, rotation]
	var main: String = profile[2]
	var cloth: String = profile[3]
	var species: String = profile[1]
	var weapon: String = profile[4]
	var svg := "<g transform=\"%s\" stroke=\"#211b1a\" stroke-width=\"4\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" % transform
	if species == "jellyfish":
		svg += jellyfish_shape(head_y, body_y, main, pose)
	elif species == "crab":
		svg += crab_shape(body_y, main, cloth, pose)
	elif species == "soul":
		svg += soul_shape(head_y, body_y, main, cloth, pose)
	else:
		svg += humanoid_shape(head_y, body_y, main, cloth, pose)
		svg += species_features(species, head_y, body_y, main, cloth)
		svg += weapon_shape(weapon, body_y, pose, main)
	svg += "</g>\n"
	return svg


func humanoid_shape(head_y: int, body_y: int, main: String, cloth: String, pose: Array) -> String:
	var svg := "<path d=\"M-15 %d L%d 113 M15 %d L%d 113\" fill=\"none\" stroke=\"%s\" stroke-width=\"12\"/>" % [body_y + 18, pose[2], body_y + 18, pose[3], main]
	svg += "<path d=\"M-18 %d L%d %d M18 %d L%d %d\" fill=\"none\" stroke=\"%s\" stroke-width=\"11\"/>" % [body_y - 8, pose[4], body_y + 9, body_y - 8, pose[5], body_y + 9, main]
	svg += "<ellipse cx=\"0\" cy=\"%d\" rx=\"25\" ry=\"29\" fill=\"%s\"/><path d=\"M-23 %d Q0 %d 23 %d L18 %d Q0 %d -18 %dZ\" fill=\"%s\"/>" % [body_y, main, body_y - 8, body_y - 18, body_y - 8, body_y + 20, body_y + 28, body_y + 20, cloth]
	svg += "<ellipse cx=\"2\" cy=\"%d\" rx=\"20\" ry=\"21\" fill=\"%s\"/><circle cx=\"9\" cy=\"%d\" r=\"3\" fill=\"#ffe06a\"/>" % [head_y, main, head_y - 2]
	return svg


func species_features(species: String, head_y: int, body_y: int, main: String, cloth: String) -> String:
	match species:
		"shrimp":
			return "<path d=\"M-8 %d Q-24 4 -28 1 M8 %d Q25 5 29 2\" fill=\"none\"/><path d=\"M-21 %d L-30 %d M22 %d L31 %d\" stroke=\"%s\" stroke-width=\"7\"/>" % [head_y - 18, head_y - 18, body_y, body_y + 15, body_y, body_y + 14, main]
		"monkey":
			return "<path d=\"M18 %d Q48 %d 37 %d Q29 %d 45 %d\" fill=\"none\" stroke=\"%s\" stroke-width=\"8\"/><circle cx=\"-17\" cy=\"%d\" r=\"8\" fill=\"%s\"/>" % [body_y + 10, body_y + 8, body_y - 25, body_y - 40, body_y - 52, main, head_y, main]
		"maiden":
			return "<path d=\"M-18 %d Q0 %d 20 112 Q0 101 -20 112Z\" fill=\"%s\"/><circle cx=\"-10\" cy=\"%d\" r=\"3\" fill=\"#e8fbff\"/>" % [body_y + 18, body_y + 7, main, head_y - 17]
		"turtle":
			return "<ellipse cx=\"-5\" cy=\"%d\" rx=\"30\" ry=\"34\" fill=\"%s\"/><path d=\"M-28 %d L18 %d M-23 %d L22 %d\"/>" % [body_y, cloth, body_y - 8, body_y + 18, body_y + 15, body_y - 18]
		"dragon":
			return "<path d=\"M-12 %d L-23 %d L-4 %d M12 %d L24 %d L5 %d\" fill=\"%s\"/><path d=\"M18 %d Q45 %d 38 %d\" fill=\"none\" stroke=\"%s\" stroke-width=\"8\"/>" % [head_y - 15, head_y - 31, head_y - 22, head_y - 15, head_y - 31, head_y - 22, cloth, body_y + 8, body_y, body_y - 24, main]
		"skeleton":
			return "<path d=\"M-14 %d H15 M-13 %d H13\" stroke=\"#f0e8cf\"/><circle cx=\"-6\" cy=\"%d\" r=\"4\" fill=\"#251d1c\"/>" % [body_y - 2, body_y + 9, head_y]
		"reaper":
			return "<path d=\"M-22 %d Q0 %d 24 %d L16 %d Q0 %d -17 %dZ\" fill=\"#171724\"/><path d=\"M20 %d q25 12 14 38\" fill=\"none\" stroke=\"#b8a57d\" stroke-width=\"4\" stroke-dasharray=\"5 5\"/>" % [head_y + 1, head_y - 24, head_y + 2, body_y + 25, body_y + 15, body_y + 25, body_y - 8]
		"attendant":
			return "<path d=\"M-18 %d Q0 %d 18 %d\" fill=\"none\" stroke=\"%s\" stroke-width=\"6\"/><ellipse cx=\"27\" cy=\"%d\" rx=\"13\" ry=\"6\" fill=\"#8c6c43\"/>" % [head_y - 14, head_y - 23, head_y - 14, cloth, body_y]
		"ox":
			return "<path d=\"M-12 %d L-30 %d L-18 %d M14 %d L31 %d L19 %d\" fill=\"#dbc490\"/>" % [head_y - 15, head_y - 28, head_y - 6, head_y - 15, head_y - 28, head_y - 6]
		"horse":
			return "<ellipse cx=\"9\" cy=\"%d\" rx=\"15\" ry=\"28\" fill=\"%s\"/><path d=\"M1 %d L-2 %d M17 %d L20 %d\" stroke=\"%s\" stroke-width=\"8\"/>" % [head_y + 8, main, head_y - 12, head_y - 32, head_y - 12, head_y - 32, main]
		"yanluo":
			return "<path d=\"M-20 %d H23 L16 %d H-15Z\" fill=\"#1d2029\"/><circle cx=\"0\" cy=\"%d\" r=\"5\" fill=\"#d6aa3e\"/>" % [head_y - 18, head_y - 31, head_y - 25]
		"guardian":
			return "<path d=\"M-24 %d L-35 %d L-18 %d M24 %d L35 %d L18 %d\" fill=\"#dbbe74\"/><rect x=\"-25\" y=\"%d\" width=\"50\" height=\"12\" rx=\"5\" fill=\"#cba84d\"/>" % [head_y - 14, head_y - 29, head_y - 7, head_y - 14, head_y - 29, head_y - 7, head_y - 21]
		"flower_fairy", "fairy_leader":
			return "<path d=\"M-20 %d Q0 %d 21 112 Q0 99 -22 112Z\" fill=\"%s\"/><path d=\"M-18 %d Q0 %d 18 %d\" fill=\"none\" stroke=\"#f4d5e6\" stroke-width=\"7\"/>" % [body_y + 18, body_y + 4, cloth, head_y - 15, head_y - 26, head_y - 15]
		"peach_demon":
			return "<path d=\"M-18 %d L-30 %d M17 %d L31 %d M-8 %d Q0 %d 8 %d\" stroke=\"#4d7d43\" stroke-width=\"9\"/><circle cx=\"-18\" cy=\"%d\" r=\"10\" fill=\"#e9859d\"/><circle cx=\"19\" cy=\"%d\" r=\"10\" fill=\"#e9859d\"/>" % [body_y - 12, head_y - 18, body_y - 10, head_y - 20, head_y - 16, head_y - 28, head_y - 16, head_y - 14, head_y - 16]
		"peach_child":
			return "<path d=\"M-42 %d Q-20 %d 0 %d Q20 %d 43 %d\" fill=\"none\" stroke=\"#f2eee0\" stroke-width=\"12\"/><path d=\"M-32 %d L-43 %d M31 %d L43 %d\" stroke=\"#2b3038\" stroke-width=\"5\"/>" % [body_y + 15, body_y - 8, body_y + 10, body_y - 8, body_y + 15, body_y + 9, body_y + 28, body_y + 9, body_y + 28]
		"land_god":
			return "<path d=\"M-18 %d Q0 %d 18 %d\" fill=\"none\" stroke=\"#eeeeea\" stroke-width=\"11\"/><path d=\"M-24 %d H25\" stroke=\"#667343\" stroke-width=\"9\"/>" % [head_y + 12, head_y + 35, head_y + 12, head_y - 18]
	return ""


func weapon_shape(weapon: String, body_y: int, pose: Array, main: String) -> String:
	var hand_x: int = pose[5]
	match weapon:
		"spear": return "<path d=\"M%d %d L%d %d\" stroke=\"#b9a473\" stroke-width=\"5\"/><path d=\"M%d %d l12 -4 -8 11Z\" fill=\"#d9e2df\"/>" % [hand_x, body_y + 7, hand_x + 35, body_y - 29, hand_x + 35, body_y - 29]
		"staff": return "<path d=\"M%d %d L%d %d\" stroke=\"#9a6d32\" stroke-width=\"6\"/>" % [hand_x, body_y + 8, hand_x + 28, body_y - 38]
		"axe": return "<path d=\"M%d %d L%d %d\" stroke=\"#8b6b43\" stroke-width=\"6\"/><path d=\"M%d %d q18 0 20 15 q-14 5 -24 -3Z\" fill=\"#aab2b6\"/>" % [hand_x, body_y + 9, hand_x + 20, body_y - 33, hand_x + 15, body_y - 38]
		"shield": return "<path d=\"M%d %d q18 3 16 28 q-15 16 -27 0 q-2 -24 11 -28Z\" fill=\"#6f5134\"/>" % [hand_x, body_y - 10]
		"bowl": return "<path d=\"M%d %d q14 12 28 0Z\" fill=\"#8b6744\"/>" % [hand_x, body_y]
		"brush": return "<path d=\"M%d %d L%d %d\" stroke=\"#d8b55b\" stroke-width=\"5\"/><path d=\"M%d %d l12 8 -15 8Z\" fill=\"#15151b\"/>" % [hand_x, body_y + 8, hand_x + 22, body_y - 30, hand_x + 22, body_y - 30]
		"bubble": return "<circle cx=\"%d\" cy=\"%d\" r=\"14\" fill=\"none\" stroke=\"#c8f5ff\" stroke-width=\"4\"/>" % [hand_x + 12, body_y - 4]
		"tree": return "<path d=\"M%d %d L%d %d\" stroke=\"#69462f\" stroke-width=\"12\"/><circle cx=\"%d\" cy=\"%d\" r=\"18\" fill=\"#5f984e\"/>" % [hand_x, body_y + 10, hand_x + 28, body_y - 42, hand_x + 28, body_y - 47]
		"basket": return "<path d=\"M%d %d q18 14 36 0Z\" fill=\"#d49b55\"/><path d=\"M%d %d q18 -20 36 0\" fill=\"none\"/>" % [hand_x, body_y, hand_x, body_y]
		"branch": return "<path d=\"M%d %d Q%d %d %d %d M%d %d l12 -18\" fill=\"none\" stroke=\"#5c7d3e\" stroke-width=\"7\"/>" % [hand_x, body_y + 8, hand_x + 22, body_y - 5, hand_x + 39, body_y - 30, hand_x + 25, body_y - 12]
		"bomb": return "<circle cx=\"%d\" cy=\"%d\" r=\"13\" fill=\"#eb849b\"/><path d=\"M%d %d l8 -12\" stroke=\"#5b844c\"/>" % [hand_x + 12, body_y - 3, hand_x + 15, body_y - 14]
		"ribbon": return "<path d=\"M%d %d Q%d %d %d %d Q%d %d %d %d\" fill=\"none\" stroke=\"#f3a7d2\" stroke-width=\"7\"/>" % [hand_x, body_y, hand_x + 38, body_y - 35, hand_x + 52, body_y + 5, hand_x + 65, body_y + 28, hand_x + 82, body_y - 12]
		"vine": return "<path d=\"M%d %d Q%d %d %d %d\" fill=\"none\" stroke=\"#60934f\" stroke-width=\"9\"/>" % [hand_x, body_y + 8, hand_x + 30, body_y - 15, hand_x + 45, body_y - 42]
	return ""


func jellyfish_shape(head_y: int, body_y: int, main: String, pose: Array) -> String:
	var spread: int = 4 + absi(pose[2]) / 4
	return "<path d=\"M-29 %d Q0 %d 29 %d L25 %d H-25Z\" fill=\"%s\"/><path d=\"M-20 %d Q%d %d -10 112 M0 %d Q%d %d 4 114 M18 %d Q%d %d 24 110\" fill=\"none\" stroke=\"%s\" stroke-width=\"6\"/><circle cx=\"9\" cy=\"%d\" r=\"4\" fill=\"#fff36b\"/>" % [body_y, head_y - 23, body_y, body_y + 12, main, body_y + 10, -spread, body_y + 28, body_y + 10, spread, body_y + 30, body_y + 10, spread * 2, body_y + 25, main, head_y]


func crab_shape(body_y: int, main: String, cloth: String, pose: Array) -> String:
	var claw_left: int = pose[4]
	var claw_right: int = pose[5]
	return "<ellipse cx=\"0\" cy=\"%d\" rx=\"35\" ry=\"25\" fill=\"%s\"/><path d=\"M-28 %d L-48 108 M-12 %d L-20 114 M28 %d L48 108 M12 %d L20 114\" fill=\"none\" stroke=\"%s\" stroke-width=\"8\"/><path d=\"M-28 %d L%d %d M28 %d L%d %d\" fill=\"none\" stroke=\"%s\" stroke-width=\"10\"/><circle cx=\"%d\" cy=\"%d\" r=\"12\" fill=\"%s\"/><circle cx=\"%d\" cy=\"%d\" r=\"12\" fill=\"%s\"/><circle cx=\"-12\" cy=\"%d\" r=\"4\" fill=\"#ffe06a\"/><circle cx=\"12\" cy=\"%d\" r=\"4\" fill=\"#ffe06a\"/>" % [body_y, main, body_y + 12, body_y + 15, body_y + 12, body_y + 15, cloth, body_y - 3, claw_left, body_y - 12, body_y - 3, claw_right, body_y - 12, main, claw_left, body_y - 15, main, claw_right, body_y - 15, main, body_y - 14, body_y - 14]


func soul_shape(head_y: int, body_y: int, main: String, cloth: String, pose: Array) -> String:
	return "<circle cx=\"0\" cy=\"%d\" r=\"20\" fill=\"%s\" opacity=\".85\"/><path d=\"M-24 %d Q0 %d 24 %d L17 109 L5 99 L-5 112 L-18 101Z\" fill=\"%s\" opacity=\".78\"/><path d=\"M-20 %d L%d %d M20 %d L%d %d\" stroke=\"%s\" stroke-width=\"9\" fill=\"none\"/><circle cx=\"7\" cy=\"%d\" r=\"3\" fill=\"#f8f0a2\"/>" % [head_y, main, body_y - 20, body_y - 30, body_y - 20, cloth, body_y - 6, pose[4], body_y + 8, body_y - 6, pose[5], body_y + 8, main, head_y - 2]
