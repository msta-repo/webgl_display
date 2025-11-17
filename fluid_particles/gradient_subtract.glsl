#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform sampler2D fields_current; // uncorrected velocity fields
uniform sampler2D pressure;       // pressure field

uniform float pressureResolutionFactor;

uniform vec2 resolution;

varying float vX;
varying float vY;

uniform float usePeriodic; 

// Wrap texture coordinates for periodic boundaries
vec2 wrap(vec2 coord) {
    return fract(coord);
}

void main() {
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    vec2 Step = 1.0 / (resolution/pressureResolutionFactor);
    
    float CScale = 0.5;
    
    // ==================== COMPUTE PRESSURE GRADIENT ====================
    // Sample pressure field
    vec4 FC = texture2D(pressure, wrap(texCoord));
    
    // Standard neighbors with wrapping
    vec4 FR = texture2D(pressure, wrap(texCoord + vec2(Step.x, 0.0)));
    vec4 FL = texture2D(pressure, wrap(texCoord - vec2(Step.x, 0.0)));
    vec4 FT = texture2D(pressure, wrap(texCoord + vec2(0.0, Step.y)));
    vec4 FD = texture2D(pressure, wrap(texCoord - vec2(0.0, Step.y)));
    
    // Extended neighbors with wrapping
    vec4 FRR = texture2D(pressure, wrap(texCoord + vec2(2.0 * Step.x, 0.0)));
    vec4 FLL = texture2D(pressure, wrap(texCoord - vec2(2.0 * Step.x, 0.0)));
    vec4 FTT = texture2D(pressure, wrap(texCoord + vec2(0.0, 2.0 * Step.y)));
    vec4 FDD = texture2D(pressure, wrap(texCoord - vec2(0.0, 2.0 * Step.y)));
    
    // ==================== SPATIAL DERIVATIVES ====================
    // High-order finite difference for pressure gradient
    // Using the red channel (r component) which stores pressure
    float dPdX = (-FRR.r + 8.0 * FR.r - 8.0 * FL.r + FLL.r) / (12.0 * Step.x);
    float dPdY = (-FTT.r + 8.0 * FT.r - 8.0 * FD.r + FDD.r) / (12.0 * Step.y);
    
    // Pressure gradient vector
    vec2 gradP = vec2(dPdX, dPdY);
    
    // Read current (uncorrected) velocity field
    vec4 velocity = texture2D(fields_current, wrap(texCoord));
    
    // ==================== PROJECT VELOCITY ====================
    // Subtract pressure gradient to make velocity divergence-free
    // u_new = u_old - ∇p
    vec2 correctedVelocity = velocity.xy - gradP;
    
    // Return corrected velocity, preserving other channels (density, etc.)
    gl_FragColor = vec4(correctedVelocity, velocity.z, velocity.w);
}
