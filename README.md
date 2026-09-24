# OpenExtendedRealityFramework

A Godot 4.7 XR framework for Meta Quest 3 that integrates a real-time AI voice/video avatar (via [LiveKit](https://livekit.io)) into a mixed-reality scene, using the [`godot-livekit`](https://github.com/NodotProject/godot-livekit) GDExtension and a Python LiveKit Agents backend.

---

## Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Project Setup](#project-setup)
4. [The `godot-livekit` Plugin](#the-godot-livekit-plugin)
5. [Building the Plugin for macOS](#building-the-plugin-for-macos)
6. [Building the Plugin for Android (Quest 3)](#building-the-plugin-for-android-quest-3)
7. [Backend: the `ava-agent` Python Server](#backend-the-ava-agent-python-server)
8. [Scenes](#scenes)
   - [Non-XR Test Scene](#non-xr-test-scene)
   - [XR (Quest 3) Scene](#xr-quest-3-scene)
9. [Known Issues / Troubleshooting](#known-issues--troubleshooting)

---

## Overview

This project connects a Godot XR scene to a live, conversational AI avatar over WebRTC. A user's microphone (and optionally camera) is published into a LiveKit room; a Python agent process joins the same room, runs an STT → LLM → TTS pipeline, and drives an Avaluma AI avatar, whose video and audio are streamed back and rendered inside the Godot scene — either on a flat desktop test scene or directly in the user's field of view on a Meta Quest 3.

---

## Requirements (macOS)

- **Godot 4.7 (stable)** — the project and the plugin build are both pinned to this version. A mismatched editor version can cause the GDExtension to silently fail to load (`LiveKitRoom` unresolved as a type).
- **macOS with Apple Silicon (arm64)** — for local development and building the desktop version of the plugin.
- **Xcode Command Line Tools** (`xcode-select --install`)
- **SCons** (`pip install scons` or `brew install scons`)
- **Homebrew** (for the `jpeg-turbo` runtime dependency, see below)
- **Android NDK r28b (`28.1.13356709`)** — for building the Android/Quest variant. Other NDK versions will fail; this exact version is what the bundled `godot-cpp` release expects.
- A **LiveKit Cloud** project (or self-hosted LiveKit server) with an API key/secret pair.
- A running instance of the separate **`ava-agent`** Python project (LiveKit Agents + Avaluma avatar backend).

---

# OpenExtendedRealityFramework

A Godot 4.7 XR framework for Meta Quest 3 that integrates a real-time AI voice/video avatar (via [LiveKit](https://livekit.io)) into a mixed-reality scene, using the [`godot-livekit`](https://github.com/NodotProject/godot-livekit) GDExtension and a Python LiveKit Agents backend.

---

## Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Project Setup](#project-setup)
4. [The `godot-livekit` Plugin](#the-godot-livekit-plugin)
5. [Building the Plugin for macOS](#building-the-plugin-for-macos)
6. [Building the Plugin for Android (Quest 3)](#building-the-plugin-for-android-quest-3)
7. [Backend: the `ava-agent` Python Server](#backend-the-ava-agent-python-server)
8. [Scenes](#scenes)
   - [Non-XR Test Scene](#non-xr-test-scene)
   - [XR (Quest 3) Scene](#xr-quest-3-scene)
9. [Known Issues / Troubleshooting](#known-issues--troubleshooting)

---

## Overview

This project connects a Godot XR scene to a live, conversational AI avatar over WebRTC. A user's microphone (and optionally camera) is published into a LiveKit room; a Python agent process joins the same room, runs an STT → LLM → TTS pipeline, and drives an Avaluma AI avatar, whose video and audio are streamed back and rendered inside the Godot scene — either on a flat desktop test scene or directly in the user's field of view on a Meta Quest 3.

---

## Requirements (macOS)

- **Godot 4.7 (stable)** — the project and the plugin build are both pinned to this version. A mismatched editor version can cause the GDExtension to silently fail to load (`LiveKitRoom` unresolved as a type).
- **macOS with Apple Silicon (arm64)** — for local development and building the desktop version of the plugin.
- **Xcode Command Line Tools** (`xcode-select --install`)
- **SCons** (`pip install scons` or `brew install scons`)
- **Homebrew** (for the `jpeg-turbo` runtime dependency, see below)
- **Android NDK r28b (`28.1.13356709`)** — for building the Android/Quest variant. Other NDK versions will fail; this exact version is what the bundled `godot-cpp` release expects.
- A **LiveKit Cloud** project (or self-hosted LiveKit server) with an API key/secret pair.
- A running instance of the separate **`ava-agent`** Python project (LiveKit Agents + Avaluma avatar backend).

---

## Project Setup

```bash
git clone <this-repo-url> OpenExtendedRealityFramework
cd OpenExtendedRealityFramework
```

Open the project in the **Godot 4.7** editor. The `addons/godot-livekit/` folder contains the GDExtension — see the next section for how its binaries get there.

### OpenXR Vendor Plugin, XR Tools, and Build Profile

Before the XR scene will run on Quest 3, a few Godot-side XR pieces need to be installed and enabled, separate from `godot-livekit` itself:

**1. Enable OpenXR**
Project Settings → **XR** → check **OpenXR → Enabled**. This is required for any of the XR nodes (`XROrigin3D`, `XRCamera3D`, controller/hand tracking) to initialize at runtime.

**2. Install the OpenXR Vendors plugin**
Meta Quest support relies on the [`godot_openxr_vendors`](https://github.com/GodotVR/godot_openxr_vendors) plugin (installable via the Godot Asset Library, or as a git submodule under `addons/`). It provides the Meta-specific OpenXR loader/permissions and features used on Quest (hand tracking, passthrough, etc.) beyond Godot's generic built-in OpenXR support. After installing:
- Enable it under **Project → Project Settings → Plugins**
- Under **Project Settings → XR → OpenXR**, set the target to include **Meta Quest** in the enabled runtimes/vendors list

**3. Install `godot-xr-tools`**
[`godot-xr-tools`](https://github.com/GodotVR/godot-xr-tools) supplies common XR building blocks (movement, pickups, UI pointers, hand poses) this project builds on. Install it the same way — Asset Library or as an addon — and enable it under **Project → Project Settings → Plugins**.

**4. Set up the Android build profile**
Quest deployment requires Godot's **Custom Build** (Gradle) pipeline rather than the default export template, since the OpenXR Vendors plugin injects its own Android manifest permissions and dependencies:
- **Project → Install Android Build Template** (this generates an `android/build/` folder in the project)
- In your Android export preset, enable **Gradle Build → Use Gradle Build**
- Confirm the OpenXR Vendors plugin's Android library appears under the export preset's **Plugins** section and is checked
- Set **Min SDK** / **Target SDK** to whatever the OpenXR Vendors plugin's documentation currently recommends for Quest 3 (check the plugin's own README, since these values are updated periodically alongside Meta's runtime requirements)

For XR usage you should only proceed to building the LiveKit Plugin after these steps are in place!

The LiveKit GDExtension and the OpenXR/XR Tools setup are independent of each other, but both need to be correctly configured for the full XR scene to run on-device.

---

## The `godot-livekit` Plugin

`godot-livekit` is a third-party GDExtension ([NodotProject/godot-livekit](https://github.com/NodotProject/godot-livekit)) that wraps LiveKit's C++ SDK, exposing classes like `LiveKitRoom`, `LiveKitTrack`, `LiveKitVideoStream`, `LiveKitAudioSource`, etc. directly to GDScript.

**Important:** the project's official Asset Library release only ships **Linux and web** binaries. macOS and Android binaries are **not** published upstream and must be built locally. This repo vendors the resulting binaries directly under `addons/godot-livekit/bin/` so contributors don't have to rebuild them from scratch — but if you need to rebuild (e.g. after an upstream update), follow the sections below.

The plugin's build script (`build.sh`) supports `macos`, `android`, `linux`, and `windows` targets, and fetches three dependencies per platform:
- The **LiveKit C++ SDK** (prebuilt, from a fork: `krazyjakee/client-sdk-cpp`)
- **`godot-cpp`** (Godot's C++ bindings, either fetched prebuilt or built locally)
- **`frametap`** (screen-capture support; not used/needed on Android)

---

## Building the Plugin for macOS

```bash
git clone https://github.com/NodotProject/godot-livekit.git
cd godot-livekit
./build.sh macos
```

### Known issue #1 — empty `godot-cpp` prebuilt fetch

The "prebuilt godot-cpp" step may silently produce an **empty** `godot-cpp/bin/` folder despite logging success. Check:

```bash
find godot-cpp -name "*.a"
```

If empty, build it locally:

```bash
cd godot-cpp
scons platform=macos arch=arm64 target=template_release -j$(sysctl -n hw.logicalcpu)
cd ..
```

### Known issue #2 — `universal` filename mismatch

The outer `SConstruct` hardcodes the expected static-lib filename as `universal`, regardless of the `arch=` you built. Alias it (safe on a single-arch Apple Silicon Mac):

```bash
cp godot-cpp/bin/libgodot-cpp.macos.template_release.arm64.a \
   godot-cpp/bin/libgodot-cpp.macos.template_release.universal.a
```

Re-run `./build.sh macos` — it should now compile successfully and produce `addons/godot-livekit/bin/libgodot-livekit.macos.arm64.dylib`.

### Known issue #3 — runtime `libjpeg.8.dylib` not found

The prebuilt LiveKit SDK's `liblivekit_ffi.dylib` links against Homebrew's `jpeg-turbo`. Install it once:

```bash
brew install jpeg-turbo
```

### Copy into this project

```bash
cp -r addons/godot-livekit/bin/* /path/to/OpenExtendedRealityFramework/addons/godot-livekit/bin/
```

---

## Building the Plugin for Android (Quest 3)

```bash
export ANDROID_NDK_ROOT="$HOME/Library/Android/sdk/ndk/28.1.13356709"
cd godot-livekit   # same clone as above
./build.sh android
```

### Known issue #1 — wrong NDK version

`godot-cpp`'s Android build expects **exactly** NDK `28.1.13356709` (r28b). Install it via `sdkmanager` or download the standalone `.dmg` from Google if `sdkmanager` isn't on your `PATH`:

```bash
<path-to-cmdline-tools>/bin/sdkmanager --install "ndk;28.1.13356709"
```

### Known issue #2 — cached `godot-cpp` is macOS-only

If you already built `godot-cpp` for macOS (above), the Android build will reuse that *cache directory* but still needs its own Android-specific static lib:

```bash
cd godot-cpp
scons platform=android arch=arm64 target=template_release
cd ..
```

This produces `godot-cpp/bin/libgodot-cpp.android.template_release.arm64.a`, which matches the Android `SConstruct` target exactly — no renaming needed (unlike macOS).

### Known issue #3 — `undefined symbol: main` at link time (real upstream bug)

Cross-compiling for Android **from a macOS host** fails at the final link step:

```
ld.lld: error: undefined symbol: main
```

This happens because `godot-livekit`'s `SConstruct` creates a bare `Environment()` for the Android branch with no explicit toolset, so SCons defaults to the **host's** linker tool (macOS's `applelink`, which passes `-dynamiclib`) instead of the correct Android linker flag (`-shared`). **Fix — patch `SConstruct`:**

```diff
- env = Environment()
+ env = Environment(tools=['gcc', 'g++', 'gnulink', 'ar'])
```

This is only needed once per clone of `godot-livekit`, and only affects building *for* Android *from* macOS. Re-run `./build.sh android` — it should now correctly pass `-shared` and link successfully, producing `addons/godot-livekit/bin/libgodot-livekit.android.arm64.so`.

> **Worth upstreaming:** this three-word fix would save future macOS-based Quest developers a lot of time — consider opening a PR against `NodotProject/godot-livekit`.

### Copy into this project

```bash
cp -r addons/godot-livekit/bin/* /path/to/OpenExtendedRealityFramework/addons/godot-livekit/bin/
```

macOS and Android binaries live side-by-side under `addons/godot-livekit/bin/` without conflict — Godot picks the correct one per export platform via the `.gdextension` file's feature tags.

### Exporting to Quest 3

Export normally via **Project → Export → Android**. A `WARNING: No "arm32" library found` is expected and harmless (Quest 3 is arm64-only). If you instead see `Parser Error: Could not find type "LiveKitRoom"` or missing `.so` file errors, the Android binaries above are missing or misplaced — re-check the copy step.

**Required Android export permissions** (Project → Export → Android preset → Permissions):
- `INTERNET`
- `RECORD_AUDIO`
- `MODIFY_AUDIO_SETTINGS`

---

## Backend: the `ava-agent` Python Server

The avatar/agent logic lives in a separate Python project (`ava-agent`), built on `livekit-agents`, using:
- `inference.STT` (Deepgram nova-3) / `inference.TTS` (Cartesia sonic-3) / `inference.TurnDetector` — LiveKit's hosted inference proxy
- `livekit.plugins.avaluma.AvatarSession` — renders the AI avatar's video/audio
- `livekit.plugins.ai_coustics` — mic noise cancellation

Run it locally for development:

```bash
cd ~/ava-agent
uv run lk agent dev
```

This registers a worker under a fixed `agent_name` (set via `@server.rtc_session(agent_name="...")` in `agent.py`). A room only gets an agent when a **dispatch** is explicitly requested — either baked into the client's access token (`RoomConfiguration.agents`) or triggered manually:

```bash
lk dispatch create --room <room-name> --agent-name <agent-name>
```

> **Gotcha:** token-based dispatch only fires when the room is **created**, not when joining an existing one. 

### Session tokens

During development, tokens are generated **manually** with a small script, run genToken.py, located in the agent's directory once before each test session and replace the outdated token in godot livekit seesion script.


Workflow before every test session:

```bash
cd ~/ava-agent
uv run python generate_token.py
```

Copy the printed `URL` and `Token` values directly into the Godot script's `connect_to_room()` call. Since the room name is regenerated on every run, dispatch reliably fires each time (recall: dispatch only triggers on room *creation*, so reusing an old room name silently skips it).

---

## Scenes

### Non-XR Test Scene

A plain `Node3D` scene with a standard `Camera3D` (no XR nodes at all), used to validate the full LiveKit pipeline in isolation before touching anything XR-specific:

- Connects to a LiveKit room, publishes the local microphone
- Subscribes to the avatar's video (rendered onto a `Sprite3D`) and audio (played via `AudioStreamPlayer`)
- Useful for isolating whether a problem is LiveKit/networking-related versus XR/OpenXR-related, since it removes an entire subsystem from the equation

Run it directly with Godot's **"Run Current Scene"** (not the project's main scene) to test independently.

### XR (Quest 3) Scene

The full mixed-reality scene, built on `XROrigin3D` / `XRCamera3D` and OpenXR. Structurally the same LiveKit connection/track-handling logic as the non-XR scene, with the avatar rendered on a billboarded `Sprite3D` positioned in front of the user in world space rather than viewed through a flat desktop camera. Requires the Android build of `godot-livekit` (see above) and exports/deploys directly to the Quest 3 over USB debugging.

---

## Known Issues / Troubleshooting

- **`Parser Error: Could not find type "LiveKitRoom"`** — the GDExtension failed to load for the current export platform; almost always a missing/misplaced binary (see build sections above) or a Godot editor version mismatch.
- **Total silence in Godot output (not even connection prints)** — check the Output/Debugger panel for a GDExtension load failure or parser error; the script may be failing to compile entirely before `_ready()` ever runs.
- **`LiveKitRoom.connection_failed` / `disconnected` signals** — always wire these up during development; a failed connection can otherwise fail completely silently with zero output.
- **Duplicate `track_subscribed` firing for the same track** — happens when manually enumerating pre-existing room participants (`get_remote_participants()`) *and* relying on the `track_subscribed` signal, since both can fire for tracks that were already active when you connected. Guard with a `handled_track_sids` set keyed by the publication's SID.
- **`participant_connected` / `track_subscribed` never firing for a participant** — these only fire for participants who join **after** you connect. For anyone already in the room at connect time, manually enumerate `room.get_remote_participants()` and their `get_track_publications()`.
- **Video texture stuck at `(0, 0)` size forever** — connect to the video stream's `frame_received` signal to confirm whether any frame has actually decoded; if it never fires, this points to a decode-pipeline issue in the extension's native LiveKit SDK, not your Godot code.
- **Microphone track publishes but carries no real audio** — `LiveKitAudioSource.create()` only creates an empty source; you must separately route Godot's mic input through an `AudioEffectCapture` bus effect and forward real PCM samples into `capture_frame()` every frame. Also ensure the sample rate used matches `AudioServer.get_mix_rate()` exactly, and send audio in fixed-size chunks (e.g. 480 samples for 10ms @ 48kHz) rather than arbitrary per-frame sizes.
- **`LiveKit Inference STT/TTS connection timed out` / signal connection timeouts** — this has been observed as a genuine, intermittent LiveKit Cloud infrastructure issue (regional degradation), not a bug in this project. Check https://status.livekit.io/ before assuming a local problem. As a diagnostic/fallback, swap `inference.STT` / `inference.TTS` / `inference.TurnDetector` for direct provider plugins (`deepgram.STT`, `cartesia.TTS`, `silero.VAD`) to bypass LiveKit's hosted inference proxy entirely.
- **`401 Unauthorized - invalid token` on agent reconnect** — check that the LiveKit API key/secret in the agent's `.env.local` hasn't been rotated or revoked on the dashboard.

---

## The `godot-livekit` Plugin

`godot-livekit` is a third-party GDExtension ([NodotProject/godot-livekit](https://github.com/NodotProject/godot-livekit)) that wraps LiveKit's C++ SDK, exposing classes like `LiveKitRoom`, `LiveKitTrack`, `LiveKitVideoStream`, `LiveKitAudioSource`, etc. directly to GDScript.

**Important:** the project's official Asset Library release only ships **Linux and web** binaries. macOS and Android binaries are **not** published upstream and must be built locally. This repo vendors the resulting binaries directly under `addons/godot-livekit/bin/` so contributors don't have to rebuild them from scratch — but if you need to rebuild (e.g. after an upstream update), follow the sections below.

The plugin's build script (`build.sh`) supports `macos`, `android`, `linux`, and `windows` targets, and fetches three dependencies per platform:
- The **LiveKit C++ SDK** (prebuilt, from a fork: `krazyjakee/client-sdk-cpp`)
- **`godot-cpp`** (Godot's C++ bindings, either fetched prebuilt or built locally)
- **`frametap`** (screen-capture support; not used/needed on Android)

---

## Building the Plugin for macOS

```bash
git clone https://github.com/NodotProject/godot-livekit.git
cd godot-livekit
./build.sh macos
```

### Known issue #1 — empty `godot-cpp` prebuilt fetch

The "prebuilt godot-cpp" step may silently produce an **empty** `godot-cpp/bin/` folder despite logging success. Check:

```bash
find godot-cpp -name "*.a"
```

If empty, build it locally:

```bash
cd godot-cpp
scons platform=macos arch=arm64 target=template_release -j$(sysctl -n hw.logicalcpu)
cd ..
```

### Known issue #2 — `universal` filename mismatch

The outer `SConstruct` hardcodes the expected static-lib filename as `universal`, regardless of the `arch=` you built. Alias it (safe on a single-arch Apple Silicon Mac):

```bash
cp godot-cpp/bin/libgodot-cpp.macos.template_release.arm64.a \
   godot-cpp/bin/libgodot-cpp.macos.template_release.universal.a
```

Re-run `./build.sh macos` — it should now compile successfully and produce `addons/godot-livekit/bin/libgodot-livekit.macos.arm64.dylib`.

### Known issue #3 — runtime `libjpeg.8.dylib` not found

The prebuilt LiveKit SDK's `liblivekit_ffi.dylib` links against Homebrew's `jpeg-turbo`. Install it once:

```bash
brew install jpeg-turbo
```

### Copy into this project

```bash
cp -r addons/godot-livekit/bin/* /path/to/OpenExtendedRealityFramework/addons/godot-livekit/bin/
```

---

## Building the Plugin for Android (Quest 3)

```bash
export ANDROID_NDK_ROOT="$HOME/Library/Android/sdk/ndk/28.1.13356709"
cd godot-livekit   # same clone as above
./build.sh android
```

### Known issue #1 — wrong NDK version

`godot-cpp`'s Android build expects **exactly** NDK `28.1.13356709` (r28b). Install it via `sdkmanager` or download the standalone `.dmg` from Google if `sdkmanager` isn't on your `PATH`:

```bash
<path-to-cmdline-tools>/bin/sdkmanager --install "ndk;28.1.13356709"
```

### Known issue #2 — cached `godot-cpp` is macOS-only

If you already built `godot-cpp` for macOS (above), the Android build will reuse that *cache directory* but still needs its own Android-specific static lib:

```bash
cd godot-cpp
scons platform=android arch=arm64 target=template_release
cd ..
```

This produces `godot-cpp/bin/libgodot-cpp.android.template_release.arm64.a`, which matches the Android `SConstruct` target exactly — no renaming needed (unlike macOS).

### Known issue #3 — `undefined symbol: main` at link time (real upstream bug)

Cross-compiling for Android **from a macOS host** fails at the final link step:

```
ld.lld: error: undefined symbol: main
```

This happens because `godot-livekit`'s `SConstruct` creates a bare `Environment()` for the Android branch with no explicit toolset, so SCons defaults to the **host's** linker tool (macOS's `applelink`, which passes `-dynamiclib`) instead of the correct Android linker flag (`-shared`). **Fix — patch `SConstruct`:**

```diff
- env = Environment()
+ env = Environment(tools=['gcc', 'g++', 'gnulink', 'ar'])
```

This is only needed once per clone of `godot-livekit`, and only affects building *for* Android *from* macOS. Re-run `./build.sh android` — it should now correctly pass `-shared` and link successfully, producing `addons/godot-livekit/bin/libgodot-livekit.android.arm64.so`.

> **Worth upstreaming:** this three-word fix would save future macOS-based Quest developers a lot of time — consider opening a PR against `NodotProject/godot-livekit`.

### Copy into this project

```bash
cp -r addons/godot-livekit/bin/* /path/to/OpenExtendedRealityFramework/addons/godot-livekit/bin/
```

macOS and Android binaries live side-by-side under `addons/godot-livekit/bin/` without conflict — Godot picks the correct one per export platform via the `.gdextension` file's feature tags.

### Exporting to Quest 3

Export normally via **Project → Export → Android**. A `WARNING: No "arm32" library found` is expected and harmless (Quest 3 is arm64-only). If you instead see `Parser Error: Could not find type "LiveKitRoom"` or missing `.so` file errors, the Android binaries above are missing or misplaced — re-check the copy step.

**Required Android export permissions** (Project → Export → Android preset → Permissions):
- `INTERNET`
- `RECORD_AUDIO`
- `MODIFY_AUDIO_SETTINGS`

---

## Backend: the `ava-agent` Python Server

The avatar/agent logic lives in a separate Python project (`ava-agent`), built on `livekit-agents`, using:
- `inference.STT` (Deepgram nova-3) / `inference.TTS` (Cartesia sonic-3) / `inference.TurnDetector` — LiveKit's hosted inference proxy
- `livekit.plugins.avaluma.AvatarSession` — renders the AI avatar's video/audio
- `livekit.plugins.ai_coustics` — mic noise cancellation

Run it locally for development:

```bash
cd ~/ava-agent
uv run lk agent dev
```

This registers a worker under a fixed `agent_name` (set via `@server.rtc_session(agent_name="...")` in `agent.py`). A room only gets an agent when a **dispatch** is explicitly requested — either baked into the client's access token (`RoomConfiguration.agents`) or triggered manually:

```bash
lk dispatch create --room <room-name> --agent-name <agent-name>
```

> **Gotcha:** token-based dispatch only fires when the room is **created**, not when joining an existing one. 

### Session tokens

During development, tokens are generated **manually** with a small script, run genToken.py, located in the agent's directory once before each test session and replace the outdated token in godot livekit seesion script.


Workflow before every test session:

```bash
cd ~/ava-agent
uv run python generate_token.py
```

Copy the printed `URL` and `Token` values directly into the Godot script's `connect_to_room()` call. Since the room name is regenerated on every run, dispatch reliably fires each time (recall: dispatch only triggers on room *creation*, so reusing an old room name silently skips it).

---

## Scenes

### Non-XR Test Scene

A plain `Node3D` scene with a standard `Camera3D` (no XR nodes at all), used to validate the full LiveKit pipeline in isolation before touching anything XR-specific:

- Connects to a LiveKit room, publishes the local microphone
- Subscribes to the avatar's video (rendered onto a `Sprite3D`) and audio (played via `AudioStreamPlayer`)
- Useful for isolating whether a problem is LiveKit/networking-related versus XR/OpenXR-related, since it removes an entire subsystem from the equation

Run it directly with Godot's **"Run Current Scene"** (not the project's main scene) to test independently.

### XR (Quest 3) Scene

The full mixed-reality scene, built on `XROrigin3D` / `XRCamera3D` and OpenXR. Structurally the same LiveKit connection/track-handling logic as the non-XR scene, with the avatar rendered on a billboarded `Sprite3D` positioned in front of the user in world space rather than viewed through a flat desktop camera. Requires the Android build of `godot-livekit` (see above) and exports/deploys directly to the Quest 3 over USB debugging.

---

## Known Issues / Troubleshooting

- **`Parser Error: Could not find type "LiveKitRoom"`** — the GDExtension failed to load for the current export platform; almost always a missing/misplaced binary (see build sections above) or a Godot editor version mismatch.
- **Total silence in Godot output (not even connection prints)** — check the Output/Debugger panel for a GDExtension load failure or parser error; the script may be failing to compile entirely before `_ready()` ever runs.
- **`LiveKitRoom.connection_failed` / `disconnected` signals** — always wire these up during development; a failed connection can otherwise fail completely silently with zero output.
- **Duplicate `track_subscribed` firing for the same track** — happens when manually enumerating pre-existing room participants (`get_remote_participants()`) *and* relying on the `track_subscribed` signal, since both can fire for tracks that were already active when you connected. Guard with a `handled_track_sids` set keyed by the publication's SID.
- **`participant_connected` / `track_subscribed` never firing for a participant** — these only fire for participants who join **after** you connect. For anyone already in the room at connect time, manually enumerate `room.get_remote_participants()` and their `get_track_publications()`.
- **Video texture stuck at `(0, 0)` size forever** — connect to the video stream's `frame_received` signal to confirm whether any frame has actually decoded; if it never fires, this points to a decode-pipeline issue in the extension's native LiveKit SDK, not your Godot code.
- **Microphone track publishes but carries no real audio** — `LiveKitAudioSource.create()` only creates an empty source; you must separately route Godot's mic input through an `AudioEffectCapture` bus effect and forward real PCM samples into `capture_frame()` every frame. Also ensure the sample rate used matches `AudioServer.get_mix_rate()` exactly, and send audio in fixed-size chunks (e.g. 480 samples for 10ms @ 48kHz) rather than arbitrary per-frame sizes.
- **`LiveKit Inference STT/TTS connection timed out` / signal connection timeouts** — this has been observed as a genuine, intermittent LiveKit Cloud infrastructure issue (regional degradation), not a bug in this project. Check https://status.livekit.io/ before assuming a local problem. As a diagnostic/fallback, swap `inference.STT` / `inference.TTS` / `inference.TurnDetector` for direct provider plugins (`deepgram.STT`, `cartesia.TTS`, `silero.VAD`) to bypass LiveKit's hosted inference proxy entirely.
- **`401 Unauthorized - invalid token` on agent reconnect** — check that the LiveKit API key/secret in the agent's `.env.local` hasn't been rotated or revoked on the dashboard.
