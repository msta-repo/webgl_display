#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif



uniform sampler2D fields_current; // fields current must contain the pressure and updated vx, vy

uniform sampler2D velocity; // velocities contains the uncorrected velocities after compute step

uniform vec2 resolution;

varying float vX;
varying float vY;

uniform float usePeriodic; 

uniform float omega;

uniform bool redOrBlack;

// Wrap texture coordinates for periodic boundaries
vec2 wrap(vec2 coord) {
    return fract(coord);
}

void main() {
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    vec2 Step = 1.0 / resolution;
    
    float CScale = 0.5;


    // Sample pressure
    vec4 p = texture2D(fields_current, wrap(texCoord));
    
    // Sample with wrapping
    vec4 FC = texture2D(velocity, wrap(texCoord));
    
    // Standard neighbors with wrapping
    vec4 FR = texture2D(fields_current, wrap(texCoord + vec2(Step.x, 0.0)));
    vec4 FL = texture2D(fields_current, wrap(texCoord - vec2(Step.x, 0.0)));
    vec4 FT = texture2D(fields_current, wrap(texCoord + vec2(0.0, Step.y)));
    vec4 FD = texture2D(fields_current, wrap(texCoord - vec2(0.0, Step.y)));
    
    // Extended neighbors with wrapping
    vec4 FRR = texture2D(fields_current, wrap(texCoord + vec2(2.0 * Step.x, 0.0)));
    vec4 FLL = texture2D(fields_current, wrap(texCoord - vec2(2.0 * Step.x, 0.0)));
    vec4 FTT = texture2D(fields_current, wrap(texCoord + vec2(0.0, 2.0 * Step.y)));
    vec4 FDD = texture2D(fields_current, wrap(texCoord - vec2(0.0, 2.0 * Step.y)));
    
    // ==================== SPATIAL DERIVATIVES ====================
    vec3 UdX = (-FRR.xyz + 8.0 * FR.xyz - 8.0 * FL.xyz + FLL.xyz) / 12.0;
    vec3 UdY = (-FTT.xyz + 8.0 * FT.xyz - 8.0 * FD.xyz + FDD.xyz) / 12.0;
    
    float Udiv = UdX.x + UdY.y; // velocity divergence

    
    // solve poisson equation using red-black gauss seidel

    //FC = FC; // update velocities

    gl_FragColor = FC; // return 
}