shader_type canvas_item;

uniform sampler2D front;
uniform sampler2D back;
uniform sampler2D left;
uniform sampler2D right;
uniform sampler2D up;
uniform sampler2D down;

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

vec4 cubeTex(vec3 uvw){
	vec3 a = abs(uvw);
	bvec3 ip = greaterThan(uvw, vec3(0.0));
	vec2 uvc;
	if(ip.x && a.x >= a.y && a.x >= a.z){
		uvc.x = -uvw.z; uvc.y = uvw.y;
		return textureLod(front, 0.5 * (uvc / a.x + 1.0),0.0);
		
	} 
	else if(!ip.x && a.x >= a.y && a.x >= a.z){
		uvc.x = uvw.z; uvc.y = uvw.y;
		return textureLod(back, 0.5 * (uvc / a.x + 1.0), 0.0);
	} 
	else if (ip.y && a.y >= a.x && a.y >= a.z){
		uvc.x = uvw.x; uvc.y = -uvw.z;
		return textureLod(up, 0.5 * (uvc / a.y + 1.0), 0.0);
	} 
	else if (!ip.y && a.y >= a.x && a.y >= a.z){
		uvc.x = uvw.x; uvc.y = uvw.z;
		return textureLod(down, 0.5 * (uvc / a.y + 1.0), 0.0);
	}
	else if (ip.z && a.z >= a.x && a.z >= a.y){
		uvc.x = uvw.x; uvc.y = uvw.y;
		return textureLod(right, 0.5 * (uvc / a.z + 1.0), 0.0);
	} 
	else if (!ip.z && a.z >= a.x && a.z >= a.y){
		uvc.x = -uvw.x; uvc.y = uvw.y;
		return textureLod(left, 0.5 * (uvc / a.z + 1.0), 0.0);
	}
	return vec4(0.0);
}

vec3 rayDirFromUv(vec2 uv) {
	vec3 dir;
	float x = sin(kPI * uv.y);
	dir.y = cos(kPI * uv.y);
	dir.x = x * sin(2.0 * kPI * (0.5 - uv.x));
	dir.z = x * cos(2.0 * kPI * (0.5 - uv.x));
	return dir;
}

void fragment(){
	vec3 d = rayDirFromUv(vec2(-UV.x, UV.y));
	COLOR = cubeTex(d);
	COLOR.rgb *= COLOR.rgb;
}