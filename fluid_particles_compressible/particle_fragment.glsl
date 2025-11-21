precision highp float;
varying vec2 vTexCoord;
varying float vInstanceID;
uniform float fadeAmount;
uniform float t;

// Random function - MUST be before main()
float random(float seed) {
    return fract(sin(seed * 12.9898) * 43758.5453);
}

vec2 hash( vec2 p ) {
    p = vec2( dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)) );
    return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise( in vec2 p ) {
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;
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
    
    // Multi-layer bloom effect
    // Core - bright and sharp
    float core = smoothstep(0.06 + abs(sin(vInstanceID)*0.00), 0.0, dist);
    
    // Inner glow - medium brightness
    float innerGlow = smoothstep(0.06, 0.0, dist);
    
    // Outer glow - soft and large (bloom effect)
    float outerGlow = smoothstep(0.08, 0.0, dist);
    
    // Optional: exponential falloff for even softer bloom
    float softBloom = exp(-dist *30.0/ (5.0 + abs(sin(vInstanceID)*0.0))    );
    
    // Combine layers with different intensities
    float alpha = core * 1.0 + innerGlow * 0.0 + outerGlow * 0.0 + softBloom * 0.0;
    
    float sparkle = sin(random(vInstanceID + t * 1.9));
    float fadeAlphaMod = (10.0 - fadeAmount + 0.05);
    
    //vec3 color = vec3(255.0, 100.0, 14.0) / 255.0;
    vec3 color = vec3(160.0, 80.0,20.0)/255.0;
    //color = color * (0.1 + 0.5 * noise(vec2(noise(vec2(vInstanceID*1.4, +vInstanceID*1.0)), 
    //                                          noise(vec2(vInstanceID*1.4, +vInstanceID*1.0)))));
    
    vec3 colorRandom = vec3(0.9, 0.8, 0.1) * noise(vec2(vInstanceID*0.1 + t, 
                                                         vInstanceID*0.2 + sin(t)*2.0));
    //color = color + colorRandom * 0.1;
    
    // Brighten the core for bloom effect
    float brightness = 1.0 + core * 1.00;
    color *= brightness;
    
    gl_FragColor = vec4(color * alpha, alpha * 0.4 * fadeAlphaMod);
}