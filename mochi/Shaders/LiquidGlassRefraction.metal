#include <metal_stdlib>
using namespace metal;

static float sdRoundedRect(float2 p, float2 halfSize, float radius) {
    float2 q = abs(p) - halfSize;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

[[ stitchable ]] float2 liquidCapsuleRefraction(float2 position, float2 size, float strength, float edgeWidth) {
    float2 halfSize = size * 0.5;
    float radius = min(halfSize.x, halfSize.y);
    float2 p = position - halfSize;
    float2 uv = p / halfSize;
    float2 core = halfSize - float2(radius, radius);

    float dist = sdRoundedRect(p, core, radius);
    float insideDistance = -dist;
    if (insideDistance <= 0.0) {
        return position;
    }

    float edgeFactor = 1.0 - smoothstep(0.0, edgeWidth, insideDistance);
    float refraction = edgeFactor * strength;

    float epsilon = 1.0;
    float2 grad = float2(
        sdRoundedRect(p + float2(epsilon, 0.0), core, radius) - sdRoundedRect(p - float2(epsilon, 0.0), core, radius),
        sdRoundedRect(p + float2(0.0, epsilon), core, radius) - sdRoundedRect(p - float2(0.0, epsilon), core, radius)
    );

    float gradLength = length(grad);
    if (gradLength > 0.0001) {
        grad /= gradLength;
    } else {
        float uvLength = length(uv);
        grad = uvLength > 0.0001 ? (uv / uvLength) : float2(0.0);
    }

    float2 offset = -grad * refraction;
    return position + offset;
}
