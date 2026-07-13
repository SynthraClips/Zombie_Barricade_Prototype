extends Node

var _player_pool: Array[AudioStreamPlayer] = []
var _bus_volume: float = 0.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus_volume = float(SaveManager.save_data.get("settings", {}).get("sfx_volume", 0.8))

func set_sfx_volume(value: float) -> void:
	_bus_volume = clampf(value, 0.0, 1.0)

func clear_sfx() -> void:
	for player in _player_pool:
		if is_instance_valid(player):
			player.stop()
			player.free()
	_player_pool.clear()

func play_sfx(name: String) -> void:
	# Headless validation has no audio device; allocating playback streams there
	# only leaves server-side WAV resources alive during immediate test shutdown.
	if DisplayServer.get_name() == "headless":
		return
	var frequency: float = {
		"gunfire": 740.0,
		"zombie_hit": 320.0,
		"zombie_death": 210.0,
		"explosion": 110.0,
		"reward_pickup": 880.0,
		"upgrade_purchased": 660.0
	}.get(name, 440.0)
	var duration: float = {
		"gunfire": 0.05,
		"zombie_hit": 0.08,
		"zombie_death": 0.12,
		"explosion": 0.2,
		"reward_pickup": 0.14,
		"upgrade_purchased": 0.18
	}.get(name, 0.1)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child(player)
	player_pool_append(player)
	player.volume_db = linear_to_db(clamp(_bus_volume, 0.01, 1.0))
	player.stream = _make_tone(frequency, duration)
	player.play()
	player.finished.connect(player.queue_free)

func player_pool_append(player: AudioStreamPlayer) -> void:
	_player_pool.append(player)
	_player_pool = _player_pool.filter(func(item): return is_instance_valid(item))

func _make_tone(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var frames: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var envelope: float = 1.0 - float(i) / max(1.0, float(frames))
		var sample: float = sin(float(i) * TAU * frequency / float(sample_rate)) * 0.35 * envelope
		var int_sample: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int_sample)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
