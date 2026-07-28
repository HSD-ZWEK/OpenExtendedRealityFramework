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
	room.connect_to_room("wss://avalumatest-uym3e2l2.livekit.cloud", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiZ29kb3QtdXNlciIsInZpZGVvIjp7InJvb21Kb2luIjp0cnVlLCJyb29tIjoidGVzdC1yb29tMiIsImNhblB1Ymxpc2giOnRydWUsImNhblN1YnNjcmliZSI6dHJ1ZSwiY2FuUHVibGlzaERhdGEiOnRydWV9LCJyb29tQ29uZmlnIjp7ImFnZW50cyI6W3siYWdlbnROYW1lIjoiYXZhLWFnZW50LXRlc3QifV19LCJzdWIiOiJnb2RvdC11c2VyIiwiaXNzIjoiQVBJdmZGZHNVNzJqcmI1IiwibmJmIjoxNzg1MjQwMTIyLCJleHAiOjE3ODUyNjE3MjJ9.Exdl0WEkzMKyW6F20WJKkY9oNyvfdl5_SM1JmHXVSME", {})

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
		agent_video_stream.frame_received.connect(_on_video_frame_received)
		avatar_video_sprite.texture = agent_video_stream.get_texture()
	elif track.get_kind() == LiveKitTrack.KIND_AUDIO:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 48000
		agent_audio_player.stream = gen
		agent_audio_player.play()
		agent_audio_playback = agent_audio_player.get_stream_playback()
		agent_audio_stream = LiveKitAudioStream.from_track(track)
		print("Audio player playing: ", agent_audio_player.playing)
		
func _on_video_frame_received():
	print("REAL FRAME RECEIVED, size: ", agent_video_stream.get_texture().get_size())

func _process(_delta):
	if agent_audio_stream and agent_audio_playback:
		agent_audio_stream.poll(agent_audio_playback)
	if agent_video_stream:
		var tex = agent_video_stream.get_texture()
		if tex and tex.get_size() != Vector2.ZERO:
			if avatar_video_sprite.texture != tex or Engine.get_frames_drawn() % 60 == 0:
				print("Video texture size now: ", tex.get_size())
