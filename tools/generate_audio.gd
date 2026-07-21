extends SceneTree

const SAMPLE_RATE := 22050
const OUTPUT_DIR := "res://assets/audio/generated"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var themes := {
		"menu": [220.0, 330.0], "level_01": [262.0, 392.0], "level_02": [196.0, 294.0],
		"level_03": [147.0, 220.0], "level_04": [294.0, 440.0], "level_05": [247.0, 370.0], "level_06": [165.0, 247.0],
	}
	for name: String in themes:
		write_wave("%s/%s.wav" % [OUTPUT_DIR, name], 6.0, themes[name][0], themes[name][1], 0.17, true)
	write_wave("%s/attack.wav" % OUTPUT_DIR, 0.16, 520.0, 180.0, 0.28, false)
	write_wave("%s/hit.wav" % OUTPUT_DIR, 0.18, 150.0, 70.0, 0.32, false)
	write_wave("%s/player_hurt.wav" % OUTPUT_DIR, 0.32, 520.0, 110.0, 0.85, false)
	write_wave("%s/enemy_attack.wav" % OUTPUT_DIR, 0.16, 430.0, 130.0, 0.42, false)
	write_wave("%s/enemy_throw.wav" % OUTPUT_DIR, 0.20, 900.0, 220.0, 0.38, false)
	write_wave("%s/enemy_hurt.wav" % OUTPUT_DIR, 0.18, 210.0, 75.0, 0.48, false)
	write_wave("%s/enemy_death.wav" % OUTPUT_DIR, 0.42, 145.0, 35.0, 0.52, false)
	write_wave("%s/pickup.wav" % OUTPUT_DIR, 0.28, 660.0, 990.0, 0.25, false)
	write_wave("%s/victory.wav" % OUTPUT_DIR, 0.75, 392.0, 784.0, 0.25, false)
	print("GENERATED 16 AUDIO FILES")
	quit(0)


func write_wave(path: String, duration: float, frequency_a: float, frequency_b: float, amplitude: float, musical: bool) -> void:
	var sample_count := int(SAMPLE_RATE * duration)
	var data_size := sample_count * 2
	var bytes := PackedByteArray()
	bytes.resize(44 + data_size)
	write_text(bytes, 0, "RIFF")
	bytes.encode_u32(4, 36 + data_size)
	write_text(bytes, 8, "WAVEfmt ")
	bytes.encode_u32(16, 16)
	bytes.encode_u16(20, 1)
	bytes.encode_u16(22, 1)
	bytes.encode_u32(24, SAMPLE_RATE)
	bytes.encode_u32(28, SAMPLE_RATE * 2)
	bytes.encode_u16(32, 2)
	bytes.encode_u16(34, 16)
	write_text(bytes, 36, "data")
	bytes.encode_u32(40, data_size)
	for index in sample_count:
		var time := float(index) / SAMPLE_RATE
		var progress := float(index) / sample_count
		var frequency := lerpf(frequency_a, frequency_b, progress) if not musical else (frequency_a if fmod(time, 1.5) < 0.75 else frequency_b)
		var envelope := 1.0 if musical else sin(PI * progress)
		var value := sin(TAU * frequency * time) * 0.72 + sin(TAU * frequency * 0.5 * time) * 0.28
		bytes.encode_s16(44 + index * 2, int(clampf(value * amplitude * envelope, -1.0, 1.0) * 32767.0))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)


func write_text(bytes: PackedByteArray, offset: int, value: String) -> void:
	var text_bytes := value.to_ascii_buffer()
	for index in text_bytes.size():
		bytes[offset + index] = text_bytes[index]
