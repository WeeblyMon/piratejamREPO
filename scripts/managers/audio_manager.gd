extends Node


#-----------
#to use this, here are examples:
# Play an SFX
#AudioManager.play_sfx("gunshot_1")
#play music track
#AudioManager.play_music("music_track_1", volume_db=-5.0, loop=true)
#stop music
#AudioManager.stop_music("music_track_1")

var sfx_sounds: Dictionary
var music_tracks: Dictionary

@onready var music_track_1: AudioStreamPlayer = $Music_Track_1  # Placeholder music track

func _ready() -> void:
	sfx_sounds = {
		"scream_2": $Scream_2,
		"scream_1": $Scream_1,
		"reload_1": $Reload_1,
		"pain_2": $Pain_2,
		"pain_1": $Pain_1,
		"mission_failed_1": $Mission_Failed_1,
		"mission_complete_1": $Mission_Complete_1,
		"menu_navigation_ding_1": $Menu_Navigation_Ding_1,
		"menu_navigation_confirm_1": $Menu_Navigation_Confirm_1,
		"gun_jam_1": $Gun_Jam_1,
		"gunshot_1": $Gunshot_1,
		"grunt_2": $Grunt_2,
		"grunt_1": $Grunt_1,
		"footsteps_wood_1_2": $Footsteps_Wood_1_2,
		"footsteps_wood_1_1": $Footsteps_Wood_1_1,
		"footsteps_asphalt_1_2": $Footsteps_Asphalt_1_2,
		"footsteps_asphalt_1_1": $Footsteps_Asphalt_1_1,
		"enemy_hit_and_blood_1": $Enemy_Hit_And_Blood_1,
		"enemy_hit_1": $Enemy_Hit_1,
		"enemy_hit_1_1": $Enemy_Hit_1_1,
		"enemy_hit_1_2": $Enemy_Hit_1_2,
		"death_1": $Death_1,
		"collision_ping_1": $Collision_Ping_1,
		"casing_drop_1": $Casing_Drop_1,
		"bullet_slow_mo_1": $Bullet_Slow_Mo_1,
		"bullet_impact_1": $Bullet_Impact_1,
	}

	music_tracks = {
		"music_track_1": $Music_Track_1,
	}


	for sound in sfx_sounds.values():
		sound.bus = "SFX"  
		sound.stop()

	for music in music_tracks.values():
		music.bus = "Music"  
		music.stop()

func play_sfx(sound_name: String, volume_db: float = 0.0, loop: bool = false) -> void:
	if sfx_sounds.has(sound_name):
		var player = sfx_sounds[sound_name]
		player.volume_db = volume_db
		player.loop = loop
		player.play()
	else:
		push_warning("SFX sound not found: %s" % sound_name)


func play_music(track_name: String, volume_db: float = 0.0, loop: bool = true) -> void:
	if music_tracks.has(track_name):
		var player = music_tracks[track_name]
		player.volume_db = volume_db
		player.loop = loop
		player.play()
	else:
		push_warning("Music track not found: %s" % track_name)


func stop_sfx(sound_name: String) -> void:
	if sfx_sounds.has(sound_name):
		sfx_sounds[sound_name].stop()
	else:
		push_warning("SFX sound not found: %s" % sound_name)


func stop_all_sfx() -> void:
	for sound in sfx_sounds.values():
		sound.stop()

func stop_music(track_name: String) -> void:
	if music_tracks.has(track_name):
		music_tracks[track_name].stop()
	else:
		push_warning("Music track not found: %s" % track_name)

func stop_all_music() -> void:
	for music in music_tracks.values():
		music.stop()

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
