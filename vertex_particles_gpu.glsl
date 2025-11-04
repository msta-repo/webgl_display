precision highp float;


attribute vec2 aPosition;      // Quad vertices (shared)
attribute float aInstanceID;   // Instance ID for each particle

varying vec2 vTexCoord;

uniform vec2 resolution;
uniform vec2 particleTexSize;   // Size of particle position texture
uniform float particleSize;
uniform sampler2D particlePositions;  // Texture containing particle positions

varying float vInstanceID; 

void main() {
    // Calculate UV for this particle in the position texture
    float totalParticles = particleTexSize.x * particleTexSize.y;
    float row = floor(aInstanceID / particleTexSize.x);
    float col = mod(aInstanceID, particleTexSize.x);
    vec2 particleUV = (vec2(col, row) + 0.5) / particleTexSize;
    
    // Sample particle position from texture
    vec4 posData = texture2D(particlePositions, particleUV);
    vec2 particlePos = posData.xy;
    
    // Calculate aspect ratio
    float aspect = resolution.x / resolution.y;
    
    // Scale quad by particle size
    vec2 scaledVertex = aPosition * particleSize;
    scaledVertex.x /= aspect;
    
    // Position at particle location
    vec2 pos = particlePos + scaledVertex;
    
    gl_Position = vec4(pos, 0.0, 1.0);
    
    vInstanceID = aInstanceID; // push through the instance id to the particle compute shader

    // Texture coordinates for the sprite
    vTexCoord = aPosition * 0.5 + 0.5;
}
