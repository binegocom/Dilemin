#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uProgress;
uniform float uStrength;
out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 pos = (uv - vec2(0.5)) * vec2(uSize.x / min(uSize.x, uSize.y), uSize.y / min(uSize.x, uSize.y));
  float radius = length(pos);
  float angle = atan(pos.y, pos.x);
  float sweep = mod(angle / 6.28318530718 - uProgress + 2.0, 1.0);
  float wedge = smoothstep(0.16, 0.0, sweep);
  float disc = 1.0 - smoothstep(0.44, 0.475, radius);
  float ambient = exp(-radius * 8.0) * 0.22;
  float intensity = (wedge * 0.20 + ambient) * disc * uStrength;
  fragColor = vec4(1.0, 0.32, 0.60, intensity);
}
