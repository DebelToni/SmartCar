struct Material {
    vec3 diffuseColor;
    vec3 specularColor;
    float shininess;
    float reflectivity;
    float transparency;
    float refractiveIndex;
};

struct Light {
    vec3 position;
    vec3 color;
    float intensity;
    vec3 direction;
    float cutoff;
    bool isDirectional;
};

uniform Material uMaterial;
uniform Light uLights[8];
uniform int uNumLights;
uniform vec3 uCameraPosition;
uniform sampler2D uNormalMap;
uniform sampler2D uDiffuseMap;
uniform sampler2D uSpecularMap;
uniform sampler2D uEmissionMap;
uniform float uTime;

in vec3 vPosition;
in vec3 vNormal;
in vec2 vTexCoord;
in vec3 vTangent;
in vec3 vBitangent;

out vec4 fragColor;

vec3 computeNormal(vec3 position, vec2 texCoord, vec3 normal, vec3 tangent, vec3 bitangent) {
    vec3 normalMap = texture(uNormalMap, texCoord).rgb;
    normalMap = normalize(normalMap * 2.0 - 1.0);
    vec3 T = normalize(tangent);
    vec3 B = normalize(bitangent);
    vec3 N = normalize(normal);
    mat3 TBN = mat3(T, B, N);
    return normalize(TBN * normalMap);
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    float nom = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = 3.14159265 * denom * denom;
    return nom / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    float nom = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    return nom / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx1 = GeometrySchlickGGX(NdotV, roughness);
    float ggx2 = GeometrySchlickGGX(NdotL, roughness);
    return ggx1 * ggx2;
}

vec3 calculateLighting(vec3 fragPos, vec3 normal, vec3 viewDir) {
    vec3 result = vec3(0.0);
    for(int i = 0; i < uNumLights; i++) {
        Light light = uLights[i];
        vec3 lightDir;
        float attenuation = 1.0;
        if (light.isDirectional) {
            lightDir = normalize(-light.direction);
        } else {
            lightDir = normalize(light.position - fragPos);
            float distance = length(light.position - fragPos);
            attenuation = 1.0 / (distance * distance);
        }
        float NdotL = max(dot(normal, lightDir), 0.0);
        vec3 diffuse = vec3(0.0);
        vec3 specular = vec3(0.0);
        if (NdotL > 0.0) {
            diffuse = uMaterial.diffuseColor * light.color * NdotL * light.intensity * attenuation;
            vec3 halfVec = normalize(lightDir + viewDir);
            float NDF = DistributionGGX(normal, halfVec, uMaterial.shininess);
            float G = GeometrySmith(normal, viewDir, lightDir, uMaterial.shininess);
            vec3 F0 = mix(vec3(0.04), uMaterial.specularColor, uMaterial.reflectivity);
            vec3 F = fresnelSchlick(max(dot(halfVec, viewDir), 0.0), F0);
            vec3 numerator = NDF * G * F;
            float denominator = 4.0 * max(dot(normal, viewDir), 0.0) * NdotL + 0.001;
            vec3 spec = numerator / denominator;
            specular = spec * light.color * light.intensity * attenuation;
        }
        result += diffuse + specular;
    }
    return result;
}

vec3 computeReflectedColor(vec3 fragPos, vec3 normal, vec3 viewDir, float reflectivity, float roughness) {
    vec3 reflectionDir = reflect(-viewDir, normal);
    vec3 reflectedColor = textureLod(uDiffuseMap, vTexCoord + reflectionDir.xy * 0.1, 5.0).rgb;
    return mix(vec3(0.0), reflectedColor, reflectivity);
}

vec3 computeRefractedColor(vec3 fragPos, vec3 normal, vec3 viewDir, float refractiveIndex, float transparency) {
    float eta = 1.0 / refractiveIndex;
    vec3 refractionDir = refract(-viewDir, normal, eta);
    vec3 refractedColor = textureLod(uDiffuseMap, vTexCoord + refractionDir.xy * 0.1, 5.0).rgb;
    return mix(vec3(0.0), refractedColor, transparency);
}

void main() {
    vec3 normal = computeNormal(vPosition, vTexCoord, vNormal, vTangent, vBitangent);
    vec3 viewDir = normalize(uCameraPosition - vPosition);
    vec3 lighting = calculateLighting(vPosition, normal, viewDir);
    vec3 diffuseColor = texture(uDiffuseMap, vTexCoord).rgb;
    vec3 specularColor = texture(uSpecularMap, vTexCoord).rgb;
    vec3 emission = texture(uEmissionMap, vTexCoord).rgb;
    vec3 fresnel = fresnelSchlick(max(dot(normal, viewDir), 0.0), mix(vec3(0.04), uMaterial.specularColor, uMaterial.reflectivity));
    vec3 reflection = computeReflectedColor(vPosition, normal, viewDir, uMaterial.reflectivity, uMaterial.shininess);
    vec3 refraction = computeRefractedColor(vPosition, normal, viewDir, uMaterial.refractiveIndex, uMaterial.transparency);
    vec3 color = diffuseColor * lighting + emission + reflection * fresnel + refraction * (1.0 - fresnel);
    fragColor = vec4(color, 1.0);
}