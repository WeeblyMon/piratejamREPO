extends Node

var sfx_sounds: Dictionary = {}
var music_tracks: Dictionary = {}

#exampple uses
#AudioManager.play_sfx("gunshot_1", volume_db=-5.0)
#AudioManager.play_music("music_track_1", volume_db=-10.0, loop=true)
#AudioManager.stop_sfx("gunshot_1")
#AudioManager.stop_music("music_track_1")

@export var audio_files: Dictionary = {
	"sfx": {
		"scream_1": "res://assets/audio/sfx/Scream_1.mp3",
		"scream_2": "res://assets/audio/sfx/Scream_2.mp3",
		"reload_1": "res://assets/audio/sfx/Reload_1.mp3",
		"pain_1": "res://assets/audio/sfx/Pain_1.mp3",
		"pain_2": "res://assets/audio/sfx/Pain_2.mp3",
		"mission_failed_1": "res://assets/audio/sfx/Mission_Failed_1.mp3",
		"mission_complete_1": "res://assets/audio/sfx/Mission_Complete_1.mp3",
		"menu_navigation_ding_1": "res://assets/audio/sfx/Menu_Navigation_Ding_1.mp3",
		"menu_navigation_confirm_1": "res://assets/audio/sfx/Menu_Navigation_Confirm_1.mp3",
		"menu_navigation_back_1": "res://assets/audio/sfx/Menu_Navigation_Back_1.mp3",
		"gun_jam_1": "res://assets/audio/sfx/Gun_Jam_1.mp3",
		"gunshot_1": "res://assets/audio/sfx/Gunshot_1.mp3",
		"handgun_shot": "res://assets/audio/sfx/pistol-shot.mp3",
		"rifle_shot": "res://assets/audio/sfx/sniper-rifle.mp3",
		"shotgun_shot": "res://assets/audio/sfx/shotgun-firing.mp3",
		"grunt_1": "res://assets/audio/sfx/Grunt_1.mp3",
		"grunt_2": "res://assets/audio/sfx/Grunt_2.mp3",
		"footsteps_wood_1_1": "res://assets/audio/sfx/Footsteps_Wood_1.1.mp3",
		"footsteps_wood_1_2": "res://assets/audio/sfx/Footsteps_Wood_1.2.mp3",
		"footsteps_asphalt_1_1": "res://assets/audio/sfx/Footsteps_Asphalt_1.1.mp3",
		"footsteps_asphalt_1_2": "res://assets/audio/sfx/Footsteps_Asphalt_1.2.mp3",
		"enemy_hit_1": "res://assets/audio/sfx/Enemy_Hit_1.mp3",
		"enemy_hit_1_1": "res://assets/audio/sfx/Enemy_Hit_1.1.mp3",
		"enemy_hit_1_2": "res://assets/audio/sfx/Enemy_Hit_1.2.mp3",
		"enemy_hit_and_blood_1": "res://assets/audio/sfx/Enemy_Hit_And_Blood_1.mp3",
		"death_1": "res://assets/audio/sfx/Death_1.mp3",
		"collision_ping_1": "res://assets/audio/sfx/Collision_Ping_1.mp3",
		"casing_drop_1": "res://assets/audio/sfx/Casing_Drop_1.mp3",
		"bullet_slow_mo_1": "res://assets/audio/sfx/Bullet_Slow_Mo_1.mp3",
		"bullet_impact_1": "res://assets/audio/sfx/Bullet_Impact_1.mp3",
		"bullet_steering_1": "res://assets/audio/sfx/Bullet_Steering_1.mp3",
		"crowd_chatter_1": "res://assets/audio/sfx/Crowd_Chatter_1.mp3",
		"explosion_1": "res://assets/audio/sfx/Explosion_1.mp3",
		"explosion_2": "res://assets/audio/sfx/Explosion_2.mp3",
		"sanity_heartbeat_1": "res://assets/audio/sfx/Sanity_Heartbeat_1.mp3",
		"siren_passing_by_1": "res://assets/audio/sfx/Siren_Passing_By_1.mp3",
		"tv_static_1": "res://assets/audio/sfx/TV_Static_1.mp3",
		"wood_break_1": "res://assets/audio/sfx/Wood_Break_1.mp3",
		"wood_break_2": "res://assets/audio/sfx/Wood_Break_2.mp3"
	},
	"music": {
		"music_track_1": "res://assets/audio/music/Normal_Theme_Sketch_1.1.mp3",
		"level_music": "res://assets/audio/music/Mission_Theme_V2.mp3",
		"main menu": "res://assets/audio/music/Normal_Theme_V2.mp3"
	}
}
func _ready() -> void:
	for sfx_name in audio_files["sfx"].keys():
		var player = AudioStreamPlayer.new()
		player.stream = load(audio_files["sfx"][sfx_name])
		player.bus = "SFX"
		add_child(player)
		sfx_sounds[sfx_name] = player
		
	for music_name in audio_files["music"].keys():
		var player = AudioStreamPlayer.new()
		player.stream = load(audio_files["music"][music_name])
		player.bus = "Music"
		add_child(player)
		music_tracks[music_name] = player

func play_sfx(sound_name: String, volume_db: float = 0.0, loop: bool = false) -> void:
	if sfx_sounds.has(sound_name):
		var player = sfx_sounds[sound_name]
		player.volume_db = volume_db
		if player.stream is AudioStream:
			player.stream.loop = loop
		player.play()
	else:
		push_warning("SFX sound not found: %s" % sound_name)

func play_sfx_varied(sound_name: String, volume_db: float = 0.0, loop: bool = false, min_pitch: float = 0.9, max_pitch: float = 1.1) -> void:
	if sfx_sounds.has(sound_name):
		var player = sfx_sounds[sound_name]
		player.volume_db = volume_db
		if player.stream is AudioStream:
			player.stream.loop = loop
		var random_pitch = randf_range(min_pitch, max_pitch)
		player.pitch_scale = random_pitch
		player.play()
	else:
		push_warning("SFX sound not found: %s" % sound_name)


func play_music(track_name: String, volume_db: float = 0.0, loop: bool = true) -> void:
	if music_tracks.has(track_name):
		var player = music_tracks[track_name]
		player.volume_db = volume_db
		if player.stream is AudioStream:
			player.stream.loop = loop
		player.play()
	else:
		push_warning("Music track not found: %s" % track_name)

func stop_sfx(sound_name: String) -> void:
	if sfx_sounds.has(sound_name):
		sfx_sounds[sound_name].stop()
	else:
		push_warning("SFX sound not found: %s" % sound_name)

func stop_all_sfx() -> void:
	for player in sfx_sounds.values():
		player.stop()

func stop_music(track_name: String) -> void:
	if music_tracks.has(track_name):
		music_tracks[track_name].stop()
	else:
		push_warning("Music track not found: %s" % track_name)

func stop_all_music() -> void:
	for player in music_tracks.values():
		player.stop()

func set_sfx_volume(volume_db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), volume_db)

func set_music_volume(volume_db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), volume_db)

func is_sfx_playing(sound_name: String) -> bool:
	if sfx_sounds.has(sound_name):
		return sfx_sounds[sound_name].is_playing()
	return false

func is_music_playing(track_name: String) -> bool:
	if music_tracks.has(track_name):
		return music_tracks[track_name].is_playing()
	return false
