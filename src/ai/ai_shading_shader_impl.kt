val shaderCode = """
#version 450 core
layout(location = 0) in vec3 vPosition;
layout(location = 1) in vec3 vNormal;
layout(location = 2) in vec2 vTexCoord;

layout(set = 0, binding = 0) uniform UniformBufferObject {
    mat4 model;
    mat4 view;
    mat4 proj;
    vec3 lightPos;
    vec3 viewPos;
    vec3 ambientColor;
    vec3 diffuseColor;
    vec3 specularColor;
    float shininess;
} ubo;

layout(set = 0, binding = 1) uniform sampler2D textureSampler;

layout(location = 0) out vec4 fragColor;

vec3 generateNoise(vec3 p) {
    return vec3(
        fract(sin(dot(p, vec3(12.9898,78.233,45.164))) * 43758.5453),
        fract(sin(dot(p + vec3(1.0), vec3(12.9898,78.233,45.164))) * 43758.5453),
        fract(sin(dot(p + vec3(2.0), vec3(12.9898,78.233,45.164))) * 43758.5453)
    );
}

float turbulence(vec3 p) {
    float sum = 0.0;
    float freq = 1.0;
    float amplitude = 1.0;
    for(int i = 0; i < 5; i++) {
        sum += abs(noise(p * freq)) * amplitude;
        freq *= 2.0;
        amplitude *= 0.5;
    }
    return sum;
}

float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(
            mix(dot(randomGradient(i), f - vec3(0.0, 0.0, 0.0)), dot(randomGradient(i + vec3(1.0, 0.0, 0.0)), f - vec3(1.0, 0.0, 0.0)), u.x),
            mix(dot(randomGradient(i + vec3(0.0, 1.0, 0.0)), f - vec3(0.0, 1.0, 0.0)), dot(randomGradient(i + vec3(1.0, 1.0, 0.0)), f - vec3(1.0, 1.0, 0.0)), u.x),
            u.y
        ),
        mix(
            mix(dot(randomGradient(i + vec3(0.0, 0.0, 1.0)), f - vec3(0.0, 0.0, 1.0)), dot(randomGradient(i + vec3(1.0, 0.0, 1.0)), f - vec3(1.0, 0.0, 1.0)), u.x),
            mix(dot(randomGradient(i + vec3(0.0, 1.0, 1.0)), f - vec3(0.0, 1.0, 1.0)), dot(randomGradient(i + vec3(1.0, 1.0, 1.0)), f - vec3(1.0, 1.0, 1.0)), u.x),
            u.y
        ),
        u.z
    );
}

vec3 randomGradient(vec3 i) {
    float random = fract(sin(dot(i ,vec3(12.9898,78.233,45.164))) * 43758.5453);
    float angle = random * 6.2831853;
    return vec3(cos(angle), sin(angle), 0.0);
}

vec3 computeLighting(vec3 normal, vec3 fragPos, vec3 viewDir) {
    vec3 lightDir = normalize(ubo.lightPos - fragPos);
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), ubo.shininess);
    vec3 ambient = ubo.ambientColor;
    vec3 diffuse = ubo.diffuseColor * diff;
    vec3 specular = ubo.specularColor * spec;
    return ambient + diffuse + specular;
}

void main() {
    vec3 pos = vPosition;
    float displacement = turbulence(pos * 0.5) * 0.1;
    vec3 displacedPosition = pos + vNormal * displacement;
    vec4 worldPos = ubo.model * vec4(displacedPosition, 1.0);
    vec3 normal = normalize(mat3(ubo.model) * vNormal);
    vec3 viewDir = normalize(ubo.viewPos - worldPos.xyz);
    vec3 lighting = computeLighting(normal, worldPos.xyz, viewDir);
    vec2 uv = vTexCoord + 0.1 * turbulence(pos * 1.0).xy;
    vec4 texColor = texture(textureSampler, uv);
    vec3 finalColor = texColor.rgb * lighting;
    fragColor = vec4(finalColor, texColor.a);
}
"""