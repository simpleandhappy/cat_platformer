
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, async_visible;
// Description:
// - Fog tinted by atmosphere.
// License:
// - J. Cuéllar 2022 MIT License
// - See: LICENSE File.
//------------------------------------------------------------------------------
const float kPI          = 3.1415927f;
const float kINV_PI      = 0.3183098f;
const float kHALF_PI     = 1.5707963f;
const float kINV_HALF_PI = 0.6366198f;
const float kQRT_PI      = 0.7853982f;
const float kINV_QRT_PI  = 1.2732395f;
const float kPI4         = 12.5663706f;
const float kINV_PI4     = 0.0795775f;
const float k3PI16       = 0.1193662f;
const float kTAU         = 6.2831853f;
const float kINV_TAU     = 0.1591549f;
const float kE           = 2.7182818f;

vec3 mul43(mat4 m, vec4 v){
	return (m * v).xyz;
}

vec4 mul44(mat4 m, vec4 v){
	return m * v;
}

float saturate(float val){
	return clamp(val, 0.0, 1.0);
}

vec3 saturateRGB(vec3 val){
	return clamp(val, 0.0, 1.0);
}

vec3 contrastLevel(vec3 val, float level){
	return mix(val, val * val * val, level);
}

vec3 tonemapPhoto(vec3 col, float exposure, float level){
	col.rgb *= exposure;
	return mix(col.rgb, 1.0 - exp2(-col.rgb), level);
}
//------------------------------------------------------------------------------

// Coords.
uniform vec3 sun_direction;
uniform vec3 moon_direction;

// General.
uniform vec2 color_correction;
uniform float horizon_level;

// Fog.
uniform float fog_density;
uniform float fog_falloff;
uniform float fog_start;
uniform float fog_end;

// Rayleigh.
uniform float fog_rayleigh_depth;
uniform float atm_blend_color;

uniform float atm_sunE;
uniform float atm_darkness;
uniform float atm_thickness;
uniform float atm_rayleigh_level;
uniform vec4 atm_day_tint: hint_color;
uniform vec4 atm_horizon_light_tint: hint_color;
uniform vec4 atm_night_tint: hint_color;
uniform vec3 atm_beta_ray;

// Mie.
uniform float fog_mie_depth;
uniform vec3 atm_beta_mie;

uniform vec4 atm_sun_mie_tint: hint_color;
uniform float atm_sun_mie_intensity;
uniform vec3 atm_sun_partial_mie_phase;

uniform vec4 atm_moon_mie_tint: hint_color;
uniform float atm_moon_mie_intensity;
uniform vec3 atm_moon_partial_mie_phase;

const float RAYLEIGH_ZENITH_LENGTH = 8.4e3;
const float MIE_ZENITH_LENGTH = 1.25e3;
//------------------------------------------------------------------------------

// Fog.
float fogExp(float depth, float density){
	return 1.0 - saturate(exp2(-depth * density));
}

float fogFalloff(float y, float zeroLevel, float falloff){
	return saturate(exp(-(y + zeroLevel) * falloff));
}

float fogDistance(float depth){
	float d = depth;
	d = (fog_end - d) / (fog_end - fog_start);
	return saturate(1.0 - d);
}
//------------------------------------------------------------------------------

// Atmospheric Scattering.
float rayleighPhase(float mu){
	return k3PI16 * (1.0 + mu * mu);
}

float miePhase(float mu, vec3 partial){
	return kPI4 * partial.x * (pow(partial.y - partial.z * mu, -1.5));
}

// Simplifield for more performance.
void opticalDepth(float y, out float sr, out float sm){
	y = max(0.03, y + 0.03);
	y = 1.0 / y;
	sr = y * RAYLEIGH_ZENITH_LENGTH * atm_rayleigh_level;
	sm = y * MIE_ZENITH_LENGTH;
}

vec3 atmosphericScattering(float sr, float sm, vec2 mu, vec3 mult, float depth){
	vec3 betaMie = atm_beta_mie;
	vec3 betaRay = atm_beta_ray * atm_thickness;
	
	vec3 extinction = saturateRGB(exp(-betaRay * sr + betaMie * sm));
	vec3 finalExtinction = mix(
		1.0 - extinction, 
		(1.0 - extinction) * extinction, 
		mix(saturate(atm_thickness * 0.5), 1.0, mult.x)
	);
	
	float rayleighPhase = rayleighPhase(mu.x);
	vec3 BRT = betaRay * rayleighPhase * saturate(depth * fog_rayleigh_depth);
	vec3 BMT = betaMie * miePhase(mu.x, atm_sun_partial_mie_phase);
	BMT *= atm_sun_mie_intensity * atm_sun_mie_tint.rgb * saturate(depth * fog_mie_depth);
	
	vec3 BRMT = (BRT + BMT) / (betaRay + betaMie);
	vec3 scatter = atm_sunE * (BRMT * finalExtinction) * atm_day_tint.rgb * mult.y;
	scatter = mix(scatter, scatter * (1.0 - extinction), atm_darkness);
	
	vec3 lcol = mix(atm_day_tint.rgb, atm_horizon_light_tint.rgb, mult.x);
	vec3 nscatter = (1.0 - extinction) * atm_night_tint.rgb;
	nscatter += miePhase(mu.y, atm_moon_partial_mie_phase) * atm_moon_mie_tint.rgb * 
		atm_moon_mie_intensity * 0.005;
	
	nscatter = mix(nscatter, nscatter * (1.0 - extinction), atm_darkness);
	
	return (scatter * lcol) + nscatter;
}

void computeCoords(vec2 uv, float depth, mat4 camMat, mat4 invProjMat, 
	out vec3 viewDir, out vec3 worldPos){
	
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	
	// ViewDir
	vec4 view = invProjMat * vec4(ndc, 1.0);
	viewDir = view.xyz / view.w;
	
	// worldPos.
	view = camMat * view;
	view.xyz /= view.w;
	view.xyz -= (camMat * vec4(0.0001, 0.0, 0.0, 1.0)).xyz;
	worldPos = view.xyz;
}

varying mat4 v_camera_matrix;
varying vec4 v_angle_mult;

void vertex(){
	POSITION = vec4(VERTEX, 1.0);
	v_angle_mult.x = saturate(1.0 - sun_direction.y);
	v_angle_mult.y = saturate(sun_direction.y + 0.45);
	v_angle_mult.z = saturate(-sun_direction.y + 0.30);
	v_angle_mult.w = saturate(sun_direction.y);
	v_camera_matrix = CAMERA_MATRIX;
}

void fragment(){
	float depthRaw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec3 view; vec3 worldPos; float half; 
	computeCoords(SCREEN_UV, depthRaw, v_camera_matrix, INV_PROJECTION_MATRIX, view, worldPos);
	worldPos = normalize(worldPos);
	
	vec3 cameraPos = (CAMERA_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec4 viewVector = mul44(INV_PROJECTION_MATRIX, vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0));
	float linearDepth = -view.z;

	float fogFactor =  fogExp(linearDepth, fog_density);
	fogFactor *=  fogFalloff(worldPos.y, 0.0, fog_falloff);
	fogFactor *= fogDistance(linearDepth);
	
	vec2 mu = vec2(
		dot(sun_direction, worldPos), dot(moon_direction, worldPos)
	);
	worldPos.y += horizon_level;
	float sr; float sm; opticalDepth(atm_blend_color, sr, sm);
	vec3 scatter = atmosphericScattering(sr, sm, mu.xy,v_angle_mult.xyz, linearDepth);
	
	vec3 tint =  scatter;
	vec4 fogColor = vec4(tint.rgb, fogFactor);
	fogColor = vec4((fogColor.rgb), saturate(fogColor.a));
	fogColor.rgb = tonemapPhoto(fogColor.rgb, color_correction.y, color_correction.x);
	
	ALBEDO = fogColor.rgb;
	//ALPHA = fogColor.a;
	ALPHA = (depthRaw) < 0.999999999999 ? fogColor.a: 0.0; // Exclude sky.
}