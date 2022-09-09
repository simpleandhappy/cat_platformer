shader_type spatial;
render_mode unshaded, async_visible;
// Description:
// - Simple moon.
// License:
// - J. Cuéllar 2022 MIT License
// - See: LICENSE File.
//------------------------------------------------------------------------------
uniform sampler2D _texture;
uniform vec3 sun_direction;

float saturate(float v){
	return clamp(v, 0.0, 1.0);
}

varying vec3 v_normal;
void vertex(){
	v_normal = (WORLD_MATRIX * vec4(VERTEX, 0.0)).xyz;
}

void fragment(){
	float l = saturate(max(0.0, dot(sun_direction, v_normal)) * 2.0);
	ALBEDO = texture(_texture, UV).rgb * l;
}