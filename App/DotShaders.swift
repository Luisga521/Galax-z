/// The matrix's shaders, compiled when the app opens (a few milliseconds, then the system keeps them): building needs no Metal toolchain.
let dotShaders = #"""
#include <metal_stdlib>
using namespace metal;

// The matrix of lights. Three small passes at one texel a dot (afterglow, then a blur each way) and one over the screen that
// draws every dot as a round light on dark glass, with the blurred light around it.

struct Look {
    float2 origin;      // the first dot's corner, px
    float pitch;        // px a dot
    float glow;         // how much light spills
    float unlit;        // how much an unlit dot shows
    float decay;        // what is left of a dot's light after this frame
    float2 size;        // dots
};

static float3 lightOf(float3 v) { return pow(v, float3(1.55)); }

/// This frame's lights, or what is left of the last one's, whichever is brighter.
kernel void afterglow(texture2d<float, access::read> dots [[texture(0)]], texture2d<float, access::read> before [[texture(1)]],
                      texture2d<float, access::write> out [[texture(2)]], constant Look &look [[buffer(0)]], uint2 p [[thread_position_in_grid]]) {
    float3 now = lightOf(dots.read(p).rgb), left = before.read(p).rgb * look.decay;
    out.write(float4(max(now, left - 0.0004), 1), p);
}

static float4 blurred(texture2d<float, access::read> in, uint2 p, int2 d) {
    const float w[5] = { 0.204, 0.180, 0.124, 0.066, 0.028 };
    int2 last = int2(in.get_width() - 1, in.get_height() - 1);
    float3 sum = in.read(p).rgb * w[0];
    for (int i = 1; i < 5; i++) {
        sum += in.read(uint2(clamp(int2(p) + d * i, int2(0), last))).rgb * w[i];
        sum += in.read(uint2(clamp(int2(p) - d * i, int2(0), last))).rgb * w[i];
    }
    return float4(sum, 1);
}
kernel void blurAcross(texture2d<float, access::read> in [[texture(0)]], texture2d<float, access::write> out [[texture(1)]], uint2 p [[thread_position_in_grid]]) {
    out.write(blurred(in, p, int2(1, 0)), p);
}
kernel void blurDown(texture2d<float, access::read> in [[texture(0)]], texture2d<float, access::write> out [[texture(1)]], uint2 p [[thread_position_in_grid]]) {
    out.write(blurred(in, p, int2(0, 1)), p);
}

struct Corner { float4 at [[position]]; };

vertex Corner wholeScreen(uint i [[vertex_id]]) {
    float2 p = float2((i << 1) & 2, i & 2);
    return { float4(p * 2 - 1, 0, 1) };
}

fragment float4 matrixOfLights(Corner in [[stage_in]], texture2d<float> lights [[texture(0)]], texture2d<float> bloom [[texture(1)]], constant Look &look [[buffer(0)]]) {
    constexpr sampler nearest(filter::nearest, address::clamp_to_edge), smooth(filter::linear, address::clamp_to_edge);
    float2 g = (in.at.xy - look.origin) / look.pitch, cell = floor(g);
    float2 uv = (cell + 0.5) / look.size;
    float inside = all(cell >= 0) && all(cell < look.size) ? 1 : 0;
    float3 light = lights.sample(nearest, uv).rgb * inside;
    float d = length((g - cell - 0.5) * look.pitch);
    float level = saturate(sqrt(max(light.r, max(light.g, light.b))));
    float r = look.pitch * (0.315 + 0.125 * level);
    float cover = saturate(r - d + 0.5);
    float core = 1 + 0.22 * level * saturate(1 - d / max(r, 0.001));       // a hot middle
    float3 out = light * cover * core;
    out += look.unlit * inside * saturate(look.pitch * 0.3 - d + 0.5) * (1 - level);
    out += bloom.sample(smooth, g / look.size).rgb * look.glow;
    out = out / (out * 0.10 + 1);
    out = saturate(out);
    // a little noise, so dark glows do not band
    float n = fract(sin(dot(in.at.xy, float2(12.9898, 78.233))) * 43758.5453) - 0.5;
    out = pow(out, float3(1 / 2.2)) + n / 340;
    return float4(out, 1);
}
"""#
