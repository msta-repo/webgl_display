#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform sampler2D u_psi;
uniform vec2 u_resolution;

// Pulse addition uniforms
uniform bool u_addPulse;
uniform vec2 u_pulsePos;
uniform float u_pulseAmplitude;
uniform float u_pulseSigmaX;
uniform float u_pulseSigmaY;
uniform float u_pulsePhi;
uniform float u_attenuate;

varying float vX;
varying float vY;

// Calculate Gaussian pulse value at given texture coordinate
float calculatePulseAt(vec2 texCoord) {
    if (!u_addPulse) {
        return 0.0;
    }
    
    // Convert texture coordinates to pixel coordinates
    vec2 pixelCoord = texCoord * u_resolution;
    vec2 pulsePixelPos = u_pulsePos * u_resolution;
    
    // Calculate distance from pulse center
    vec2 delta = pixelCoord - pulsePixelPos;

    // Rotate coordinates by phi for anisotropic Gaussian
    float cosPhi = cos(u_pulsePhi);
    float sinPhi = sin(u_pulsePhi);
    float dx_prime = delta.x * cosPhi + delta.y * sinPhi;
    float dy_prime = -delta.x * sinPhi + delta.y * cosPhi;
    
    // Calculate anisotropic Gaussian value
    float sigmaX_sq = u_pulseSigmaX * u_pulseSigmaX;
    float sigmaY_sq = u_pulseSigmaY * u_pulseSigmaY;

    float pulseValue = u_pulseAmplitude * exp(-dx_prime * dx_prime / (2.0 * sigmaX_sq) - dy_prime * dy_prime / (2.0 * sigmaY_sq));
    
    return pulseValue;
}

void main() {
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    
    // Read current value from texture
    float psi = texture2D(u_psi, texCoord).r;
    
    // Add pulse
    float pulseValue = calculatePulseAt(texCoord);
    psi = psi*(1.0 - u_attenuate);
    
    psi += pulseValue;
    
    // Write back
    gl_FragColor = vec4(psi, psi, psi, 1.0);
}