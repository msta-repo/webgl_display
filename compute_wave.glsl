#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform sampler2D u_psi_current;
uniform sampler2D u_psi_previous;
uniform vec2 u_resolution;
uniform float u_dt;
uniform float u_D;
uniform float u_t;
uniform float u_attenuate;

// Pulse addition uniforms
uniform bool u_addPulse;
uniform vec2 u_pulsePos;
uniform float u_pulseAmplitude;
uniform float u_pulseSigmaX;
uniform float u_pulseSigmaY;
uniform float u_pulsePhi;

varying float vX;
varying float vY;

float heaviside(float x) {
    return (x > 0.0) ? 1.0 : 0.0;
}

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
    //vec2 delta = pixelCoord - vec2(0.5,0.5)*u_resolution;

    // Rotate coordinates by phi for anisotropic Gaussian
    float cosPhi = cos(u_pulsePhi*0.0);
    float sinPhi = sin(u_pulsePhi*0.0);
    float dx_prime = delta.x * cosPhi + delta.y * sinPhi;
    float dy_prime = -delta.x * sinPhi + delta.y * cosPhi;
    
    // Calculate anisotropic Gaussian value
     //float sigmaX_sq = 500.0;
    float sigmaX_sq = u_pulseSigmaX * u_pulseSigmaX;
    //float sigmaY_sq = u_pulseSigmaY * u_pulseSigmaY*50.0;
    float sigmaY_sq = sigmaX_sq;

    float pulseValue = u_pulseAmplitude * exp(-dx_prime * dx_prime / (2.0 * sigmaX_sq) - dy_prime * dy_prime / (2.0 * sigmaY_sq));
    //float pulseValue = 1.0 * exp(-dx_prime * dx_prime / (2.0 * sigmaX_sq) - dy_prime * dy_prime / (2.0 * sigmaY_sq));
    return pulseValue;
}

void main() {
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    vec2 h = 1.0 / u_resolution;
    
    float psi_i = texture2D(u_psi_current, texCoord).r;
    float psi_im1 = texture2D(u_psi_previous, texCoord).r;
    
    // Add pulse to current value
    float pulseValue = calculatePulseAt(texCoord);
    psi_i += pulseValue;
    psi_im1 += pulseValue;

    float h_sq = h.x * h.x;

    float left   =   calculatePulseAt(texCoord + vec2(-h.x, 0.0));
    float right  =  calculatePulseAt(texCoord + vec2(h.x, 0.0));
    float up     =  calculatePulseAt(texCoord + vec2(0.0, h.y));
    float down   =  calculatePulseAt(texCoord + vec2(0.0, -h.y));
    
    float laplacianPulse = (left + right + up + down - 4.0 * pulseValue) / h_sq ;



    left   = texture2D(u_psi_current, texCoord + vec2(-h.x, 0.0)).r;
    right  = texture2D(u_psi_current, texCoord + vec2(h.x, 0.0)).r;
    up     = texture2D(u_psi_current, texCoord + vec2(0.0, h.y)).r;
    down   = texture2D(u_psi_current, texCoord + vec2(0.0, -h.y)).r;


    
    float laplacianWave = (left + right + up + down - 4.0 * psi_i) / h_sq ;
    
    float laplacian = laplacianWave + laplacianPulse;


    // Wave equation update
    float dt_sq = u_dt * u_dt;
    float psi_next = psi_i + (1.0 - u_attenuate)*(psi_i - psi_im1) + (dt_sq * u_D) * laplacian;

    //float psi_next = laplacianPulse;
    gl_FragColor = vec4(psi_next, psi_next, psi_next, 1.0);
}