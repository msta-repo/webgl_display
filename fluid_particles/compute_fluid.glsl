#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
uniform sampler2D fields_current;
uniform sampler2D fields_previous;
uniform vec2 resolution;
uniform float dt;
uniform float D;
uniform float t;
varying float vX;
varying float vY;

uniform float usePeriodic; 

// Mouse interaction uniforms
uniform int u_mouseActive;
uniform vec2 u_mousePos;
uniform vec2 u_mouseVel;
uniform float u_mouseRadius; 

// Wrap texture coordinates for periodic boundaries
vec2 wrap(vec2 coord) {
    return fract(coord);
}

void main() {
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    vec2 Step = 1.0 / resolution;
    
    float CScale = 0.5;
    //float K = 0.2;
    //float v = 0.55;

    float K = 0.4;
    float v = 0.8;

    float kappa = 0.2;

    float S = K / dt;
    
    // Sample with wrapping
    vec4 FC = texture2D(fields_current, wrap(texCoord));
    
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
    
    float Udiv = UdX.x + UdY.y;
    vec2 DdX = vec2(UdX.z, UdY.z);
    
    // ==================== MASS CONSERVATION ====================
    FC.z -= dt * dot(vec3(DdX, Udiv), FC.xyz);
    
    
    float Laplacian_rho = (FR.z + FL.z + FT.z + FD.z) - 4.0 * FC.z;
    FC.z += dt * kappa * Laplacian_rho;
    
    FC.z = clamp(FC.z, 0.5, 3.0);
    
    // ==================== MOMENTUM CONSERVATION ====================
    vec2 PdX = S * DdX;
    vec2 Laplacian = (FR.xy + FL.xy + FT.xy + FD.xy) - 4.0 * FC.xy;
    vec2 ViscosityForce = v * Laplacian;
    
   

    // Semi-Lagrangian advection with wrapping
    vec2 Was = wrap(texCoord - dt * FC.xy * Step);
    FC.xy = texture2D(fields_current, Was).xy;
    
    float force_strength = exp(-dot(texCoord.xy-0.5, texCoord.xy-0.5)/0.005);
    vec2 ExternalForces = vec2(0.0, 0.000)*force_strength;
    
    // Add mouse/touch interaction force with Gaussian falloff
    if (u_mouseActive == 1) {
        vec2 toMouse = texCoord - u_mousePos;
        float distSq = dot(toMouse, toMouse);
        float radiusSq = u_mouseRadius * u_mouseRadius;
        
        // Gaussian falloff: exp(-distSq / (2 * sigma^2))
        // Using sigma = radius/2 for a smooth falloff
        float sigma = u_mouseRadius * 0.5;
        float sigmaSq = sigma * sigma;
        float gaussian = exp(-distSq / (2.0 * sigmaSq));
        
        // Apply velocity scaled by Gaussian
        ExternalForces += u_mouseVel * gaussian*2.0;
    }
    
    FC.xy += dt * (ViscosityForce - PdX + ExternalForces);
    
    // Vorticity confinement based on values stored in alpha
    FC.a = (FR.y - FL.y - FT.x + FD.x);
    vec2 vort = vec2(abs(FT.a) - abs(FD.a), abs(FL.a) - abs(FR.a));
    float VORTICITY_AMOUNT = 0.002;
    vort *= VORTICITY_AMOUNT/length(vort + 1e-9)*FC.w;
    FC.xy += vort;


       // ==================== BOUNDARY CONDITIONS (only for walls) ====================
    if (usePeriodic < 0.5) {
        if (texCoord.x < Step.x * 3.0 || texCoord.x > 1.0 - Step.x * 3.0) {
            FC.x = 0.0;
        }
        if (texCoord.y < Step.y * 3.0 || texCoord.y > 1.0 - Step.y * 3.0) {
            FC.y = 0.0;
        }
    }

    
    gl_FragColor = FC;
}