shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, blend_add,  async_visible;
// Description:
// - Sun and moon.
// License:
// - J. Cuéllar 2022 MIT License
// - See: LICENSE File.
//------------------------------------------------------------------------------
float saturate(float value){
	return clamp(value, 0.0, 1.0);
}

vec3 mul43(mat4 m, vec4 v){
	return (m * v).xyz;
}

vec4 mul44(mat4 m, vec4 v){
	return m * v;
}

float disk(vec3 norm, vec3 coords, lowp float size){
	float d = length(norm - coords);
	return 1.0 - step(size, d);
}

vec3 contrastLevel(vec3 val, float level){
	return mix(val, val * val * val, level);
}

// Sun.
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec4 sun_disk_color: hint_color = vec4(1.0);
uniform float sun_disk_size = 0.03;
uniform float sun_disk_intensity = 1.0;

// Moon.
uniform vec4 moon_color: hint_color;
uniform sampler2D moon_texture: hint_albedo;
uniform vec3 moon_direction;
uniform mat3 moon_matrix;
uniform float moon_size;
uniform float horizon_level = 0.0;

varying mat4 v_camera_matrix; varying float v_moon_size;
void vertex(){
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
	v_camera_matrix = CAMERA_MATRIX;
	v_moon_size = 1.0 / moon_size;
}

void fragment(){
	vec3 color;
	vec4 view = mul44(INV_PROJECTION_MATRIX, vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0));
	view = CAMERA_MATRIX * view;
	view.xyz /= view.w;
	view.xyz -= (CAMERA_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 worldPos = normalize(view).xyz;
	
	float moonMask = saturate(dot(worldPos.xyz, moon_direction.xyz));
	vec3 moonCoords = v_moon_size * (moon_matrix * worldPos) + 0.5;
	
	vec3 sunDisk = disk(worldPos, sun_direction, sun_disk_size) *
		sun_disk_color.rgb * sun_disk_intensity;
	
	vec4 moon = textureLod(moon_texture, 
		vec2(-moonCoords.x + 1.0, moonCoords.y), 0.0);
	moon.rgb = contrastLevel(moon.rgb * moon_color.rgb, moon_color.a);
	moon.rgb *= moonMask;
	float moonDiskMask = saturate(1.0 - moon.a);
	
	color.rgb = sunDisk * moonDiskMask;
	color.rgb += moon.rgb;
	worldPos.y += horizon_level;
	color.rgb = mix(color.rgb, vec3(0.0), saturate(-worldPos.y * 100.0));
	ALBEDO = color.rgb;
}