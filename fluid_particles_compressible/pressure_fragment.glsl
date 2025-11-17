#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform sampler2D fields_current; // Current pressure field
uniform sampler2D velocity;       // Velocity field from fluid compute

uniform vec2 resolution;

uniform float pressureResolutionFactor;

uniform float usePeriodic; 
uniform float omega;              // SOR relaxation parameter (1.7-1.9)
uniform int redOrBlack;           // 0 for red, 1 for black

varying float vX;
varying float vY;

// Wrap texture coordinates for periodic boundaries
vec2 wrap(vec2 coord) {
    if (usePeriodic > 0.5) {
        return fract(coord);
    }
    return coord;
}

void main() {
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    vec2 Step = 1.0 / resolution;
    vec2 pStep = 1.0 / (resolution/pressureResolutionFactor);

    // Determine if this pixel is red or black
    // Use floor and fract to avoid integer modulo
    vec2 pixelCoord = gl_FragCoord.xy;
    float sum = pixelCoord.x + pixelCoord.y;
    float checkerboard = floor(fract(sum / 2.0) + 0.5); // 0 or 1
    
    // Only update pixels matching the current red/black pass
    float targetPattern = float(redOrBlack);
    if (abs(checkerboard - targetPattern) > 0.1) {
        // Not our turn - just pass through current pressure
        gl_FragColor = texture2D(fields_current, texCoord);
        return;
    }
    
    // ==================== COMPUTE DIVERGENCE ====================
    // Sample with wrapping
    vec4 FC = texture2D(velocity, wrap(texCoord));
    
    // Standard neighbors with wrapping
    vec4 FR = texture2D(velocity, wrap(texCoord + vec2(Step.x, 0.0)));
    vec4 FL = texture2D(velocity, wrap(texCoord - vec2(Step.x, 0.0)));
    vec4 FT = texture2D(velocity, wrap(texCoord + vec2(0.0, Step.y)));
    vec4 FD = texture2D(velocity, wrap(texCoord - vec2(0.0, Step.y)));
    
    // Extended neighbors with wrapping
    vec4 FRR = texture2D(velocity, wrap(texCoord + vec2(2.0 * Step.x, 0.0)));
    vec4 FLL = texture2D(velocity, wrap(texCoord - vec2(2.0 * Step.x, 0.0)));
    vec4 FTT = texture2D(velocity, wrap(texCoord + vec2(0.0, 2.0 * Step.y)));
    vec4 FDD = texture2D(velocity, wrap(texCoord - vec2(0.0, 2.0 * Step.y)));
    
    // ==================== SPATIAL DERIVATIVES ====================
    vec3 UdX = (-FRR.xyz + 8.0 * FR.xyz - 8.0 * FL.xyz + FLL.xyz) / (12.0*Step.x);
    vec3 UdY = (-FTT.xyz + 8.0 * FT.xyz - 8.0 * FD.xyz + FDD.xyz) / (12.0*Step.y);
    
    float divergence = UdX.x + UdY.y;
    //divergence = divergence * Step.x/pStep.x; // rescale divergence
    divergence = divergence*0.45; // rescale divergence to make more stable for some reason


    // ==================== GAUSS-SEIDEL ITERATION ====================
    // Solve: ∇²p = divergence
    // Using finite differences: (pR + pL + pT + pB - 4*pC) / h² = divergence
    // Rearranged: pC = (pR + pL + pT + pB - h²*divergence) / 4
    
    // Read neighboring pressures
    float pRight = texture2D(fields_current, wrap(texCoord + vec2(pStep.x, 0.0))).r;
    float pLeft = texture2D(fields_current, wrap(texCoord - vec2(pStep.x, 0.0))).r;
    float pTop = texture2D(fields_current, wrap(texCoord + vec2(0.0, pStep.y))).r;
    float pBottom = texture2D(fields_current, wrap(texCoord - vec2(0.0, pStep.y))).r;
    
    float pCurrent = texture2D(fields_current, texCoord).r;
    
    // Average grid spacing
    float h = (Step.x + Step.y) / 2.0; // this works better if using velocity resolution step instead of pressure resolution step
    float h_squared = h * h;
    
    // Gauss-Seidel update
    float pNew = (pRight + pLeft + pTop + pBottom - h_squared * divergence) / 4.0;
    
    // Apply Successive Over-Relaxation (SOR)
    float pRelaxed = (1.0 - omega) * pCurrent + omega * pNew;
    
    // Store pressure in red channel
    gl_FragColor = vec4(pRelaxed, 0.0, 0.0, 1.0);
}
