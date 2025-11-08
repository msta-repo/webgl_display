#ifdef GL_FRAGMENT_PRECISION_HIGH
    precision highp float;
#else
    precision mediump float;
#endif

uniform sampler2D particlePositions;
uniform sampler2D velocityField;
uniform vec2 particleTexSize;
uniform float dt;

// Convert position [-1, 1] to UV [0, 1]
vec2 posToUV(vec2 pos) {
    return pos * 0.5 + 0.5;
}

// Wrapping function - more reliable than if statements
vec2 wrapPosition(vec2 pos) {
    // Use fract for wrapping instead of if statements
    pos.x = mod(pos.x + 1.0, 2.0) - 1.0;
    pos.y = mod(pos.y + 1.0, 2.0) - 1.0;
    return pos;
}

void main() {
    vec2 vTexCoord = gl_FragCoord.xy / particleTexSize;
    
    // Read current particle position
    vec4 posData = texture2D(particlePositions, vTexCoord);
    vec2 pos = posData.xy;
    
    // Sample velocity field at particle position
    // Clamp UV to slightly inside [0,1] to avoid boundary issues
    vec2 velocityUV = clamp(posToUV(pos), 0.001, 0.999);
    

    vec4 velocity = texture2D(velocityField, velocityUV);
    
    // Simpler mass calculation that won't overflow on mediump
    float seed = dot(vTexCoord, vec2(12.9898, 78.233));
    //float mass = 1.0 + 4.0 * fract(sin(seed) * 43758.5453);
    float mass = 1.0;
    
    // Update position with safety checks
    vec2 deltaPos = dt * velocity.xy * 0.01 / mass;
    
    // Clamp delta to prevent extreme jumps (safety check)
    deltaPos = clamp(deltaPos, vec2(-0.1), vec2(0.1));
    
    pos += deltaPos;
    
    // Wrap around boundaries (more reliable than if statements)
    pos = wrapPosition(pos);
    
    gl_FragColor = vec4(pos, 0.0, 1.0);
}