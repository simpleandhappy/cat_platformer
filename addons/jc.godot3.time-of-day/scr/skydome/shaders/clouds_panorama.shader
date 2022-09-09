shader_type spatial;
render_mode unshaded, depth_draw_never, cull_front, skip_vertex_transform, blend_mix, async_visible;
// Description:
// - Panoramic clouds.
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

uniform sampler2D _texture: hint_black_albedo;
uniform vec4 day_color: hint_color = vec4(1.0);
uniform vec4 horizon_color: hint_color = vec4(1.0);
uniform vec4 night_color: hint_color = vec4(1.0);
uniform float intensity = 1.0;
uniform float tonemap;
//uniform float density = 1.0;
uniform vec4 density_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 alpha_channel = vec4(0.0, 0.0, 1.0, 0.0);

uniform float horizon_fade_offset = 0.1;
uniform float horizon_fade = 5.0;
uniform float horizon_level = 0.0;

uniform vec3 sun_direction;
uniform vec3 moon_direction;

//varying vec4 v_world_pos;
varying vec4 v_angle_mult;
void vertex(){
	vec4 vert = vec4(VERTEX, 0.0);
	vert.y += horizon_level;
	POSITION =  PROJECTION_MATRIX * INV_CAMERA_MATRIX * WORLD_MATRIX * vert;
	POSITION.z = POSITION.w;
	v_angle_mult.x = saturate((1.0 - sun_direction.y)-0.20);
	v_angle_mult.y = saturate(sun_direction.y + 0.45);
	v_angle_mult.z = saturate(-sun_direction.y + 0.30);
	v_angle_mult.w = saturate((-sun_direction.y)+0.60);
}

void fragment(){
	vec3 localPos = normalize(VERTEX).xyz;
	vec4 col = textureLod(_texture, equirectUV(localPos), 0.0);

	float density = dot(col, density_channel) * intensity;
	float alpha  = dot(col, alpha_channel);
	
	vec3 tint = mix(day_color.rgb, horizon_color.rgb, v_angle_mult.x) ;
	tint = mix(tint, night_color.rgb, v_angle_mult.w);
	
	ALBEDO = tint.rgb * density;
	ALBEDO = tonemapPhoto(ALBEDO, intensity, tonemap);
	ALPHA = alpha;
	ALPHA = mix(ALPHA, 0.0, saturate((-localPos.y+horizon_fade_offset) * horizon_fade));
}