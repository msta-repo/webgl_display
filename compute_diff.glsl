#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform sampler2D u_psi;
uniform vec2 u_resolution;
uniform float u_dt;
uniform float u_D;

// Heat addition uniforms
uniform bool u_addHeat;
uniform vec2 u_heatPos;
uniform float u_heatAmplitude;
uniform float u_heatWidth;

varying float vX;
varying float vY;

void main() {
    // Convert from clip space [-1,1] to texture coordinates [0,1]
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    
    // Calculate texture space step (1 pixel)
    vec2 h = 1.0 / u_resolution;
    
    // Sample current value and neighbors
    float center = texture2D(u_psi, texCoord).r;
    float left   = texture2D(u_psi, texCoord + vec2(-h.x, 0.0)).r;
    float right  = texture2D(u_psi, texCoord + vec2(h.x, 0.0)).r;
    float up     = texture2D(u_psi, texCoord + vec2(0.0, h.y)).r;
    float down   = texture2D(u_psi, texCoord + vec2(0.0, -h.y)).r;
    
    // Compute Laplacian (discrete approximation)
    float laplacian = (left + right + up + down - 4.0 * center);
    
    // Update: psi_{next} = psi_{current} + dt * D * Laplacian(psi)
    float psi_next = center + u_dt * u_D * laplacian;
    
    // Add Gaussian heat pulse if enabled
    if (u_addHeat) {
        // Convert texture coordinates to pixel coordinates
        vec2 pixelCoord = texCoord * u_resolution;
        vec2 pulsePixelPos = u_heatPos * u_resolution;
        
        // Calculate distance from heat source
        vec2 delta = pixelCoord - pulsePixelPos;
        float dist = length(delta);
        
        // Add Gaussian heat distribution
        float heatValue = u_heatAmplitude * exp(-dist * dist / u_heatWidth);
        psi_next += heatValue;
    }
    
    // Output to all channels
    gl_FragColor = vec4(psi_next, psi_next, psi_next, 1.0);
}