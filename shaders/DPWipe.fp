
void main()
{
	vec2 Pos	= TexCoord ;
	ivec2 Dim	= textureSize( InputTexture, 0 );
	ivec2 Txl	= ivec2( Pos * Dim );
	vec3 Col	= texture( InputTexture, Pos ).rgb ;
	
	int i ;
	float j ;
	for( i = 1; i < min( timer, Dim.y - Txl.y ); i++ )
	{
		Txl.y	+= min( i, 6 );
		j		= 1.0 / i ;
		Col		= mix( Col, texelFetch( InputTexture, Txl, 0 ).rgb, j );
	}
	Col.r	= max( max( Col.r, Col.g ), Col.b );
	Col.gb	*= sqrt( j );
	
	FragColor = vec4( Col, 1.0 );
}
