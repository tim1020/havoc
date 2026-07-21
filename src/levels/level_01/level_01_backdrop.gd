class_name Level01Backdrop
extends Node2D

const SECTION_WIDTH := 2560.0
const LEVEL_WIDTH := SECTION_WIDTH * 5.0


func _ready() -> void:
	z_index = -20
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, SECTION_WIDTH, 720), Color("dce7d2"))
	draw_rect(Rect2(SECTION_WIDTH, 0, SECTION_WIDTH, 720), Color("c9dfc1"))
	draw_rect(Rect2(SECTION_WIDTH * 2, 0, SECTION_WIDTH, 720), Color("b8ccc1"))
	draw_rect(Rect2(SECTION_WIDTH * 3, 0, SECTION_WIDTH, 720), Color("1d2930"))
	draw_rect(Rect2(SECTION_WIDTH * 4, 0, SECTION_WIDTH, 720), Color("172229"))
	draw_foothill()
	draw_vine_grove()
	draw_cave_entrance()
	draw_cave_interior()


func draw_foothill() -> void:
	var ink := Color("49685a")
	draw_polyline(PackedVector2Array([
		Vector2(0, 430), Vector2(180, 250), Vector2(330, 390),
		Vector2(520, 190), Vector2(720, 410), Vector2(930, 230), Vector2(1280, 420),
	]), ink, 5.0, true)
	for x in [120.0, 360.0, 870.0, 1110.0]:
		draw_line(Vector2(x, 520), Vector2(x, 400), Color("6f5a3c"), 8.0, true)
		draw_circle(Vector2(x, 385), 42, Color("73945f"))
		draw_circle(Vector2(x - 34, 405), 30, Color("73945f"))
		draw_circle(Vector2(x + 36, 405), 30, Color("73945f"))


func draw_vine_grove() -> void:
	var offset := SECTION_WIDTH
	var ink := Color("3e6c4c")
	for x in [90.0, 330.0, 570.0, 830.0, 1090.0]:
		var world_x: float = offset + float(x)
		draw_line(Vector2(world_x, 650), Vector2(world_x + 45, 210), Color("5b4933"), 12.0, true)
		draw_arc(Vector2(world_x + 75, 300), 95, PI * 0.55, PI * 1.45, 24, ink, 7.0, true)
		draw_arc(Vector2(world_x - 35, 430), 68, -PI * 0.4, PI * 0.7, 18, ink, 5.0, true)
	for y in [180.0, 280.0, 380.0]:
		draw_bezier(Vector2(offset, y), Vector2(offset + 350, y + 120), Vector2(offset + 870, y - 90), Vector2(offset + 1280, y + 40), ink)


func draw_cave_entrance() -> void:
	var offset := SECTION_WIDTH * 2
	var rock := Color("52666a")
	draw_polyline(PackedVector2Array([
		Vector2(offset, 470), Vector2(offset + 160, 270), Vector2(offset + 360, 180),
		Vector2(offset + 640, 140), Vector2(offset + 910, 190), Vector2(offset + 1120, 310),
		Vector2(offset + 1280, 480),
	]), rock, 18.0, true)
	draw_arc(Vector2(offset + 640, 600), 330, PI, TAU, 48, Color("26383d"), 22.0, true)
	for x in [160.0, 350.0, 950.0, 1130.0]:
		draw_line(Vector2(offset + x, 520), Vector2(offset + x + 55, 380), rock, 9.0, true)
		draw_circle(Vector2(offset + x + 60, 360), 26, Color("718d76"))


func draw_cave_interior() -> void:
	var offset := SECTION_WIDTH * 3
	var wall := Color("52626a")
	for x in range(0, 1281, 160):
		var height := 110.0 + float((x / 160) % 3) * 45.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(offset + x, 0), Vector2(offset + x + 80, 0),
			Vector2(offset + x + 35, height),
		]), wall)
	for x in [180.0, 520.0, 850.0, 1120.0]:
		draw_line(Vector2(offset + x, 610), Vector2(offset + x + 40, 260), Color("42535b"), 14.0, true)
		draw_circle(Vector2(offset + x + 40, 245), 24, Color("d3a74a"))
		draw_circle(Vector2(offset + x + 40, 245), 10, Color("ffe08a"))
	draw_polyline(PackedVector2Array([
		Vector2(offset, 560), Vector2(offset + 260, 490), Vector2(offset + 520, 550),
		Vector2(offset + 800, 470), Vector2(offset + 1040, 540), Vector2(offset + 1280, 480),
	]), Color("7a8a8f"), 7.0, true)


func draw_bezier(from: Vector2, control_a: Vector2, control_b: Vector2, to: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 25:
		var t := float(index) / 24.0
		var point := from * pow(1.0 - t, 3.0)
		point += control_a * 3.0 * pow(1.0 - t, 2.0) * t
		point += control_b * 3.0 * (1.0 - t) * t * t
		point += to * t * t * t
		points.append(point)
	draw_polyline(points, color, 5.0, true)
