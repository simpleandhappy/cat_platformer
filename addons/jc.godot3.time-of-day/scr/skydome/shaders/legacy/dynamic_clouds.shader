shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_front, skip_vertex_transform;
// Description:
// - Dynamic clouds.
// License:
// - MIT License
// This shader is based on DanilS clouds shader with MIT License
// See: https://github.com/danilw/godot-utils-and-other
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

float saturate(float value){
	return clamp(value, 0.0, 1.0);
}

vec3 saturateRGB(vec3 value){
	return clamp(value.rgb, 0.0, 1.0);
}

float pow3(float real){
	return real * real * real;
}

vec3 tonemapPhoto(vec3 col, float exposure, float level){
	col.rgb *= exposure;
	return mix(col.rgb, 1.0 - exp2(-col.rgb), level);
}

uniform vec3 sun_direction;
uniform vec3 moon_direction;
uniform float coverage;
uniform float thickness;
uniform float absorption;
uniform float noise_freq;
uniform float intensity;
uniform float size;
uniform float offset_speed;
uniform vec3 _offset;
uniform sampler2D noise;

uniform vec4 day_color: hint_color;
uniform vec4 horizon_color: hint_color;
uniform vec4 night_color: hint_color;
uniform float tonemap;

//const int kCLOUDS_STEP = 12;
uniform int clouds_step = 12;

uniform vec3 partial_mie_phase;
uniform float mie_intensity;
uniform vec4 mie_tint = vec4(1.0);

uniform float horizon_level;

float noiseClouds(vec3 p){
	vec3 pos = vec3(p * 0.01);
	pos.z *= 256.0;
	vec2 Offset = vec2(0.317, 0.123);
	vec4 uv= vec4(0.0);
	uv.xy = pos.xy + Offset * floor(pos.z);
	uv.zw = uv.xy + Offset;
	float x1 = textureLod(noise, uv.xy, 0.0).r;
	float x2 = textureLod(noise, uv.zw, 0.0).r;
	return mix(x1, x2, fract(pos.z));
}

float cloudsFBM(vec3 p, float l){
	float ret;
	ret = 0.51749673 * noiseClouds(p);  
	p *= l;
	ret += 0.25584929 * noiseClouds(p); 
	p *= l; 
	ret += 0.12527603 * noiseClouds(p); 
	p *= l;
	ret += 0.06255931 * noiseClouds(p);
	return ret;
}

float noiseCloudsFBM(vec3 p, float freq){
	return cloudsFBM(p, freq);
}

float remap(float value, float fromMin, float fromMax, float toMin, float toMax){
	return toMin + (value - fromMin) * (toMax - toMin) / (fromMax - fromMin);
}

float cloudsDensity(vec3 p, vec3 offset, float t){
	vec3 pos = p * 0.0212242 + offset;
	float dens = noiseCloudsFBM(pos, noise_freq);
	
	//dens = remap(dens, -(1.0-noiseCloudsFBM(pos, noise_freq*1.4)), 1.0, 0.0, 1.0);
	
	
	float cov = 1.0-coverage;
	dens *= smoothstep(cov, cov+0.05, dens);
	//dens += dens;
	return saturate(dens);
}

bool intersectSphere(float r, vec3 origin, vec3 dir, out float t, out vec3 nrm)
{
	origin += vec3(0.0, 450.0, 0.0);
	float a = dot(dir, dir);
	float b = 2.0 * dot(origin, dir);
	float c = dot(origin, origin) - r * r;
	float d = b * b - 4.0 * a * c;
	if(d < 0.0) return false;
	
	d = sqrt(d);
	a *= 2.0;
	float t1 = 0.5 * (-b + d);
	float t2 = 0.5 * (-b - d);
	
	if(t1<0.0) t1 = t2;
	if(t2 < 0.0) t2 = t1;
	t1 = min(t1, t2);
	
	if(t1 < 0.0) return false;
	nrm = origin + t1 * dir;
	t = t1;
	
	return true;
}

float miePhase(float mu, vec3 partial){
	return kPI4 * (partial.x) * (pow(partial.y - partial.z * mu, -1.5));
}

vec4 renderClouds(vec3 ro, vec3 rd, float tm, float am, float cs){
	vec4 ret;
	vec3 wind = _offset * (tm * offset_speed);
    vec3 n; float tt; float a = 0.0;
    if(intersectSphere(500, ro, rd, tt, n))
	{
		float marchStep = float(clouds_step) * thickness;
		vec3 dirStep = rd / rd.y * marchStep;
		vec3 pos = n * size;
		
		vec2 mu = vec2(dot(sun_direction, rd), dot(moon_direction, rd));
		float mph = ((miePhase(mu.x, partial_mie_phase)) +
		miePhase(mu.y, partial_mie_phase) * am);
		
		vec4 t = vec4(1.0);
		t.rgb *= (mph * mie_intensity) * 0.1;
		for(int i = 0; i < clouds_step; i++)
		{
			float h = float(i) * cs; // / float(clouds_step);
			float density = cloudsDensity(pos, wind, h);
			float sh = saturate(exp(-absorption * density * marchStep));
			
			t *= sh;
			ret += (t * (exp(h) * 0.571428571) * density * marchStep);
			
			a += (1.0 - sh) * (1.0 - a);
			pos += dirStep;
			
			//if (length(pos) > 1e3) break;
		}
		
		return vec4(clamp(ret.rgb, 0.0, 1.3), a);
	}
	return vec4(clamp(ret.rgb, 0.0, 1.3), a);
}

varying vec4 world_pos;
varying vec4 moon_coords;
varying vec3 deep_space_coords;
varying vec4 angle_mult;
varying float rcp_clouds_step;

void vertex(){
	vec4 vert = vec4(VERTEX, 0.0);
	POSITION =  PROJECTION_MATRIX * INV_CAMERA_MATRIX * WORLD_MATRIX * vert;
	POSITION.z = POSITION.w;
	
	world_pos = (WORLD_MATRIX * vert);
	angle_mult.x = saturate(1.0 - sun_direction.y);
	angle_mult.y = saturate(sun_direction.y + 0.45);
	angle_mult.z = saturate(-sun_direction.y + 0.30);
	angle_mult.w = saturate(-sun_direction.y + 0.60);
	rcp_clouds_step = 1.0 / float(clouds_step);
}

void fragment(){
	vec3 ray = normalize(world_pos).xyz;
	float horizonBlend = saturate((ray.y-0.00) * 100.0);
	
	vec4 clouds = renderClouds(vec3(0.0, -horizon_level, 0.0), ray, TIME, angle_mult.z, rcp_clouds_step);
	clouds.a = saturate(clouds.a);
	clouds.rgb *= mix(mix(day_color.rgb, horizon_color.rgb, angle_mult.x), 
		night_color.rgb, angle_mult.w);
	clouds.a = mix(0.0, clouds.a, horizonBlend);
	
	ALBEDO = tonemapPhoto(clouds.rgb, intensity, tonemap);
	ALPHA = pow3(clouds.a);
	//DEPTH = 1.0;
}