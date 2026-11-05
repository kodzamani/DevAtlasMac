#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// All shaders here are consumed through SwiftUI's `colorEffect` / `layerEffect`.
// `position` is in points with a top-left origin, and colors are premultiplied.
// Stitchable functions cannot use derivatives, so anti-aliasing widths are passed in.

// MARK: - Helpers

static float da_hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float da_roundBox(float2 p, float2 center, float2 halfSize, float radius) {
    float2 d = abs(p - center) - halfSize + radius;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

static float da_smoothUnion(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

/// Composites a straight-alpha color over a premultiplied destination.
static float4 da_over(float4 dst, float3 rgb, float alpha) {
    return float4(rgb * alpha + dst.rgb * (1.0 - alpha), alpha + dst.a * (1.0 - alpha));
}

static float3 da_unpremultiply(half4 c) {
    return c.a > 0.001 ? float3(c.rgb) / float(c.a) : float3(c.rgb);
}

// MARK: - Aurora background

/// A neutral window surface with a barely visible wash of the accent color that drifts very
/// slowly. Dithered with a fixed pattern to avoid banding without adding visible grain.
[[ stitchable ]] half4 daAurora(float2 position, half4 color, float2 size, float time, half4 accent, float dark) {
    float aspect = size.x / max(size.y, 1.0);
    float2 uv = position / max(size.y, 1.0);
    float t = time * 0.025;

    float3 base = dark > 0.5 ? float3(0.082, 0.084, 0.094) : float3(0.906, 0.914, 0.933);
    // Half-desaturated so a saturated accent doesn't tint the whole window.
    float3 rawTint = da_unpremultiply(accent);
    float3 tint = mix(float3(dot(rawTint, float3(0.299, 0.587, 0.114))), rawTint, 0.5);

    float2 p1 = float2(aspect * (0.25 + 0.10 * sin(t)), 0.15 + 0.08 * cos(t * 0.8));
    float2 p2 = float2(aspect * (0.80 + 0.10 * cos(t * 0.7)), 0.90 + 0.08 * sin(t * 0.9));

    float wash = exp(-length_squared(uv - p1) * 1.6) + 0.7 * exp(-length_squared(uv - p2) * 1.6);
    float strength = dark > 0.5 ? 0.06 : 0.04;
    float3 result = mix(base, tint, clamp(wash, 0.0, 1.0) * strength);

    result += (da_hash(position) - 0.5) / 255.0;
    return half4(half3(result), 1.0);
}

// MARK: - Folder icon

/// Procedural Finder-style folder drawn from signed distance fields, so it stays sharp at
/// every icon size. `pointer` (in points) drives the light; `open` lifts the front panel.
[[ stitchable ]] half4 daFolderIcon(float2 position, half4 color, float2 size, half4 tint,
                                    float2 pointer, float hover, float open, float px) {
    const float aspect = 0.80;
    float width = min(size.x, size.y / aspect) * 0.90;
    float2 origin = (size - float2(width, width * aspect)) * 0.5;
    float2 p = (position - origin) / width;
    float aa = max(px / width, 0.0015);
    // Mute the language colors so a full grid stays calm, and lift near-black ones.
    float3 raw = da_unpremultiply(tint);
    float3 base = max(mix(float3(dot(raw, float3(0.299, 0.587, 0.114))), raw, 0.72), float3(0.26, 0.27, 0.30));

    float lift = open * 0.012;

    float back = da_smoothUnion(da_roundBox(p, float2(0.50, 0.45), float2(0.50, 0.33), 0.055),
                                da_roundBox(p, float2(0.23, 0.12), float2(0.21, 0.085), 0.042), 0.018);
    float paper = da_roundBox(p, float2(0.50, 0.335 - open * 0.02), float2(0.435, 0.135), 0.022);
    float frontTop = 0.235 + lift;
    float frontCenter = (frontTop + 0.78) * 0.5;
    float frontHalf = (0.78 - frontTop) * 0.5;
    float front = da_roundBox(p, float2(0.50, frontCenter), float2(0.50, frontHalf), 0.058);

    float2 light = hover > 0.001 ? (pointer - origin) / width : float2(0.22, 0.05);

    float4 out = float4(0.0);

    // Back panel and tab.
    float backAlpha = smoothstep(aa, -aa, back);
    float backShade = mix(0.86, 0.72, smoothstep(0.03, 0.40, p.y));
    out = da_over(out, base * backShade, backAlpha);

    // Paper sheet peeking between the panels.
    float paperAlpha = smoothstep(aa, -aa, paper);
    float3 paperColor = mix(float3(0.99), float3(0.84, 0.85, 0.88), smoothstep(0.20, 0.40, p.y));
    out = da_over(out, paperColor, paperAlpha);

    // Front panel with a vertical gradient and a light-following bevel.
    float frontAlpha = smoothstep(aa, -aa, front);
    float gradientT = smoothstep(frontTop, 0.78, p.y);
    float3 frontColor = mix(mix(base, float3(1.0), 0.14), base, gradientT);

    const float e = 0.006;
    float dx = da_roundBox(p + float2(e, 0), float2(0.50, frontCenter), float2(0.50, frontHalf), 0.058) - front;
    float dy = da_roundBox(p + float2(0, e), float2(0.50, frontCenter), float2(0.50, frontHalf), 0.058) - front;
    float2 normal = normalize(float2(dx, dy) + 1e-5);
    float2 toLight = normalize(light - p + 1e-5);
    float edge = smoothstep(-0.03, -0.002, front);
    frontColor += (dot(normal, toLight) * edge * 0.06);

    // Hairline on the top edge catches the light like the lip of a real folder.
    float lip = smoothstep(-0.014, -0.004, front) * (1.0 - smoothstep(frontTop, frontTop + 0.03, p.y));
    frontColor = mix(frontColor, float3(1.0), lip * 0.22);

    // Specular highlight that follows the pointer.
    float dist = length(p - light);
    frontColor += float3(exp(-dist * dist * 7.0) * (0.02 + 0.07 * hover));

    out = da_over(out, clamp(frontColor, 0.0, 1.0), frontAlpha);
    return half4(out);
}

// MARK: - Ripple

/// Radial ripple played once through an icon when it gets selected.
[[ stitchable ]] half4 daRipple(float2 position, SwiftUI::Layer layer, float2 origin, float time,
                                float amplitude, float frequency, float decay, float speed) {
    float distance = length(position - origin);
    float delay = distance / speed;
    float t = max(time - delay, 0.0);
    float rippleAmount = amplitude * sin(frequency * t) * exp(-decay * t);
    float2 direction = normalize(position - origin + 1e-5);
    float2 samplePosition = position + rippleAmount * direction;
    return layer.sample(samplePosition);
}
