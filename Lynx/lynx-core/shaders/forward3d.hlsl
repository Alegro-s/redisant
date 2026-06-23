cbuffer FrameCB : register(b0) {
    float4x4 viewProj;
    float4x4 lightViewProj;
    float4x4 lightViewProjC1;
    float4 lightDir;
    float4 ambientColor;
    float4 cameraPos;
    float4 shadowParams; // x=texel, y=bias, z=penumbra, w=cascadeSplit
    float4 cascadeFlags; // x=enableCascade (1=on)
    float4 renderParams; // x=iblStrength, y=exposure, z=bloom, w=postEnabled
};

cbuffer ObjectCB : register(b1) {
    float4x4 model;
    float4 baseColor;
    float metallic;
    float roughness;
    float useAlbedo;
    float useNormal;
};

Texture2D shadowMap : register(t0);
Texture2D albedoMap : register(t1);
Texture2D shadowMapC1 : register(t2);
SamplerState shadowSampler : register(s0);
SamplerState albedoSampler : register(s1);

struct VSIn {
    float3 pos : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

struct PSIn {
    float4 pos : SV_Position;
    float3 worldNormal : TEXCOORD0;
    float4 color : COLOR0;
    float4 shadowCoord0 : TEXCOORD1;
    float2 uv : TEXCOORD2;
    float3 worldPos : TEXCOORD3;
    float4 shadowCoord1 : TEXCOORD4;
};

PSIn VSMain(VSIn input) {
    float4 worldPos = mul(model, float4(input.pos, 1.0));
    float3 worldNormal = normalize(mul((float3x3)model, input.normal));
    PSIn o;
    o.pos = mul(viewProj, worldPos);
    o.worldNormal = worldNormal;
    o.color = baseColor;
    o.shadowCoord0 = mul(lightViewProj, worldPos);
    o.shadowCoord1 = mul(lightViewProjC1, worldPos);
    o.worldPos = worldPos.xyz;
    o.uv = input.uv;
    return o;
}

PSIn VSShadow(VSIn input) {
    float4 worldPos = mul(model, float4(input.pos, 1.0));
    PSIn o;
    o.pos = mul(lightViewProj, worldPos);
    o.worldNormal = float3(0, 1, 0);
    o.color = float4(0, 0, 0, 1);
    o.shadowCoord0 = o.pos;
    o.shadowCoord1 = o.pos;
    o.worldPos = worldPos.xyz;
    o.uv = input.uv;
    return o;
}

float shadowCompare(float4 shadowCoord, Texture2D map, float2 texel, float bias, float penumbra) {
    float3 proj = shadowCoord.xyz / shadowCoord.w;
    float2 uv = proj.xy * 0.5 + 0.5;
    uv.y = 1.0 - uv.y;
    if (uv.x < 0.001 || uv.x > 0.999 || uv.y < 0.001 || uv.y > 0.999)
        return 1.0;
    float depth = proj.z * 0.5 + 0.5;
    float lit = 0.0;
    [unroll] for (int y = -1; y <= 1; y++) {
        [unroll] for (int x = -1; x <= 1; x++) {
            float2 off = float2(x, y) * texel;
            float stored = map.SampleLevel(shadowSampler, uv + off, 0).r;
            lit += depth <= stored + bias ? 1.0 : penumbra;
        }
    }
    return lit / 9.0;
}

float shadowFactor(PSIn input) {
    float2 texel = float2(shadowParams.x, shadowParams.x);
    float bias = shadowParams.y;
    float penumbra = shadowParams.z;
    float sh0 = shadowCompare(input.shadowCoord0, shadowMap, texel, bias, penumbra);
    if (cascadeFlags.x < 0.5)
        return sh0;
    float sh1 = shadowCompare(input.shadowCoord1, shadowMapC1, texel, bias, penumbra);
    float dist = distance(cameraPos.xyz, input.worldPos);
    float split = shadowParams.w;
    float blend = smoothstep(split * 0.85, split * 1.05, dist);
    return lerp(sh0, sh1, blend);
}

float4 PSShadow(PSIn input) : SV_Target {
    float d = input.pos.z / input.pos.w;
    d = d * 0.5 + 0.5;
    return float4(d, d, d, 1.0);
}

float3 aces_tone_map(float3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

float4 PSMain(PSIn input) : SV_Target {
    float3 albedo = input.color.rgb;
    if (useAlbedo > 0.5)
        albedo *= albedoMap.Sample(albedoSampler, input.uv).rgb;

    float3 N = normalize(input.worldNormal);
    if (useNormal > 0.5) {
        float2 nxy = input.uv * 6.28318;
        float3 bump = normalize(float3(sin(nxy.x) * 0.25, sin(nxy.y) * 0.25, 1.0));
        N = normalize(N + bump * 0.45);
    }

    float ibl = renderParams.x;
    float sky = saturate(N.y * 0.5 + 0.5);
    float ground = 1.0 - sky;
    float3 iblAmbient = albedo * (sky * float3(0.55, 0.65, 0.85) + ground * float3(0.15, 0.12, 0.10)) * ibl;

    float3 L = normalize(-lightDir.xyz);
    float NdotL = saturate(dot(N, L));
    float specPower = lerp(4.0, 64.0, 1.0 - roughness);
    float spec = pow(saturate(NdotL), specPower) * metallic * 0.6;
    float sh = shadowFactor(input);
    float3 diffuse = albedo * (ambientColor.rgb + NdotL * 0.85 * sh) + iblAmbient;
    float3 lit = diffuse + spec * sh;

    if (renderParams.w > 0.5) {
        float lum = dot(lit, float3(0.2126, 0.7152, 0.0722));
        float bloom = saturate(lum - 0.75) * renderParams.z;
        lit += bloom * albedo;
        lit = aces_tone_map(lit * renderParams.y);
    }
    return float4(lit, input.color.a);
}
