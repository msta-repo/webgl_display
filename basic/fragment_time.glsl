precision mediump float;
varying float vX;
varying float vY;
uniform float u_time;  // Time uniform in seconds

void main() {
    // vX is in clip space (-1 to 1), remap to 0-1 for brightness
    float brightness = 0.5 + 0.5 * (vX + 1.0);
    
    // Add time-varying phase to sin and cos
    gl_FragColor = vec4(
        (sin(vX * vY * 100.0 + u_time * 2.0) + 1.0) / 2.0,  // Red channel
        cos(vY * vX * 160.0 + u_time * 3.0),                 // Green channel
        0.0,                                                   // Blue channel
        1.0                                                    // Alpha
    );
}