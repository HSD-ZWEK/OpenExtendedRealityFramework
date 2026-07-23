extends Node
var room: LiveKitRoom
var mic_source: LiveKitAudioSource
var mic_track: LiveKitLocalAudioTrack
var cam_source: LiveKitVideoSource
var cam_track: LiveKitLocalVideoTrack
var agent_video_stream: LiveKitVideoStream
var agent_audio_stream: LiveKitAudioStream
var agent_audio_playback: AudioStreamGeneratorPlayback
@onready var avatar_video_sprite: Sprite3D = $AvatarVideo3D
@onready var agent_audio_player: AudioStreamPlayer = $AvatarAudio

func _ready():
	avatar_video_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	avatar_video_sprite.shaded = false
	room = LiveKitRoom.new()
	room.connected.connect(_on_connected)
	room.participant_connected.connect(_on_participant_connected)
	room.track_subscribed.connect(_on_track_subscribed)
	room.connect_to_room("wss://avalumatest-uym3e2l2.livekit.cloud", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiZ29kb3QtdXNlciIsInZpZGVvIjp7InJvb21Kb2luIjp0cnVlLCJyb29tIjoibXktdGVzdC1yb29tIiwiY2FuUHVibGlzaCI6dHJ1ZSwiY2FuU3Vic2NyaWJlIjp0cnVlLCJjYW5QdWJsaXNoRGF0YSI6dHJ1ZX0sInJvb21Db25maWciOnsiYWdlbnRzIjpbeyJhZ2VudE5hbWUiOiJhdmEtYWdlbnQifV19LCJzdWIiOiJnb2RvdC11c2VyIiwiaXNzIjoiQVBJdmZGZHNVNzJqcmI1IiwibmJmIjoxNzg0NzI2Nzc1LCJleHAiOjE3ODQ3NDgzNzV9.CSG43w1rE_Lsft13z2-5aUOVACxDcF2sULVvNtfmAV8", {})

func _on_connected():
	print("Connected as: ", room.get_local_participant().get_identity())
	_publish_mic()

func _publish_mic():
	mic_source = LiveKitAudioSource.create(48000, 1, 200)
	mic_track = LiveKitLocalAudioTrack.create("mic", mic_source)
	room.get_local_participant().publish_track(mic_track, {"source": LiveKitTrack.SOURCE_MICROPHONE})

func _publish_camera():
	cam_source = LiveKitVideoSource.create(640, 480)
	cam_track = LiveKitLocalVideoTrack.create("camera", cam_source)
	room.get_local_participant().publish_track(cam_track, {"source": LiveKitTrack.SOURCE_CAMERA})

func _on_participant_connected(participant):
	print("Joined: ", participant.get_identity())

func _on_track_subscribed(track, publication, participant):
	print("Track subscribed: ", track.get_name(), " kind: ", track.get_kind(), " from: ", participant.get_identity())
	if track.get_kind() == LiveKitTrack.KIND_VIDEO:
		agent_video_stream = LiveKitVideoStream.from_track(track)
		avatar_video_sprite.texture = agent_video_stream.get_texture()
	elif track.get_kind() == LiveKitTrack.KIND_AUDIO:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 48000
		agent_audio_player.stream = gen
		agent_audio_player.play()
		agent_audio_playback = agent_audio_player.get_stream_playback()
		agent_audio_stream = LiveKitAudioStream.from_track(track)

func _process(_delta):
	if agent_audio_stream and agent_audio_playback:
		agent_audio_stream.poll(agent_audio_playback)
