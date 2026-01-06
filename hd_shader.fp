vec3 rgb2hsv( vec3 c )
{
	vec4 K = vec4(0.0,-1.0/3.0,2.0/3.0,-1.0);
	vec4 p = (c.g<c.b)?vec4(c.bg,K.wz):vec4(c.gb,K.xy);
	vec4 q = (c.r<p.x)?vec4(p.xyw,c.r):vec4(c.r,p.yzx);
	float d = q.x-min(q.w,q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z+(q.w-q.y)/(6.0*d+e)),d/(q.x+e),q.x);
}
vec3 hsv2rgb( vec3 c )
{
	vec4 K = vec4(1.0,2.0/3.0,1.0/3.0,3.0);
	vec3 p = abs(fract(c.xxx+K.xyz)*6.0-K.www);
	return c.z*mix(K.xxx,clamp(p-K.xxx,0.0,1.0),c.y);
}
//https://www.quizcanners.com/single-post/2018/04/02/Color-Bleeding-in-Shader
void main()
{
	vec2 coord = TexCoord;
	vec4 res = texture(InputTexture,coord);
	vec3 c = res.rgb;
	vec3 chsv = rgb2hsv(c);

	// color bleeding adjustment
	if (chsv.z > 0.85)
	{
		vec3 mix = c.gbr + c.brg;
		c.rgb += mix * mix * rl_bleeding * chsv.z;
		res.rgb = c;
	}
	else if (chsv.z < 0.30)
	{
		vec3 mix = c.gbr + c.brg;
		c.rgb -= mix * mix * mix * rl_bleeding * (1.0 - chsv.z);
		res.rgb = c;
	}

	// saturation adjustment
	chsv = rgb2hsv(c);
	if (chsv.z > 0.85)
	{
		chsv.y *= (2.0 - chsv.z);
		c = hsv2rgb(chsv);
	}
	else if (chsv.z < 0.30)
	{
		chsv.y *= (1.0 - chsv.z);
		c = hsv2rgb(chsv);
	}

	FragColor = res;
}

