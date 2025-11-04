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

void main() {
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    vec2 Step = 1.0 / resolution;
    
    // Paper's constants (K ≈ 0.2, dt = 0.15)
    // The paper assumes dx = dy = 1.0 (grid units, not texture units)
    float CScale = 0.5;       // For central differences with dx=1: (f[i+1]-f[i-1])/2
    float K = 0.025;            // Density-invariant pressure constant
    float v = 0.02;            // Kinematic viscosity
    float S = K / dt;         // Pressure gradient scale
    
    // Sample current state and neighbors
    vec4 FC = texture2D(fields_current, texCoord);
    
    // Standard neighbors (1 cell away)
    vec3 FR = texture2D(fields_current, texCoord + vec2(Step.x, 0.0)).xyz;
    vec3 FL = texture2D(fields_current, texCoord - vec2(Step.x, 0.0)).xyz;
    vec3 FT = texture2D(fields_current, texCoord + vec2(0.0, Step.y)).xyz;
    vec3 FD = texture2D(fields_current, texCoord - vec2(0.0, Step.y)).xyz;
    
    // Extended neighbors (2 cells away) for 4th-order derivatives
    vec3 FRR = texture2D(fields_current, texCoord + vec2(2.0 * Step.x, 0.0)).xyz;
    vec3 FLL = texture2D(fields_current, texCoord - vec2(2.0 * Step.x, 0.0)).xyz;
    vec3 FTT = texture2D(fields_current, texCoord + vec2(0.0, 2.0 * Step.y)).xyz;
    vec3 FDD = texture2D(fields_current, texCoord - vec2(0.0, 2.0 * Step.y)).xyz;
    
    // ==================== SPATIAL DERIVATIVES (4th-order central differences) ====================
    // 4th-order: df/dx ≈ (-f[i+2] + 8*f[i+1] - 8*f[i-1] + f[i-2]) / 12
    vec3 UdX = (-FRR + 8.0 * FR - 8.0 * FL + FLL) / 12.0;
    vec3 UdY = (-FTT + 8.0 * FT - 8.0 * FD + FDD) / 12.0;
    
    float Udiv = UdX.x + UdY.y;     // Velocity divergence
    vec2 DdX = vec2(UdX.z, UdY.z);  // Density gradient
    
    // ==================== MASS CONSERVATION ====================
    // drho/dt = -u·∇rho - rho*div(u)
    FC.z -= dt * dot(vec3(DdX, Udiv), FC.xyz);
    
    // Add small density diffusion to suppress checkerboard instabilities
    float kappa = 0.02;  // Density diffusion coefficient
    float Laplacian_rho = (FR.z + FL.z + FT.z + FD.z) - 4.0 * FC.z;
    FC.z += dt * kappa * Laplacian_rho;
    
    FC.z = clamp(FC.z, 0.5, 3.0);
    
    // ==================== MOMENTUM CONSERVATION ====================
    // Pressure gradient
    vec2 PdX = S * DdX;
    
    // Laplacian (with dx=1): (u[i+1] + u[i-1] + u[j+1] + u[j-1] - 4*u[i,j])
    vec2 Laplacian = (FR.xy + FL.xy + FT.xy + FD.xy) - 4.0 * FC.xy;
    vec2 ViscosityForce = v * Laplacian;
    
    // Semi-Lagrangian advection FIRST (as in paper)
    // Velocity is in grid units (pixels/timestep), Step converts to texture space
    vec2 Was = texCoord - dt * FC.xy * Step;
    FC.xy = texture2D(fields_current, Was).xy;
    
    // Then apply forces
    float force_strength = exp(-dot(texCoord.xy-0.5, texCoord.xy-0.5)/0.005);
    vec2 ExternalForces = vec2(0.0, 0.001)*force_strength;
    FC.xy += dt * (ViscosityForce - PdX + ExternalForces);
    
    // ==================== BOUNDARY CONDITIONS ====================
    // Need wider boundary for 4th-order stencil (3 pixels instead of 2)
    if (texCoord.x < Step.x * 3.0 || texCoord.x > 1.0 - Step.x * 3.0) {
        FC.x = 0.0;
    }
    if (texCoord.y < Step.y * 3.0 || texCoord.y > 1.0 - Step.y * 3.0) {
        FC.y = 0.0;
    }
    
    // particle advection


    gl_FragColor = FC;
}
