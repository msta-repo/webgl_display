precision highp float;

uniform sampler2D particlePositions;  // Current particle positions
uniform sampler2D velocityField;      // Fluid velocity field
uniform vec2 particleTexSize;         // Size of particle position texture
uniform float dt;

// Convert position [-1, 1] to UV [0, 1]
vec2 posToUV(vec2 pos) {
    return pos * 0.5 + 0.5;
}

void main() {
    // Calculate UV from gl_FragCoord
    vec2 vTexCoord = gl_FragCoord.xy / particleTexSize;
    
    // Read current particle position
    vec4 posData = texture2D(particlePositions, vTexCoord);
    vec2 pos = posData.xy;
    
    // Sample velocity field at particle position
    vec2 velocityUV = posToUV(pos);
    vec4 velocity = texture2D(velocityField, velocityUV);
    
    // Update position: Particle.Pos += dt * v.xyz
    pos += dt * velocity.xy * 0.01;
    
    // Wrap around boundaries
    if (pos.x < -1.0) pos.x += 2.0;
    if (pos.x > 1.0) pos.x -= 2.0;
    if (pos.y < -1.0) pos.y += 2.0;
    if (pos.y > 1.0) pos.y -= 2.0;
    
    gl_FragColor = vec4(pos, 0.0, 1.0);
}
