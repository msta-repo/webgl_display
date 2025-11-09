

precision highp float;
varying vec2 vTexCoord;
varying float vInstanceID;
uniform float fadeAmount;
uniform float t;



// Random function - MUST be before main()
float random(float seed) {
    return fract(sin(seed * 12.9898) * 43758.5453);
}

vec2 hash( vec2 p ) // replace this by something better
{
	p = vec2( dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)) );
	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise( in vec2 p )
{
    const float K1 = 0.366025404; // (sqrt(3)-1)/2;
    const float K2 = 0.211324865; // (3-sqrt(3))/6;

	vec2  i = floor( p + (p.x+p.y)*K1 );
    vec2  a = p - i + (i.x+i.y)*K2;
    float m = step(a.y,a.x); 
    vec2  o = vec2(m,1.0-m);
    vec2  b = a - o + K2;
	vec2  c = a - 1.0 + 2.0*K2;
    vec3  h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
	vec3  n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
    return dot( n, vec3(70.0) );
}


void main() {
    vec2 center = vec2(0.5);
    float dist = distance(vTexCoord, center);
    float alpha = smoothstep(0.2, 0.0, dist);
    
    float sparkle =  sin(random(vInstanceID + t * 1.9));

    float fadeAlphaMod = (10.0 - fadeAmount + 0.05);

    vec3 color = vec3(255.0, 100.0,14.0) / 255.0;

    color = color*(0.1 + 0.5*noise(vec2(noise(vec2(vInstanceID*1.4, +vInstanceID*1.0)), noise(vec2(vInstanceID*1.4, +vInstanceID*1.0)))));

    vec3 colorRandom = vec3( 0.9, 0.8, 0.1)*noise(vec2( vInstanceID*0.1 + t , vInstanceID*0.2 + sin(t)*2.0));

    color = color + colorRandom*0.1;
    gl_FragColor = vec4(color*alpha, alpha*0.4 * fadeAlphaMod);
}