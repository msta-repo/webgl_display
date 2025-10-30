#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform sampler2D u_psi;
uniform vec2 u_resolution;
uniform float u_dt;
uniform float u_D;
varying float vX;
varying float vY;

void main() {
    // Convert from clip space [-1,1] to texture coordinates [0,1]
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    
    // Calculate texture space step (1 pixel)
    vec2 h = 1.0 / u_resolution;
    
    // Check if we're at the boundary (heat sink)
   // if (texCoord.x < 20.0 * h.x){
        //texCoord.x > 1.0 - 20.0 * h.x){// ||
        //texCoord.y < 20.0 * h.y ||
        //texCoord.y > 1.0 - 20.0 * h.y) {
        // Boundary: fixed at 0.0 (heat sink)
   //     gl_FragColor = vec4(-10.0, -10.0, -10.0, 1.0);
    //    return;
    //}
    
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
    
    // Output to all channels
    gl_FragColor = vec4(psi_next, psi_next, psi_next, 1.0);
}