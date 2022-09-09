shader_type spatial;
render_mode unshaded, depth_draw_never, cull_front, skip_vertex_transform, blend_mix, async_visible;
// Description:
// - Per vertex sky.
// License:
// - J. Cuéllar 2022 MIT License
// - See: LICENSE File.
// Uniforms.
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

vec2 equirectUV(vec3 norm){
	vec2 ret;
	ret.x = (atan(norm.x, norm.z) + kPI) * kINV_TAU;
	ret.y = acos(norm.y) * kINV_PI;
	return ret;
}

float disk(vec3 norm, vec3 coords, lowp float size){
	float d = length(norm - coords);
	return 1.0 - step(size, d);
}

// https://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
vec3 interleavedGradientNoise(vec2 pos) {
	const vec3 magic = vec3(0.06711056f, 0.00583715f, 52.9829189f);
	float res = fract(magic.z * fract(dot(pos, magic.xy))) * 2.0 - 1.0;
	return vec3(res, -res, res) * 0.00392156862745; // / 255.0;
}
//------------------------------------------------------------------------------

// Coords.
uniform vec3 sun_direction;
uniform vec3 moon_direction;
uniform mat3 deep_space_matrix;
uniform mat3 moon_matrix;

// General.
uniform vec2 color_correction;
uniform vec4 ground_color: hint_color;
uniform float horizon_level;
uniform bool debanding;

// Rayleigh.
uniform float atm_sunE;
uniform float atm_darkness;
uniform float atm_thickness;
uniform float atm_rayleigh_level;
uniform vec4 atm_day_tint: hint_color;
uniform vec4 atm_horizon_light_tint: hint_color;
uniform vec4 atm_night_tint: hint_color;
uniform vec3 atm_beta_ray;

// Mie.
uniform vec3 atm_beta_mie;

uniform vec4 atm_sun_mie_tint: hint_color;
uniform float atm_sun_mie_intensity;
uniform vec3 atm_sun_partial_mie_phase;

uniform vec4 atm_moon_mie_tint: hint_color;
uniform float atm_moon_mie_intensity;
uniform vec3 atm_moon_partial_mie_phase;

const float RAYLEIGH_ZENITH_LENGTH = 8.4e3;
const float MIE_ZENITH_LENGTH = 1.25e3;

// Near Space.
uniform vec4 sun_disk_color: hint_color = vec4(1.0);
uniform float sun_disk_size = 0.03;
uniform float sun_disk_intensity = 1.0;

uniform vec4 moon_color: hint_color;
uniform sampler2D moon_texture: hint_albedo;
uniform float moon_size;

// Background.
uniform sampler2D background_texture: hint_albedo;
uniform vec4 background_color: hint_color;

// Stars Field.
uniform sampler2D stars_field_texture: hint_albedo;
uniform sampler2D noise_tex: hint_albedo;
uniform vec4 stars_field_color: hint_color;
uniform float stars_scintillation;
uniform float stars_scintillation_speed;

// Atmospheric Scattering.
//------------------------------------------------------------------------------
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

vec3 atmosphericScattering(float sr, float sm, vec2 mu, vec3 mult){
	vec3 betaMie = atm_beta_mie;
	vec3 betaRay = atm_beta_ray * atm_thickness;
	
	vec3 extinction = saturateRGB(exp(-betaRay * sr + betaMie * sm));
	vec3 finalExtinction = mix(
		1.0 - extinction, 
		(1.0 - extinction) * extinction, 
		mix(saturate(atm_thickness * 0.5), 1.0, mult.x)
	);
	
	float rayleighPhase = rayleighPhase(mu.x);
	vec3 BRT = betaRay * rayleighPhase;
	vec3 BMT = betaMie * miePhase(mu.x, atm_sun_partial_mie_phase);
	BMT *= atm_sun_mie_intensity * atm_sun_mie_tint.rgb;
	
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

varying vec4 v_world_pos;
varying vec3 v_deep_space_coords;
varying vec4 v_angle_mult;
varying vec3 v_scattering;
varying float v_horizon_blend;
varying vec4 v_moon_coords;
void vertex(){
	vec4 vert = vec4(VERTEX, 0.0);
	POSITION =  PROJECTION_MATRIX * INV_CAMERA_MATRIX * WORLD_MATRIX * vert;
	POSITION.z = POSITION.w;
	
	v_world_pos = WORLD_MATRIX * vert;
	
	v_moon_coords.xyz = (moon_matrix * vert.xyz) / moon_size + 0.5;
	v_moon_coords.w = dot(v_world_pos.xyz, moon_direction.xyz);
	v_moon_coords.x = -v_moon_coords.x + 1.0;
	
	v_deep_space_coords.xyz = (deep_space_matrix * VERTEX).xyz;
	
	v_angle_mult.x = saturate(1.0 - sun_direction.y);
	v_angle_mult.y = saturate(sun_direction.y + 0.45);
	v_angle_mult.z = saturate(-sun_direction.y + 0.30);
	v_angle_mult.w = saturate(sun_direction.y);
	
	v_world_pos = normalize(v_world_pos);
	
	vec2 mu = vec2(
		dot(sun_direction, v_world_pos.xyz), 
		dot(moon_direction, v_world_pos.xyz)
	);
	v_world_pos.y += horizon_level;
	
	// Atmospheric Scattering.
	float sr, sm;
	opticalDepth(v_world_pos.y, sr, sm);
	v_scattering = atmosphericScattering(sr, sm, mu.xy, v_angle_mult.xyz);
}

void fragment(){
	vec3 color = vec3(0.0);
	vec3 worldPos = normalize(v_world_pos).xyz;

	color.rgb += v_scattering.rgb;
	
	
	// Near Space.
	vec3 nearSpace = vec3(0.0);
	
	vec3 sunDisk = disk(worldPos, sun_direction, sun_disk_size) * 
		sun_disk_intensity * sun_disk_color.rgb * v_scattering;
	
	vec4 moon = texture(moon_texture, v_moon_coords.xy);
	moon.rgb = contrastLevel(moon.rgb * moon_color.rgb, moon_color.a);
	moon *= saturate(v_moon_coords.w);
	
	float moonMask = saturate(1.0 - moon.a);
	nearSpace = moon.rgb + (sunDisk.rgb * moonMask);
	color.rgb += nearSpace;
	
	// Deep Space.
	vec3 deepSpace = vec3(0.0);
	vec2 deepSpaceUV = equirectUV(normalize(v_deep_space_coords));
	
	// Background(Milky Way)
	vec3 background = contrastLevel(
		textureLod(background_texture, deepSpaceUV, 0.0).rgb * background_color.rgb, 
		background_color.a
	);
	deepSpace += background.rgb * moonMask;
	
	// Stars Field.
	float starsScintillation = textureLod(noise_tex, UV + (TIME * stars_scintillation_speed), 0.0).r;
	starsScintillation = mix(1.0, starsScintillation * 1.5, stars_scintillation);
	
	vec3 starsField = textureLod(stars_field_texture, deepSpaceUV, 0.0).rgb * stars_field_color.rgb;
	starsField = saturateRGB(
		mix(starsField.rgb, starsField.rgb * starsScintillation, stars_scintillation)
	);
	//deepSpace.rgb -= saturate(starsField.r*10.0);
	deepSpace.rgb = (deepSpace.rgb + starsField.rgb) * v_angle_mult.z * moonMask;
	
	float horizonBlend = saturate((worldPos.y - 0.03) * 3.0);
	color.rgb += deepSpace.rgb * horizonBlend;
	
	// Ground Color.
	color.rgb = mix(
		color.rgb, ground_color.rgb * v_angle_mult.w, 
		saturate((-worldPos.y - horizon_level)*100.0) * ground_color.a
	);
	
	// Color Correction.
	color.rgb = tonemapPhoto(color.rgb, color_correction.y, color_correction.x);
	
	if(debanding){
		color.rgb += interleavedGradientNoise(FRAGCOORD.xy);
	}
	
	ALBEDO = color.rgb;
}