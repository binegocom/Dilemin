# Dılêmın animation system

All animations must honor the operating system's Reduce Motion setting.
The radar is **schematic**: marker positions are deterministic pseudorandom
positions derived from opaque public profile IDs, NOT geographic coordinates.

| Engine | Purpose | Source |
| --- | --- | --- |
| Flutter | Radar circles, avatar layouts and transitions | `features/radar/radar_canvas.dart` |
| GLSL (GPU) | Radar sweep glow | `shaders/radar_glow.frag` |
| Flame | Soft particle field when profiles are visible | `features/animations/radar_particles.dart` |
| Lottie | Looping online indicator | `assets/lottie/online_pulse.json` |
| Rive | Online signal icon, "wifi" artboard | `assets/rive/web_icons_pack.riv` |

The bundled Rive asset is derived from the official Rive Flutter example
repository (MIT licensed). Source:
https://github.com/rive-app/rive-flutter/blob/master/example/assets/web_icons_pack.riv
The bootstrap script verifies it by pinned Git blob hash before packaging.
Do not remove the upstream MIT attribution when redistributing the asset.

Run `bash scripts/fetch_rive_assets.sh` from repository root before `flutter pub get`.
The asset is fetched **at build time**, not from inside the running application.
Flutter's normal build process compiles the GLSL program.

## Performance acceptance criteria

- Monitor actual iOS and Android devices under `flutter run --profile`.
- Keep raster/UI frame times within the device refresh-rate budget.
- Ensure reduced motion prevents continuous shader/flame/Rive/Lottie movement.
- The Flame overlay is only mounted when visible profiles exist.
- Use RepaintBoundary for independent effects; never animate profile list layout.
