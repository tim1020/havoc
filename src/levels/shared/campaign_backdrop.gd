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
	elif level_number == 3:
		draw_underworld()
	elif level_number == 4:
		draw_peach_garden()
	else:
		draw_heaven_gate()


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


func draw_peach_garden() -> void:
	var colors := [Color("5f815d"), Color("427f83"), Color("896c8b"), Color("4f704f")]
	for section in 4:
		draw_rect(Rect2(section * SECTION_WIDTH, 0, SECTION_WIDTH, 720), colors[section])
	# 4-1 桃林小径
	for x in [120.0, 360.0, 650.0, 940.0, 1160.0]:
		draw_line(Vector2(x, 620), Vector2(x, 270), Color("704a35"), 24, true)
		for angle in range(0, 360, 45):
			var point := Vector2(x, 250) + Vector2.from_angle(deg_to_rad(angle)) * 78.0
			draw_circle(point, 43, Color("e889a1"))
	# 4-2 瑶池木桥
	var offset := SECTION_WIDTH
	draw_rect(Rect2(offset, 500, SECTION_WIDTH, 180), Color("4b9cad"), true)
	for x in range(80, 1200, 170):
		draw_circle(Vector2(offset + x, 535 + (x % 2) * 45), 48, Color("70b978"))
	draw_arc(Vector2(offset + 640, 470), 420, PI, TAU, 36, Color("edc978"), 14, true)
	# 4-3 七彩瑶台
	offset = SECTION_WIDTH * 2
	draw_circle(Vector2(offset + 640, 610), 390, Color("d8c6dd"))
	for index in 7:
		var x := offset + 180 + index * 150
		draw_bezier(PackedVector2Array([Vector2(x, 80), Vector2(x + 80, 240), Vector2(x - 70, 370), Vector2(x + 25, 520)]), Color.from_hsv(index / 7.0, 0.55, 0.95), 9)
	# 4-4 巨蟠桃树
	offset = SECTION_WIDTH * 3
	draw_line(Vector2(offset + 640, 650), Vector2(offset + 640, 115), Color("65452f"), 110, true)
	for angle in range(0, 360, 30):
		var point := Vector2(offset + 640, 170) + Vector2.from_angle(deg_to_rad(angle)) * 270.0
		draw_circle(point, 115, Color("d77e96"))
	for x in [300.0, 640.0, 980.0]:
		draw_circle(Vector2(offset + x, 235), 42, Color("f3ae75"))


func draw_bezier(points: PackedVector2Array, color: Color, width: float) -> void:
	var curve := Curve2D.new()
	curve.add_point(points[0], Vector2.ZERO, points[1] - points[0])
	curve.add_point(points[3], points[2] - points[3], Vector2.ZERO)
	draw_polyline(curve.tessellate(5, 3.0), color, width, true)


func draw_heaven_gate() -> void:
	var colors := [Color("6fa9ca"), Color("5d93bd"), Color("527fa9"), Color("456f98")]
	for section in 4:
		draw_rect(Rect2(section * SECTION_WIDTH, 0, SECTION_WIDTH, 720), colors[section])
	# 5-1 云海浮台
	for x in range(80, 1260, 180):
		draw_circle(Vector2(x, 560 + (x % 3) * 18), 90, Color("e9f3f5"))
		draw_circle(Vector2(x + 65, 585), 70, Color("d7e5eb"))
	# 5-2 下层天梯
	var offset := SECTION_WIDTH
	for index in 8:
		var rect := Rect2(offset + 80 + index * 150, 620 - index * 55, 190, 32)
		draw_rect(rect, Color("d8d8d0"), true)
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("f1d36b"), 5, true)
	# 5-3 幻影天梯
	offset = SECTION_WIDTH * 2
	for x in [140.0, 420.0, 700.0, 980.0, 1180.0]:
		draw_line(Vector2(offset + x, 120), Vector2(offset + x, 620), Color("e1e4e8"), 18, true)
		draw_circle(Vector2(offset + x, 125), 34, Color("f5d86d"))
	draw_arc(Vector2(offset + 640, 590), 390, PI, TAU, 40, Color("f6e4a0"), 12, true)
	# 5-4 南天门广场
	offset = SECTION_WIDTH * 3
	for x in [180.0, 390.0, 890.0, 1100.0]:
		draw_line(Vector2(offset + x, 120), Vector2(offset + x, 625), Color("eee8db"), 34, true)
		draw_circle(Vector2(offset + x, 115), 42, Color("e5c35c"))
	draw_rect(Rect2(offset + 420, 150, 440, 470), Color("c94f43"), true)
	draw_rect(Rect2(offset + 420, 150, 440, 470), Color("f3d370"), false, 14)
