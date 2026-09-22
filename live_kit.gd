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
@onready var mic_input_player: AudioStreamPlayer = $MicInput
var mic_capture_effect: AudioEffectCapture

func _ready():
	print("Input devices: ", AudioServer.get_input_device_list())
	print("Current input device: ", AudioServer.input_device)
	avatar_video_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	avatar_video_sprite.shaded = false

	room = LiveKitRoom.new()
	room.connected.connect(_on_connected)
	room.disconnected.connect(_on_disconnected)
	room.connection_failed.connect(_on_connection_failed)
	room.reconnecting.connect(func(): print("Reconnecting..."))
	room.reconnected.connect(func(): print("Reconnected!"))
	room.participant_connected.connect(_on_participant_connected)
	room.track_subscribed.connect(_on_track_subscribed)

	print("About to connect...")
	room.connect_to_room("wss://avalumatest-uym3e2l2.livekit.cloud", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiZ29kb3QtdXNlciIsInZpZGVvIjp7InJvb21Kb2luIjp0cnVlLCJyb29tIjoiY29uc29sZS00ZjA2NjY4NyIsImNhblB1Ymxpc2giOnRydWUsImNhblN1YnNjcmliZSI6dHJ1ZSwiY2FuUHVibGlzaERhdGEiOnRydWV9LCJyb29tQ29uZmlnIjp7ImFnZW50cyI6W3siYWdlbnROYW1lIjoiYXZhLWFnZW50LXRlc3QifV19LCJzdWIiOiJnb2RvdC11c2VyIiwiaXNzIjoiQVBJdmZGZHNVNzJqcmI1IiwibmJmIjoxNzg5NTYxNzkwLCJleHAiOjE3ODk1ODMzOTB9.LByvWzejL7c640FsDFcqGLuPF7Q4fjKXCZpBvbqj-rI", {})
	print("connect_to_room() called, state: ", room.get_connection_state())
	
	var mic_stream = AudioStreamMicrophone.new()
	mic_input_player.stream = mic_stream
	mic_input_player.play()

	var bus_idx = AudioServer.get_bus_index("MicCapture")
	mic_capture_effect = AudioServer.get_bus_effect(bus_idx, 0)
	
	print("Mic player playing: ", mic_input_player.playing)
	print("Mic player stream: ", mic_input_player.stream)
	print("Mic player bus: ", mic_input_player.bus)
	print("Actual mix rate now: ", AudioServer.get_mix_rate())

func _on_disconnected():
	print("DISCONNECTED")

func _on_connection_failed(error: String):
	print("CONNECTION FAILED: ", error)

func _on_connected():
	print("Connected as: ", room.get_local_participant().get_identity())
	_publish_mic()
	_process_existing_participants()

func _publish_mic():
	mic_source = LiveKitAudioSource.create(48000, 1, 200)
	mic_track = LiveKitLocalAudioTrack.create("mic", mic_source)
	room.get_local_participant().publish_track(mic_track, {"source": LiveKitTrack.SOURCE_MICROPHONE})

func _publish_camera():
	cam_source = LiveKitVideoSource.create(640, 480)
	cam_track = LiveKitLocalVideoTrack.create("camera", cam_source)
	room.get_local_participant().publish_track(cam_track, {"source": LiveKitTrack.SOURCE_CAMERA})

func _process_existing_participants():
	var participants = room.get_remote_participants()
	print("Existing participants at connect time: ", participants.keys())
	for identity in participants.keys():
		var participant = participants[identity]
		var publications = participant.get_track_publications()
		for track_sid in publications.keys():
			var pub = publications[track_sid]
			print("Publication found: ", pub.get_name(), " kind: ", pub.get_kind(), " subscribed: ", pub.get_subscribed())
			if not pub.get_subscribed():
				pub.set_subscribed(true)
			var track = pub.get_track()
			print("  -> track object after subscribe: ", track)
			if track:
				_handle_track(track, pub, participant)
			else:
				# Track not ready yet — retry shortly since subscription is async
				_retry_get_track(pub, participant)

func _retry_get_track(pub, participant, attempts: int = 0):
	if attempts > 10:
		print("  -> gave up waiting for track: ", pub.get_name())
		return
	await get_tree().create_timer(0.2).timeout
	var track = pub.get_track()
	if track:
		print("  -> track resolved after retry (", attempts, "): ", track)
		_handle_track(track, pub, participant)
	else:
		_retry_get_track(pub, participant, attempts + 1)

func _on_participant_connected(participant):
	print("Joined: ", participant.get_identity())

func _on_track_subscribed(track, publication, participant):
	_handle_track(track, publication, participant)

var handled_track_sids := {}

func _handle_track(track, publication, participant):
	var sid = publication.get_sid()  # or track.get_sid() if publication doesn't expose it
	if handled_track_sids.has(sid):
		return
	handled_track_sids[sid] = true

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

var mic_ring_buffer := PackedFloat32Array()
const CHUNK_SIZE := 480  # 10ms at 48000 Hz

func _process(_delta):
	if agent_audio_stream and agent_audio_playback:
		agent_audio_stream.poll(agent_audio_playback)
	if agent_video_stream:
		var tex = agent_video_stream.get_texture()
		if tex and tex.get_size() != Vector2.ZERO:
			if avatar_video_sprite.texture != tex or Engine.get_frames_drawn() % 60 == 0:
				print("Video texture size now: ", tex.get_size())

	if mic_source:
		if Engine.get_frames_drawn() % 60 == 0:
			print("Queued duration: ", mic_source.get_queued_duration())
	# Pull captured mic audio and forward to LiveKit
	if mic_source and mic_capture_effect:
		var frames_available = mic_capture_effect.get_frames_available()
		if frames_available > 0:
			var stereo_buf: PackedVector2Array = mic_capture_effect.get_buffer(frames_available)
			for i in range(stereo_buf.size()):
				mic_ring_buffer.append(stereo_buf[i].x)
				#mic_ring_buffer.append((stereo_buf[i].x + stereo_buf[i].y) * 0.5)

			# Emit fixed-size chunks only
			while mic_ring_buffer.size() >= CHUNK_SIZE:
				var chunk := mic_ring_buffer.slice(0, CHUNK_SIZE)
				mic_source.capture_frame(chunk, 48000, 1, CHUNK_SIZE)
				mic_ring_buffer = mic_ring_buffer.slice(CHUNK_SIZE)
