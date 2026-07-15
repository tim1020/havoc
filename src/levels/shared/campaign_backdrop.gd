class_name CampaignBackdrop
extends Node2D

const SECTION_WIDTH := 1280.0

var level_number: int


func _init(value: int = 2) -> void:
	level_number = value
	z_index = -20


func _draw() -> void:
	if level_number == 2:
		draw_dragon_palace()
	else:
		draw_underworld()


func draw_dragon_palace() -> void:
	var colors := [Color("163f55"), Color("17374f"), Color("24485e"), Color("4d493c")]
	for section in 4:
		draw_rect(Rect2(section * SECTION_WIDTH, 0, SECTION_WIDTH, 720), colors[section])
	# 2-1 珊瑚走廊
	for x in [120.0, 360.0, 690.0, 1020.0]:
		draw_line(Vector2(x, 620), Vector2(x, 390), Color("c65e73"), 12, true)
		draw_arc(Vector2(x, 420), 65, PI, TAU, 16, Color("ef8291"), 8, true)
		draw_line(Vector2(x, 490), Vector2(x - 55, 430), Color("c65e73"), 8, true)
	for x in range(80, 1280, 210):
		draw_circle(Vector2(x, 150 + (x % 3) * 38), 7, Color("92dbea"))
	# 2-2 水晶回廊
	var offset := SECTION_WIDTH
	for x in [100.0, 340.0, 590.0, 880.0, 1130.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(offset + x, 620), Vector2(offset + x + 55, 300), Vector2(offset + x + 110, 620)]), Color("5bbbd0"))
		draw_polyline(PackedVector2Array([Vector2(offset + x, 620), Vector2(offset + x + 55, 300), Vector2(offset + x + 110, 620)]), Color("b5eff8"), 5, true)
	draw_line(Vector2(offset, 205), Vector2(offset + SECTION_WIDTH, 205), Color("8ad9e9"), 5, true)
	# 2-3 龟丞相竞技场
	offset = SECTION_WIDTH * 2
	draw_arc(Vector2(offset + 640, 625), 430, PI, TAU, 48, Color("73d6df"), 15, true)
	for x in [220.0, 1060.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(offset + x - 80, 610), Vector2(offset + x, 270), Vector2(offset + x + 80, 610)]), Color("4e9dad"))
	# 2-4 龙王大殿
	offset = SECTION_WIDTH * 3
	for x in range(80, 1280, 160):
		draw_line(Vector2(offset + x, 130), Vector2(offset + x, 600), Color("d4b157"), 6, true)
		for y in range(160, 560, 70):
			draw_circle(Vector2(offset + x, y), 8, Color("eff3c0"))
	draw_colored_polygon(PackedVector2Array([Vector2(offset + 470, 600), Vector2(offset + 535, 335), Vector2(offset + 745, 335), Vector2(offset + 810, 600)]), Color("9b633d"))
	draw_arc(Vector2(offset + 640, 350), 95, PI, TAU, 24, Color("f0c66a"), 12, true)


func draw_underworld() -> void:
	var colors := [Color("2b1c3c"), Color("21172f"), Color("302038"), Color("1b1726")]
	for section in 4:
		draw_rect(Rect2(section * SECTION_WIDTH, 0, SECTION_WIDTH, 720), colors[section])
	# 3-1 奈何桥
	for x in range(0, 1281, 120):
		draw_line(Vector2(x, 515), Vector2(x + 40, 620), Color("6a6772"), 7, true)
		draw_line(Vector2(x, 515), Vector2(x + 120, 515), Color("8a8791"), 6, true)
	for x in [130.0, 480.0, 920.0, 1160.0]:
		draw_circle(Vector2(x, 610), 12, Color("c83d50"))
		draw_line(Vector2(x, 610), Vector2(x, 575), Color("8f394a"), 4, true)
	# 3-2 恶鬼道
	var offset := SECTION_WIDTH
	for x in [160.0, 430.0, 710.0, 980.0, 1190.0]:
		draw_line(Vector2(offset + x, 0), Vector2(offset + x + 25, 460), Color("5e5967"), 11, true)
		for y in range(70, 430, 55):
			draw_circle(Vector2(offset + x + int(y / 15) % 12, y), 9, Color("8b8592"), false, 3)
	for x in [310.0, 840.0]:
		draw_arc(Vector2(offset + x, 590), 70, 0, TAU, 32, Color("8346ad"), 9, true)
	# 3-3 鬼门关
	offset = SECTION_WIDTH * 2
	draw_rect(Rect2(offset + 360, 180, 560, 440), Color("302c38"), true)
	draw_rect(Rect2(offset + 360, 180, 560, 440), Color("8e7687"), false, 12)
	for x in [430.0, 850.0]:
		draw_circle(Vector2(offset + x, 360), 78, Color("4c394f"))
		draw_circle(Vector2(offset + x - 22, 345), 9, Color("70d9e4"))
		draw_circle(Vector2(offset + x + 22, 345), 9, Color("70d9e4"))
	# 3-4 森罗殿
	offset = SECTION_WIDTH * 3
	for x in [170.0, 430.0, 850.0, 1110.0]:
		draw_line(Vector2(offset + x, 180), Vector2(offset + x, 620), Color("713d43"), 18, true)
		draw_circle(Vector2(offset + x, 180), 24, Color("d9c3a4"))
	draw_rect(Rect2(offset + 440, 380, 400, 210), Color("3e2837"), true)
	draw_rect(Rect2(offset + 440, 380, 400, 210), Color("b38a55"), false, 8)
