vec3 desaturate(vec3 color, float amount)
{
	//VSO: make gray a unit vector of norm 1.0, which gives it more light. 
    vec3 gray = vec3(dot(vec3(0.2126 / 0.75, 0.7152 / 0.75 , 0.0722 / 0.75), color));
    return vec3(mix(color, gray, amount));
}

void main()
{
	vec3 color = texture(InputTexture, TexCoord).rgb;
	
	//VSO: the final color is an weight sum
	//of (1-amount).color + amount.gray.
	const float greyPart = 0.50;
	// amount was 0.725, reduce it to 0.50 so that the original color has 
	//more importance.
	FragColor = vec4(desaturate(color,greyPart), 1.0);
}
